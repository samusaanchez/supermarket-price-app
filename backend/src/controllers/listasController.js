const pool = require('../db/pool');

// GET /listas
async function list(req, res) {
  try {
    const { rows } = await pool.query(
      `SELECT
         l.id, l.nombre, l.created_at, l.updated_at,
         COUNT(li.id)::int AS num_items
       FROM listas_compra l
       LEFT JOIN lista_items li ON li.lista_id = l.id
       WHERE l.usuario_id = $1
       GROUP BY l.id
       ORDER BY l.updated_at DESC`,
      [req.userId]
    );
    return res.json({ listas: rows });
  } catch (err) {
    console.error('Error listando listas:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

// POST /listas
async function create(req, res) {
  const nombre = (req.body.nombre || '').trim();
  if (nombre.length === 0 || nombre.length > 255) {
    return res.status(400).json({
      error: {
        code: 'NOMBRE_INVALIDO',
        message: 'El nombre debe tener entre 1 y 255 caracteres',
      },
    });
  }

  try {
    const { rows } = await pool.query(
      `INSERT INTO listas_compra (usuario_id, nombre)
       VALUES ($1, $2)
       RETURNING id, nombre, created_at, updated_at`,
      [req.userId, nombre]
    );
    return res.status(201).json({ lista: { ...rows[0], num_items: 0 } });
  } catch (err) {
    console.error('Error creando lista:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

// GET /listas/:id
async function getById(req, res) {
  const listaId = req.params.id;

  try {
    const listaResult = await pool.query(
      `SELECT id, nombre, created_at, updated_at
       FROM listas_compra
       WHERE id = $1 AND usuario_id = $2`,
      [listaId, req.userId]
    );

    if (listaResult.rows.length === 0) {
      return res.status(404).json({
        error: { code: 'NO_ENCONTRADO', message: 'Lista no encontrada' },
      });
    }

    const itemsResult = await pool.query(
      `SELECT
         li.id, li.cantidad, li.created_at,
         p.id AS producto_id, p.nombre, p.marca, p.tamano,
         p.presentacion, p.variante,
         p.cantidad_valor, p.cantidad_unidad,
         p.categoria_id
       FROM lista_items li
       JOIN productos p ON p.id = li.producto_id
       WHERE li.lista_id = $1
       ORDER BY li.created_at`,
      [listaId]
    );

    return res.json({
      lista: listaResult.rows[0],
      items: itemsResult.rows,
    });
  } catch (err) {
    if (err.code === '22P02') {
      return res.status(400).json({
        error: { code: 'ID_INVALIDO', message: 'El id no es válido' },
      });
    }
    console.error('Error getById lista:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

// PATCH /listas/:id
async function rename(req, res) {
  const listaId = req.params.id;
  const nombre = (req.body.nombre || '').trim();

  if (nombre.length === 0 || nombre.length > 255) {
    return res.status(400).json({
      error: {
        code: 'NOMBRE_INVALIDO',
        message: 'El nombre debe tener entre 1 y 255 caracteres',
      },
    });
  }

  try {
    const { rows } = await pool.query(
      `UPDATE listas_compra
       SET nombre = $1, updated_at = NOW()
       WHERE id = $2 AND usuario_id = $3
       RETURNING id, nombre, created_at, updated_at`,
      [nombre, listaId, req.userId]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        error: { code: 'NO_ENCONTRADO', message: 'Lista no encontrada' },
      });
    }

    return res.json({ lista: rows[0] });
  } catch (err) {
    if (err.code === '22P02') {
      return res.status(400).json({
        error: { code: 'ID_INVALIDO', message: 'El id no es válido' },
      });
    }
    console.error('Error renombrando lista:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

// DELETE /listas/:id
async function remove(req, res) {
  const listaId = req.params.id;

  try {
    const { rowCount } = await pool.query(
      `DELETE FROM listas_compra
       WHERE id = $1 AND usuario_id = $2`,
      [listaId, req.userId]
    );

    if (rowCount === 0) {
      return res.status(404).json({
        error: { code: 'NO_ENCONTRADO', message: 'Lista no encontrada' },
      });
    }

    return res.status(204).end();
  } catch (err) {
    if (err.code === '22P02') {
      return res.status(400).json({
        error: { code: 'ID_INVALIDO', message: 'El id no es válido' },
      });
    }
    console.error('Error borrando lista:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

// POST /listas/:id/items
async function addItem(req, res) {
  const listaId = req.params.id;
  const productoId = req.body.producto_id;
  const cantidad = parseInt(req.body.cantidad, 10) || 1;

  if (!productoId) {
    return res.status(400).json({
      error: {
        code: 'DATOS_INVALIDOS',
        message: 'producto_id es obligatorio',
      },
    });
  }
  if (cantidad < 1 || cantidad > 999) {
    return res.status(400).json({
      error: {
        code: 'CANTIDAD_INVALIDA',
        message: 'La cantidad debe estar entre 1 y 999',
      },
    });
  }

  const client = await pool.connect();
  try {
    // Comprobamos que la lista es del usuario
    const listaCheck = await client.query(
      'SELECT id FROM listas_compra WHERE id = $1 AND usuario_id = $2',
      [listaId, req.userId]
    );
    if (listaCheck.rows.length === 0) {
      return res.status(404).json({
        error: { code: 'NO_ENCONTRADO', message: 'Lista no encontrada' },
      });
    }

    // Intentamos insertar. Si ya existe, sumamos cantidades.
    let itemResult;
    try {
      itemResult = await client.query(
        `INSERT INTO lista_items (lista_id, producto_id, cantidad)
         VALUES ($1, $2, $3)
         RETURNING id, cantidad`,
        [listaId, productoId, cantidad]
      );
    } catch (insertErr) {
      if (insertErr.code === '23505') {
        // Ya existe: sumar cantidad (respetando el tope de 999)
        itemResult = await client.query(
          `UPDATE lista_items
           SET cantidad = LEAST(cantidad + $3, 999)
           WHERE lista_id = $1 AND producto_id = $2
           RETURNING id, cantidad`,
          [listaId, productoId, cantidad]
        );
      } else if (insertErr.code === '23503') {
        return res.status(404).json({
          error: {
            code: 'PRODUCTO_NO_EXISTE',
            message: 'El producto no existe',
          },
        });
      } else {
        throw insertErr;
      }
    }

    await client.query(
      'UPDATE listas_compra SET updated_at = NOW() WHERE id = $1',
      [listaId]
    );

    return res.status(201).json({ item: itemResult.rows[0] });
  } catch (err) {
    if (err.code === '22P02') {
      return res.status(400).json({
        error: { code: 'ID_INVALIDO', message: 'El id no es válido' },
      });
    }
    console.error('Error añadiendo item:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  } finally {
    client.release();
  }
}

// PATCH /listas/:id/items/:itemId
async function updateItem(req, res) {
  const { id: listaId, itemId } = req.params;
  const cantidad = parseInt(req.body.cantidad, 10);

  if (isNaN(cantidad) || cantidad < 1 || cantidad > 999) {
    return res.status(400).json({
      error: {
        code: 'CANTIDAD_INVALIDA',
        message: 'La cantidad debe estar entre 1 y 999',
      },
    });
  }

  try {
    // Update con JOIN implícito: la fila solo se toca si la lista es del usuario
    const { rows } = await pool.query(
      `UPDATE lista_items
       SET cantidad = $1
       WHERE id = $2 AND lista_id = $3
         AND EXISTS (
           SELECT 1 FROM listas_compra
           WHERE id = $3 AND usuario_id = $4
         )
       RETURNING id, cantidad`,
      [cantidad, itemId, listaId, req.userId]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        error: { code: 'NO_ENCONTRADO', message: 'Item no encontrado' },
      });
    }

    await pool.query(
      'UPDATE listas_compra SET updated_at = NOW() WHERE id = $1',
      [listaId]
    );

    return res.json({ item: rows[0] });
  } catch (err) {
    if (err.code === '22P02') {
      return res.status(400).json({
        error: { code: 'ID_INVALIDO', message: 'El id no es válido' },
      });
    }
    console.error('Error actualizando item:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

// DELETE /listas/:id/items/:itemId
async function removeItem(req, res) {
  const { id: listaId, itemId } = req.params;

  try {
    const { rowCount } = await pool.query(
      `DELETE FROM lista_items
       WHERE id = $1 AND lista_id = $2
         AND EXISTS (
           SELECT 1 FROM listas_compra
           WHERE id = $2 AND usuario_id = $3
         )`,
      [itemId, listaId, req.userId]
    );

    if (rowCount === 0) {
      return res.status(404).json({
        error: { code: 'NO_ENCONTRADO', message: 'Item no encontrado' },
      });
    }

    await pool.query(
      'UPDATE listas_compra SET updated_at = NOW() WHERE id = $1',
      [listaId]
    );

    return res.status(204).end();
  } catch (err) {
    if (err.code === '22P02') {
      return res.status(400).json({
        error: { code: 'ID_INVALIDO', message: 'El id no es válido' },
      });
    }
    console.error('Error borrando item:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

module.exports = { list, create, getById, rename, remove, addItem, updateItem, removeItem };