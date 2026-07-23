const pool = require('../db/pool');

async function list(req, res) {
  try {
    const { rows } = await pool.query(
      `SELECT id, nombre, icono, orden
       FROM categorias
       ORDER BY orden, nombre`
    );
    return res.json({ categorias: rows });
  } catch (err) {
    console.error('Error listando categorías:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

module.exports = { list };