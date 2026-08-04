const pool = require('../db/pool');

// POST /reclamaciones  (reportar un precio o una foto incorrectos)
async function crear(req, res) {
  const tipo = req.body.tipo;
  const precioId = req.body.precio_id || null;
  const fotoId = req.body.foto_id || null;
  const motivo = (req.body.motivo || '').trim() || null;

  if (tipo !== 'precio' && tipo !== 'foto') {
    return res.status(400).json({
      error: { code: 'TIPO_INVALIDO', message: 'tipo debe ser "precio" o "foto"' },
    });
  }
  if (tipo === 'precio' && !precioId) {
    return res.status(400).json({
      error: { code: 'OBJETIVO_REQUERIDO', message: 'Falta precio_id' },
    });
  }
  if (tipo === 'foto' && !fotoId) {
    return res.status(400).json({
      error: { code: 'OBJETIVO_REQUERIDO', message: 'Falta foto_id' },
    });
  }

  try {
    // El objetivo debe existir.
    if (tipo === 'precio') {
      const p = await pool.query('SELECT id FROM precios WHERE id = $1', [precioId]);
      if (p.rows.length === 0) {
        return res.status(404).json({
          error: { code: 'NO_ENCONTRADO', message: 'Ese precio no existe' },
        });
      }
    } else {
      const f = await pool.query('SELECT id FROM fotos WHERE id = $1', [fotoId]);
      if (f.rows.length === 0) {
        return res.status(404).json({
          error: { code: 'NO_ENCONTRADO', message: 'Esa foto no existe' },
        });
      }
    }

    const { rows } = await pool.query(
      `INSERT INTO reclamaciones (usuario_id, tipo, precio_id, foto_id, motivo)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, tipo, estado, created_at`,
      [
        req.userId,
        tipo,
        tipo === 'precio' ? precioId : null,
        tipo === 'foto' ? fotoId : null,
        motivo,
      ]
    );
    return res.status(201).json({ reclamacion: rows[0] });
  } catch (err) {
    if (err.code === '22P02') {
      return res.status(400).json({
        error: { code: 'ID_INVALIDO', message: 'El id no es válido' },
      });
    }
    console.error('Error creando reclamación:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

// GET /reclamaciones  (las mías)
async function listMias(req, res) {
  try {
    const { rows } = await pool.query(
      `SELECT id, tipo, precio_id, foto_id, motivo, estado, created_at, resolved_at
       FROM reclamaciones
       WHERE usuario_id = $1
       ORDER BY created_at DESC`,
      [req.userId]
    );
    return res.json({ reclamaciones: rows });
  } catch (err) {
    console.error('Error listando reclamaciones:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

module.exports = { crear, listMias };
