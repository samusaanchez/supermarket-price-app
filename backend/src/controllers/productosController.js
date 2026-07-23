const pool = require('../db/pool');

const DEFAULT_PER_PAGE = 20;
const MAX_PER_PAGE = 100;

async function list(req, res) {
  const supermercadoId = parseInt(req.query.supermercado_id, 10);
  const categoriaId = parseInt(req.query.categoria_id, 10);
  const page = Math.max(1, parseInt(req.query.page, 10) || 1);
  const perPage = Math.min(
    MAX_PER_PAGE,
    Math.max(1, parseInt(req.query.per_page, 10) || DEFAULT_PER_PAGE)
  );
  const offset = (page - 1) * perPage;

  const filtros = [];
  const params = [];

  if (!isNaN(categoriaId)) {
    params.push(categoriaId);
    filtros.push(`p.categoria_id = $${params.length}`);
  }

  if (!isNaN(supermercadoId)) {
    params.push(supermercadoId);
    filtros.push(`EXISTS (
      SELECT 1 FROM precios pr
      WHERE pr.producto_id = p.id AND pr.supermercado_id = $${params.length}
    )`);
  }

  const where = filtros.length > 0 ? `WHERE ${filtros.join(' AND ')}` : '';

  try {
    const countResult = await pool.query(
      `SELECT COUNT(*)::int AS total FROM productos p ${where}`,
      params
    );
    const total = countResult.rows[0].total;

    params.push(perPage);
    params.push(offset);

    const dataResult = await pool.query(
      `SELECT
         p.id, p.nombre, p.marca, p.tamano, p.presentacion, p.variante,
         p.cantidad_valor, p.cantidad_unidad,
         p.foto_url, p.confianza_promedio, p.categoria_id,
         ${!isNaN(supermercadoId) ? `
         (SELECT pr.precio FROM precios pr
          WHERE pr.producto_id = p.id AND pr.supermercado_id = $${params.length - 2}) AS precio_actual,
         (SELECT pr.fecha_actualizacion FROM precios pr
          WHERE pr.producto_id = p.id AND pr.supermercado_id = $${params.length - 2}) AS fecha_precio
         ` : `
         NULL::numeric AS precio_actual,
         NULL::timestamptz AS fecha_precio
         `}
       FROM productos p
       ${where}
       ORDER BY p.nombre, p.variante
       LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params
    );

    return res.json({
      productos: dataResult.rows,
      paginacion: {
        page,
        per_page: perPage,
        total,
        total_paginas: Math.ceil(total / perPage),
      },
    });
  } catch (err) {
    console.error('Error listando productos:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

async function getById(req, res) {
  const id = req.params.id;

  try {
    const productoResult = await pool.query(
      `SELECT
         p.id, p.nombre, p.marca, p.tamano, p.presentacion, p.variante,
         p.cantidad_valor, p.cantidad_unidad,
         p.foto_url, p.confianza_promedio, p.categoria_id,
         c.nombre AS categoria_nombre
       FROM productos p
       LEFT JOIN categorias c ON c.id = p.categoria_id
       WHERE p.id = $1`,
      [id]
    );

    if (productoResult.rows.length === 0) {
      return res.status(404).json({
        error: { code: 'NO_ENCONTRADO', message: 'Producto no encontrado' },
      });
    }

    const producto = productoResult.rows[0];

    const preciosResult = await pool.query(
      `SELECT
         pr.precio,
         pr.fecha_actualizacion,
         pr.confianza_usuario,
         s.id AS supermercado_id,
         s.nombre AS supermercado_nombre,
         s.cadena AS supermercado_cadena
       FROM precios pr
       JOIN supermercados s ON s.id = pr.supermercado_id
       WHERE pr.producto_id = $1 AND s.activo = TRUE
       ORDER BY pr.precio ASC`,
      [id]
    );

    return res.json({
      producto,
      precios: preciosResult.rows,
    });
  } catch (err) {
    // Si el id no es un UUID válido, PostgreSQL lanza un error
    if (err.code === '22P02') {
      return res.status(400).json({
        error: { code: 'ID_INVALIDO', message: 'El id no es válido' },
      });
    }
    console.error('Error getById producto:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

async function buscar(req, res) {
  const q = (req.query.q || '').trim();

  if (q.length < 2) {
    return res.status(400).json({
      error: {
        code: 'QUERY_CORTA',
        message: 'Escribe al menos 2 caracteres para buscar',
      },
    });
  }

  try {
    const { rows } = await pool.query(
      `SELECT
         p.id, p.nombre, p.marca, p.tamano, p.presentacion, p.variante,
         p.cantidad_valor, p.cantidad_unidad, p.categoria_id,
         similarity(unaccent(lower(p.nombre || ' ' || p.marca)), unaccent(lower($1))) AS similitud
       FROM productos p
       WHERE unaccent(lower(p.nombre || ' ' || p.marca)) % unaccent(lower($1))
       ORDER BY similitud DESC
       LIMIT 30`,
      [q]
    );

    return res.json({ productos: rows, query: q });
  } catch (err) {
    console.error('Error buscando productos:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

module.exports = { list, getById, buscar };