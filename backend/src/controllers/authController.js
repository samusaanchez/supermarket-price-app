const pool = require('../db/pool');
const passwordService = require('../services/password');

async function register(req, res) {
  const { email, password, nombre } = req.body;

  // Validación mínima
  if (!email || !password) {
    return res.status(400).json({
      error: {
        code: 'DATOS_INVALIDOS',
        message: 'email y password son obligatorios',
      },
    });
  }

  if (password.length < 8) {
    return res.status(400).json({
      error: {
        code: 'PASSWORD_CORTA',
        message: 'La contraseña debe tener al menos 8 caracteres',
      },
    });
  }

  try {
    const passwordHash = await passwordService.hash(password);

    const { rows } = await pool.query(
      `INSERT INTO usuarios (email, password_hash, nombre)
       VALUES ($1, $2, $3)
       RETURNING id, email, nombre, confiabilidad, created_at`,
      [email.toLowerCase(), passwordHash, nombre || null]
    );

    return res.status(201).json({ user: rows[0] });
  } catch (err) {
    // Email duplicado: la BD lo bloquea con su UNIQUE, aquí lo traducimos
    if (err.code === '23505') {
      return res.status(409).json({
        error: {
          code: 'EMAIL_YA_REGISTRADO',
          message: 'Ese email ya está en uso',
        },
      });
    }
    console.error('Error en register:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

module.exports = { register };