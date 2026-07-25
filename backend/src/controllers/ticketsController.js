const pool = require('../db/pool');

// POST /tickets  (multipart, campo de archivo "foto")
async function create(req, res) {
  if (!req.file) {
    return res.status(400).json({
      error: {
        code: 'FOTO_FALTA',
        message: 'Debes adjuntar una imagen del ticket en el campo "foto"',
      },
    });
  }

  // Ruta pública desde la que se sirve la imagen (carpeta estática /uploads).
  const fotoUrl = `/uploads/${req.file.filename}`;

  try {
    const { rows } = await pool.query(
      `INSERT INTO tickets (usuario_id, foto_url, estado)
       VALUES ($1, $2, 'pendiente')
       RETURNING id, estado, foto_url, created_at`,
      [req.userId, fotoUrl]
    );
    return res.status(201).json({ ticket: rows[0] });
  } catch (err) {
    console.error('Error creando ticket:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

// GET /tickets  (lista de mis tickets)
async function list(req, res) {
  try {
    const { rows } = await pool.query(
      `SELECT t.id, t.estado, t.foto_url,
              t.supermercado_id, s.nombre AS supermercado_nombre,
              t.total_ticket, t.fecha_compra, t.created_at,
              COUNT(ti.id)::int AS num_items
       FROM tickets t
       LEFT JOIN supermercados s ON s.id = t.supermercado_id
       LEFT JOIN ticket_items ti ON ti.ticket_id = t.id
       WHERE t.usuario_id = $1
       GROUP BY t.id, s.nombre
       ORDER BY t.created_at DESC`,
      [req.userId]
    );
    return res.json({ tickets: rows });
  } catch (err) {
    console.error('Error listando tickets:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

// GET /tickets/:id  (ticket + sus líneas, con nombre de producto)
async function getById(req, res) {
  const ticketId = req.params.id;

  try {
    const ticketResult = await pool.query(
      `SELECT t.id, t.supermercado_id, s.nombre AS supermercado_nombre,
              t.foto_url, t.estado, t.total_ticket, t.fecha_compra,
              t.error_mensaje, t.created_at, t.updated_at
       FROM tickets t
       LEFT JOIN supermercados s ON s.id = t.supermercado_id
       WHERE t.id = $1 AND t.usuario_id = $2`,
      [ticketId, req.userId]
    );

    if (ticketResult.rows.length === 0) {
      return res.status(404).json({
        error: { code: 'NO_ENCONTRADO', message: 'Ticket no encontrado' },
      });
    }

    const itemsResult = await pool.query(
      `SELECT ti.id, ti.texto_ocr, ti.producto_id,
              p.nombre AS producto_nombre, p.marca AS producto_marca,
              ti.precio_ocr, ti.precio_confirmado,
              ti.peso, ti.es_peso_variable, ti.cantidad, ti.estado, ti.orden
       FROM ticket_items ti
       LEFT JOIN productos p ON p.id = ti.producto_id
       WHERE ti.ticket_id = $1
       ORDER BY ti.orden, ti.created_at`,
      [ticketId]
    );

    return res.json({
      ticket: { ...ticketResult.rows[0], items: itemsResult.rows },
    });
  } catch (err) {
    console.error('Error obteniendo ticket:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

// POST /tickets/emparejar
// Recibe líneas de texto (del OCR) y propone productos + clasificación de confianza.
// Umbrales: >=0.8 auto, >=0.4 revisar, resto sin_match. (Regla 5 -> híbrido)
async function emparejar(req, res) {
  const lineas = req.body.lineas;
  if (!Array.isArray(lineas) || lineas.length === 0) {
    return res.status(400).json({
      error: { code: 'LINEAS_REQUERIDAS', message: 'Envía al menos una línea' },
    });
  }

  try {
    const resultados = [];
    for (const linea of lineas) {
      const texto = (linea.texto || '').trim();
      const precio = linea.precio ?? null;

      let candidatos = [];
      if (texto.length >= 2) {
        const { rows } = await pool.query(
          `SELECT p.id, p.nombre, p.marca, p.tamano, p.presentacion, p.variante,
                  similarity(unaccent(lower(p.nombre || ' ' || p.marca)),
                             unaccent(lower($1))) AS similitud
           FROM productos p
           WHERE unaccent(lower(p.nombre || ' ' || p.marca)) % unaccent(lower($1))
           ORDER BY similitud DESC
           LIMIT 3`,
          [texto]
        );
        candidatos = rows;
      }

      const top = candidatos.length > 0 ? Number(candidatos[0].similitud) : 0;
      let clasificacion;
      if (top >= 0.8) {
        clasificacion = 'auto';
      } else if (top >= 0.4) {
        clasificacion = 'revisar';
      } else {
        clasificacion = 'sin_match';
      }

      resultados.push({ texto, precio, clasificacion, similitud_top: top, candidatos });
    }

    const resumen = {
      total: resultados.length,
      auto: resultados.filter((r) => r.clasificacion === 'auto').length,
      revisar: resultados.filter((r) => r.clasificacion === 'revisar').length,
      sin_match: resultados.filter((r) => r.clasificacion === 'sin_match').length,
    };

    return res.json({ resultados, resumen });
  } catch (err) {
    console.error('Error emparejando líneas:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

// POST /tickets/:id/confirmar
// Recibe la lista de líneas ya revisadas y escribe los precios en una transacción.
async function confirmar(req, res) {
  const ticketId = req.params.id;
  const { supermercado_id, fecha_compra, total_ticket, items } = req.body;

  // ----- Validaciones de entrada -----
  if (!Number.isInteger(supermercado_id)) {
    return res.status(400).json({
      error: {
        code: 'SUPERMERCADO_REQUERIDO',
        message: 'Los precios son por sucursal: falta supermercado_id (entero)',
      },
    });
  }
  if (!Array.isArray(items) || items.length === 0) {
    return res.status(400).json({
      error: { code: 'ITEMS_REQUERIDOS', message: 'Debes enviar al menos una línea' },
    });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1. El ticket es del usuario y no está ya confirmado. FOR UPDATE lo bloquea
    //    para que dos confirmaciones a la vez no se pisen.
    const t = await client.query(
      `SELECT id, estado FROM tickets
       WHERE id = $1 AND usuario_id = $2
       FOR UPDATE`,
      [ticketId, req.userId]
    );
    if (t.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({
        error: { code: 'NO_ENCONTRADO', message: 'Ticket no encontrado' },
      });
    }
    if (t.rows[0].estado === 'completado') {
      await client.query('ROLLBACK');
      return res.status(409).json({
        error: { code: 'TICKET_YA_CONFIRMADO', message: 'Este ticket ya fue confirmado' },
      });
    }

    // 2. El supermercado existe.
    const s = await client.query('SELECT id FROM supermercados WHERE id = $1', [supermercado_id]);
    if (s.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        error: { code: 'SUPERMERCADO_NO_EXISTE', message: 'Ese supermercado no existe' },
      });
    }

    // 3. Confianza del usuario, congelada en este momento (regla 3).
    const u = await client.query('SELECT confiabilidad FROM usuarios WHERE id = $1', [req.userId]);
    const confianza = u.rows[0].confiabilidad;

    // 4. Una línea a la vez: upsert en precios + copia en histórico + registro.
    let preciosActualizados = 0;
    for (const item of items) {
      // Sin producto no hay precio: línea descartada o sin emparejar.
      if (!item.producto_id) continue;

      const precio = Number(item.precio);
      if (!(precio > 0)) {
        await client.query('ROLLBACK');
        return res.status(400).json({
          error: {
            code: 'PRECIO_INVALIDO',
            message: `Precio inválido en la línea del producto ${item.producto_id}`,
          },
        });
      }

      // Upsert: si ya existe precio para (producto, sucursal) lo sobrescribe.
      await client.query(
        `INSERT INTO precios
           (producto_id, supermercado_id, precio, usuario_id, confianza_usuario, fuente, fecha_actualizacion)
         VALUES ($1, $2, $3, $4, $5, 'ticket', NOW())
         ON CONFLICT (producto_id, supermercado_id)
         DO UPDATE SET
           precio              = EXCLUDED.precio,
           usuario_id          = EXCLUDED.usuario_id,
           confianza_usuario   = EXCLUDED.confianza_usuario,
           fuente              = 'ticket',
           fecha_actualizacion = NOW()`,
        [item.producto_id, supermercado_id, precio, req.userId, confianza]
      );

      // Histórico: siempre se añade una fila (append-only).
      await client.query(
        `INSERT INTO precios_historico (producto_id, supermercado_id, precio, usuario_id)
         VALUES ($1, $2, $3, $4)`,
        [item.producto_id, supermercado_id, precio, req.userId]
      );

      // Registro de la línea confirmada (guarda el peso de esta compra).
      await client.query(
        `INSERT INTO ticket_items
           (ticket_id, texto_ocr, producto_id, precio_confirmado, peso, es_peso_variable, estado)
         VALUES ($1, $2, $3, $4, $5, $6, 'confirmado')`,
        [
          ticketId,
          item.texto_ocr || '',
          item.producto_id,
          precio,
          item.peso ?? null,
          item.es_peso_variable ?? false,
        ]
      );

      preciosActualizados++;
    }

    // 5. El ticket queda cerrado.
    await client.query(
      `UPDATE tickets
       SET estado = 'completado', supermercado_id = $1, fecha_compra = $2,
           total_ticket = $3, updated_at = NOW()
       WHERE id = $4`,
      [supermercado_id, fecha_compra ?? null, total_ticket ?? null, ticketId]
    );

    // 6. Contador del usuario.
    await client.query(
      'UPDATE usuarios SET tickets_subidos = tickets_subidos + 1 WHERE id = $1',
      [req.userId]
    );

    await client.query('COMMIT');
    return res.status(200).json({
      ticket_id: ticketId,
      estado: 'completado',
      precios_actualizados: preciosActualizados,
    });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Error confirmando ticket:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  } finally {
    client.release();
  }
}

module.exports = { create, list, getById, emparejar, confirmar };
