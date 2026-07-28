const pool = require('../db/pool');

async function list(req, res) {
  const lat = parseFloat(req.query.lat);
  const lng = parseFloat(req.query.lng);
  const radioKm = parseFloat(req.query.radio) || 10;

  const hasCoords = !isNaN(lat) && !isNaN(lng);

  try {
    let sql;
    let params;

    if (hasCoords) {
      // Haversine en SQL: 6371 = radio de la Tierra en km
      sql = `
        SELECT * FROM (
          SELECT
            id, nombre, cadena, lat, lng, direccion, horario,
            6371 * acos(
              cos(radians($1)) * cos(radians(lat)) *
              cos(radians(lng) - radians($2)) +
              sin(radians($1)) * sin(radians(lat))
            ) AS distancia_km
          FROM supermercados
          WHERE activo = TRUE
        ) sub
        WHERE distancia_km <= $3
        ORDER BY distancia_km ASC
      `;
      params = [lat, lng, radioKm];
    } else {
      sql = `
        SELECT id, nombre, cadena, lat, lng, direccion, horario
        FROM supermercados
        WHERE activo = TRUE
        ORDER BY nombre ASC
      `;
      params = [];
    }

    const { rows } = await pool.query(sql, params);
    return res.json({ supermercados: rows });
  } catch (err) {
    console.error('Error listando supermercados:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

async function getById(req, res) {
  const id = parseInt(req.params.id, 10);
  if (isNaN(id)) {
    return res.status(400).json({
      error: { code: 'ID_INVALIDO', message: 'El id debe ser un número' },
    });
  }

  try {
    const { rows } = await pool.query(
      `SELECT id, nombre, cadena, lat, lng, direccion, horario
       FROM supermercados
       WHERE id = $1 AND activo = TRUE`,
      [id]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        error: { code: 'NO_ENCONTRADO', message: 'Supermercado no encontrado' },
      });
    }

    return res.json({ supermercado: rows[0] });
  } catch (err) {
    console.error('Error getById supermercado:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

// POST /supermercados  (alta de un supermercado; nivel 1: entra activo)
async function crear(req, res) {
  const nombre = (req.body.nombre || '').trim();
  const cadena = (req.body.cadena || '').trim() || null;
  const direccion = (req.body.direccion || '').trim() || null;
  const horario = (req.body.horario || '').trim() || null;
  const lat = Number(req.body.lat);
  const lng = Number(req.body.lng);

  if (!nombre) {
    return res.status(400).json({
      error: { code: 'NOMBRE_REQUERIDO', message: 'El nombre es obligatorio' },
    });
  }
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return res.status(400).json({
      error: {
        code: 'UBICACION_REQUERIDA',
        message: 'Falta la ubicación (lat/lng)',
      },
    });
  }

  try {
    const { rows } = await pool.query(
      `INSERT INTO supermercados (nombre, cadena, lat, lng, direccion, horario, activo)
       VALUES ($1, $2, $3, $4, $5, $6, TRUE)
       RETURNING id, nombre, cadena, lat, lng, direccion, horario`,
      [nombre, cadena, lat, lng, direccion, horario]
    );
    return res.status(201).json({ supermercado: rows[0] });
  } catch (err) {
    console.error('Error creando supermercado:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

module.exports = { list, getById, crear };