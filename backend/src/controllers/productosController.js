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

    // Orden (lista blanca para evitar inyección).
    let orderBy;
    switch (req.query.orden) {
      case 'valoracion':
        orderBy = 'valoracion_media DESC NULLS LAST, p.nombre';
        break;
      case 'precio_asc':
        orderBy = 'precio_actual ASC NULLS LAST, p.nombre';
        break;
      case 'precio_desc':
        orderBy = 'precio_actual DESC NULLS LAST, p.nombre';
        break;
      default:
        orderBy = 'p.nombre, p.variante';
    }

    const dataResult = await pool.query(
      `SELECT
         p.id, p.nombre, p.marca, p.tamano, p.presentacion, p.variante,
         p.cantidad_valor, p.cantidad_unidad,
         COALESCE(p.foto_url, (
           SELECT f.url FROM fotos f
            WHERE f.producto_id = p.id
            ORDER BY (f.estado = 'verificada') DESC,
                     (f.votos_positivos - f.votos_negativos) DESC,
                     f.created_at DESC
            LIMIT 1)) AS foto_url,
         (SELECT ROUND(AVG((v.calidad + v.precio) / 2.0)::numeric, 1)
            FROM valoraciones v WHERE v.producto_id = p.id) AS valoracion_media,
         (SELECT COUNT(*) FROM valoraciones v WHERE v.producto_id = p.id)
            AS valoraciones_total,
         p.confianza_promedio, p.categoria_id,
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
       ORDER BY ${orderBy}
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

    // Valoración: medias de calidad y precio, total, y mi nota.
    const valResult = await pool.query(
      `SELECT
         ROUND(AVG(calidad)::numeric, 1) AS calidad_media,
         ROUND(AVG(precio)::numeric, 1)  AS precio_media,
         COUNT(*)::int AS total,
         MAX(CASE WHEN usuario_id = $2 THEN calidad END) AS mi_calidad,
         MAX(CASE WHEN usuario_id = $2 THEN precio  END) AS mi_precio
       FROM valoraciones
       WHERE producto_id = $1`,
      [id, req.userId]
    );

    return res.json({
      producto,
      precios: preciosResult.rows,
      valoracion: valResult.rows[0],
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
  const supermercadoId = parseInt(req.query.supermercado_id, 10);
  const tieneSuper = !isNaN(supermercadoId);

  if (q.length < 2) {
    return res.status(400).json({
      error: {
        code: 'QUERY_CORTA',
        message: 'Escribe al menos 2 caracteres para buscar',
      },
    });
  }

  try {
    const params = [q];
    // Si buscamos dentro de un supermercado, traemos su precio y
    // filtramos a productos que tengan precio en esa tienda.
    let precioSelect = `
      NULL::numeric AS precio_actual,
      NULL::timestamptz AS fecha_precio`;
    let filtroSuper = '';
    if (tieneSuper) {
      params.push(supermercadoId); // $2
      precioSelect = `
        (SELECT pr.precio FROM precios pr
          WHERE pr.producto_id = p.id AND pr.supermercado_id = $2) AS precio_actual,
        (SELECT pr.fecha_actualizacion FROM precios pr
          WHERE pr.producto_id = p.id AND pr.supermercado_id = $2) AS fecha_precio`;
      filtroSuper = `AND EXISTS (SELECT 1 FROM precios pr
                       WHERE pr.producto_id = p.id AND pr.supermercado_id = $2)`;
    }

    const { rows } = await pool.query(
      `SELECT
         p.id, p.nombre, p.marca, p.tamano, p.presentacion, p.variante,
         p.cantidad_valor, p.cantidad_unidad, p.categoria_id,
         (SELECT f.url FROM fotos f
            WHERE f.producto_id = p.id
            ORDER BY (f.estado = 'verificada') DESC,
                     (f.votos_positivos - f.votos_negativos) DESC,
                     f.created_at DESC
            LIMIT 1) AS foto_url,
         (SELECT ROUND(AVG((v.calidad + v.precio) / 2.0)::numeric, 1)
            FROM valoraciones v WHERE v.producto_id = p.id) AS valoracion_media,
         ${precioSelect},
         similarity(unaccent(lower(p.nombre || ' ' || p.marca)), unaccent(lower($1))) AS similitud
       FROM productos p
       WHERE unaccent(lower(p.nombre || ' ' || p.marca)) % unaccent(lower($1))
       ${filtroSuper}
       ORDER BY similitud DESC
       LIMIT 30`,
      params
    );

    return res.json({ productos: rows, query: q });
  } catch (err) {
    console.error('Error buscando productos:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

// POST /productos  (alta de producto nuevo, p.ej. desde una línea sin_match del ticket)
const UNIDADES = ['L', 'ml', 'kg', 'g', 'ud'];

async function crear(req, res) {
  const nombre = (req.body.nombre || '').trim();
  const marca = (req.body.marca || '').trim();
  const tamano = (req.body.tamano || '').trim();
  const presentacion = (req.body.presentacion || '').trim();
  const variante = (req.body.variante || '').trim();
  const categoriaId = req.body.categoria_id ?? null;
  const cantidadValor = req.body.cantidad_valor ?? null;
  const cantidadUnidad = req.body.cantidad_unidad ?? null;

  // Campos que identifican al producto (regla 1). El nombre también es obligatorio.
  if (!nombre || !marca || !tamano || !presentacion) {
    return res.status(400).json({
      error: {
        code: 'CAMPOS_REQUERIDOS',
        message: 'nombre, marca, tamano y presentacion son obligatorios',
      },
    });
  }

  // La cantidad estructurada es opcional, pero si viene una parte, vienen ambas.
  const tieneValor = cantidadValor !== null && cantidadValor !== '';
  const tieneUnidad = cantidadUnidad !== null && cantidadUnidad !== '';
  if (tieneValor !== tieneUnidad) {
    return res.status(400).json({
      error: {
        code: 'CANTIDAD_INCOMPLETA',
        message: 'cantidad_valor y cantidad_unidad deben ir juntos o ninguno',
      },
    });
  }
  if (tieneUnidad && !UNIDADES.includes(cantidadUnidad)) {
    return res.status(400).json({
      error: {
        code: 'UNIDAD_INVALIDA',
        message: `cantidad_unidad debe ser una de: ${UNIDADES.join(', ')}`,
      },
    });
  }

  try {
    const { rows } = await pool.query(
      `INSERT INTO productos
         (nombre, marca, tamano, presentacion, variante,
          categoria_id, cantidad_valor, cantidad_unidad)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id, nombre, marca, tamano, presentacion, variante,
                 categoria_id, cantidad_valor, cantidad_unidad`,
      [nombre, marca, tamano, presentacion, variante,
       categoriaId, tieneValor ? cantidadValor : null, tieneUnidad ? cantidadUnidad : null]
    );
    return res.status(201).json({ producto: rows[0], ya_existia: false });
  } catch (err) {
    // 23505 = violación de UNIQUE (marca, tamano, presentacion, variante).
    // En vez de fallar, devolvemos el producto que ya existe para que el
    // cliente lo reutilice (así el flujo de "crear desde ticket" no se corta).
    if (err.code === '23505') {
      const existing = await pool.query(
        `SELECT id, nombre, marca, tamano, presentacion, variante,
                categoria_id, cantidad_valor, cantidad_unidad
         FROM productos
         WHERE marca = $1 AND tamano = $2 AND presentacion = $3 AND variante = $4`,
        [marca, tamano, presentacion, variante]
      );
      return res.status(200).json({ producto: existing.rows[0], ya_existia: true });
    }
    console.error('Error creando producto:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

// POST /productos/:id/valoraciones  (calidad + precio, 1-5; una por usuario)
async function valorar(req, res) {
  const productoId = req.params.id;
  const calidad = Number(req.body.calidad);
  const precio = Number(req.body.precio);

  const ok = (n) => Number.isInteger(n) && n >= 1 && n <= 5;
  if (!ok(calidad) || !ok(precio)) {
    return res.status(400).json({
      error: {
        code: 'VALORACION_INVALIDA',
        message: 'calidad y precio deben ser enteros del 1 al 5',
      },
    });
  }

  try {
    const prod = await pool.query('SELECT id FROM productos WHERE id = $1', [
      productoId,
    ]);
    if (prod.rows.length === 0) {
      return res.status(404).json({
        error: { code: 'PRODUCTO_NO_ENCONTRADO', message: 'Producto no existe' },
      });
    }

    await pool.query(
      `INSERT INTO valoraciones (producto_id, usuario_id, calidad, precio)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (producto_id, usuario_id)
       DO UPDATE SET calidad = EXCLUDED.calidad,
                     precio  = EXCLUDED.precio,
                     updated_at = NOW()`,
      [productoId, req.userId, calidad, precio]
    );

    const agg = await pool.query(
      `SELECT ROUND(AVG(calidad)::numeric, 1) AS calidad_media,
              ROUND(AVG(precio)::numeric, 1)  AS precio_media,
              COUNT(*)::int AS total
       FROM valoraciones WHERE producto_id = $1`,
      [productoId]
    );

    return res.json({
      valoracion: {
        ...agg.rows[0],
        mi_calidad: calidad,
        mi_precio: precio,
      },
    });
  } catch (err) {
    if (err.code === '22P02') {
      return res.status(400).json({
        error: { code: 'ID_INVALIDO', message: 'El id no es válido' },
      });
    }
    console.error('Error valorando producto:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

module.exports = { list, getById, buscar, crear, valorar };