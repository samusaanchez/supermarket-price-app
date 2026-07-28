const pool = require('../db/pool');
const fs = require('fs');
const path = require('path');

// Umbrales de validación por comunidad (Fase C).
const VOTOS_PARA_VERIFICAR = 3;
const VOTOS_PARA_RECHAZAR = 3;

// POST /fotos  (multipart: campo "foto" + producto_id en el body)
async function crear(req, res) {
  if (!req.file) {
    return res.status(400).json({
      error: { code: 'FOTO_FALTA', message: 'Debes adjuntar una imagen en el campo "foto"' },
    });
  }

  const productoId = req.body.producto_id;
  if (!productoId) {
    return res.status(400).json({
      error: { code: 'PRODUCTO_REQUERIDO', message: 'Falta producto_id' },
    });
  }

  try {
    // El producto debe existir.
    const prod = await pool.query('SELECT id FROM productos WHERE id = $1', [productoId]);
    if (prod.rows.length === 0) {
      return res.status(404).json({
        error: { code: 'PRODUCTO_NO_ENCONTRADO', message: 'Ese producto no existe' },
      });
    }

    const url = `/uploads/${req.file.filename}`;
    const { rows } = await pool.query(
      `INSERT INTO fotos (producto_id, usuario_id, url, estado)
       VALUES ($1, $2, $3, 'pendiente')
       RETURNING id, producto_id, url, estado, votos_positivos, votos_negativos, created_at`,
      [productoId, req.userId, url]
    );
    return res.status(201).json({ foto: rows[0] });
  } catch (err) {
    console.error('Error subiendo foto:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

// GET /fotos?producto_id=...
async function listar(req, res) {
  const productoId = req.query.producto_id;
  if (!productoId) {
    return res.status(400).json({
      error: { code: 'PRODUCTO_REQUERIDO', message: 'Falta el parámetro producto_id' },
    });
  }

  try {
    const { rows } = await pool.query(
      `SELECT id, producto_id, usuario_id, url, estado,
              votos_positivos, votos_negativos, created_at
       FROM fotos
       WHERE producto_id = $1
       ORDER BY
         (estado = 'verificada') DESC,
         (votos_positivos - votos_negativos) DESC,
         created_at DESC`,
      [productoId]
    );
    return res.json({ fotos: rows });
  } catch (err) {
    console.error('Error listando fotos:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

// POST /fotos/:id/votos  (body: { voto: 1 | -1 })
async function votar(req, res) {
  const fotoId = req.params.id;
  const voto = Number(req.body.voto);

  if (voto !== 1 && voto !== -1) {
    return res.status(400).json({
      error: { code: 'VOTO_INVALIDO', message: 'El voto debe ser 1 (👍) o -1 (👎)' },
    });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // La foto existe (y bloqueada para recalcular sin carreras).
    const f = await client.query(
      'SELECT id, usuario_id FROM fotos WHERE id = $1 FOR UPDATE',
      [fotoId]
    );
    if (f.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({
        error: { code: 'NO_ENCONTRADO', message: 'Foto no encontrada' },
      });
    }

    // No puedes votar tu propia foto.
    if (f.rows[0].usuario_id === req.userId) {
      await client.query('ROLLBACK');
      return res.status(403).json({
        error: { code: 'VOTO_PROPIO', message: 'No puedes votar tu propia foto' },
      });
    }

    // Registra el voto; si ya había uno de este usuario, lo cambia.
    await client.query(
      `INSERT INTO votos_fotos (foto_id, usuario_id, voto)
       VALUES ($1, $2, $3)
       ON CONFLICT (foto_id, usuario_id)
       DO UPDATE SET voto = EXCLUDED.voto, created_at = NOW()`,
      [fotoId, req.userId, voto]
    );

    // Recalcula contadores desde la fuente de verdad (la tabla de votos).
    const c = await client.query(
      `SELECT
         COUNT(*) FILTER (WHERE voto = 1)::int  AS pos,
         COUNT(*) FILTER (WHERE voto = -1)::int AS neg
       FROM votos_fotos
       WHERE foto_id = $1`,
      [fotoId]
    );
    const pos = c.rows[0].pos;
    const neg = c.rows[0].neg;

    // Decide el estado según los umbrales.
    let estado = 'pendiente';
    if (pos >= VOTOS_PARA_VERIFICAR && neg === 0) {
      estado = 'verificada';
    } else if (neg >= VOTOS_PARA_RECHAZAR) {
      estado = 'rechazada';
    }

    const upd = await client.query(
      `UPDATE fotos
       SET votos_positivos = $1, votos_negativos = $2, estado = $3
       WHERE id = $4
       RETURNING id, producto_id, url, estado, votos_positivos, votos_negativos`,
      [pos, neg, estado, fotoId]
    );

    await client.query('COMMIT');
    return res.json({ foto: upd.rows[0] });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Error votando foto:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  } finally {
    client.release();
  }
}

// DELETE /fotos/:id  (solo el dueño puede borrar su foto)
async function eliminar(req, res) {
  const fotoId = req.params.id;
  try {
    const f = await pool.query(
      'SELECT id, usuario_id, url FROM fotos WHERE id = $1',
      [fotoId]
    );
    if (f.rows.length === 0) {
      return res.status(404).json({
        error: { code: 'NO_ENCONTRADO', message: 'Foto no encontrada' },
      });
    }
    if (f.rows[0].usuario_id !== req.userId) {
      return res.status(403).json({
        error: { code: 'NO_ES_TUYA', message: 'Solo puedes borrar tus fotos' },
      });
    }

    await pool.query('DELETE FROM fotos WHERE id = $1', [fotoId]);

    // Best-effort: borrar también el archivo físico.
    try {
      const nombre = path.basename(f.rows[0].url); // /uploads/xxx.jpg -> xxx.jpg
      fs.unlinkSync(path.join(__dirname, '..', '..', 'uploads', nombre));
    } catch (_) {
      // Si el archivo ya no está, no pasa nada.
    }

    return res.status(204).send();
  } catch (err) {
    console.error('Error borrando foto:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

module.exports = { crear, listar, votar, eliminar };
