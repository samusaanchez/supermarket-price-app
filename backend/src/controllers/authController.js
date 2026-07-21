const tokenService = require('../services/token');
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

async function login(req, res) {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({
      error: {
        code: 'DATOS_INVALIDOS',
        message: 'email y password son obligatorios',
      },
    });
  }

  try {
    const { rows } = await pool.query(
      `SELECT id, email, nombre, confiabilidad, password_hash
       FROM usuarios
       WHERE email = $1`,
      [email.toLowerCase()]
    );

    const user = rows[0];

    // Mismo error para "no existe" y "contraseña mal": no damos pistas
    const passwordOk = user
      ? await passwordService.verify(password, user.password_hash)
      : false;

    if (!user || !passwordOk) {
      return res.status(401).json({
        error: {
          code: 'CREDENCIALES_INVALIDAS',
          message: 'Email o contraseña incorrectos',
        },
      });
    }

    // Actualizamos last_login (no bloqueante, si falla no importa)
    pool.query('UPDATE usuarios SET last_login = NOW() WHERE id = $1', [user.id])
      .catch((err) => console.error('No se pudo actualizar last_login:', err));

    const accessToken = tokenService.signAccessToken(user.id);
    const refreshToken = tokenService.signRefreshToken(user.id);

    return res.json({
      user: {
        id: user.id,
        email: user.email,
        nombre: user.nombre,
        confiabilidad: user.confiabilidad,
      },
      accessToken,
      refreshToken,
    });
  } catch (err) {
    console.error('Error en login:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

async function getMe(req, res) {
  try {
    const { rows } = await pool.query(
      `SELECT id, email, nombre, confiabilidad,
              tickets_subidos, fotos_verificadas,
              created_at, last_login
       FROM usuarios
       WHERE id = $1`,
      [req.userId]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        error: { code: 'USUARIO_NO_EXISTE', message: 'Usuario no encontrado' },
      });
    }

    return res.json({ user: rows[0] });
  } catch (err) {
    console.error('Error en getMe:', err);
    return res.status(500).json({
      error: { code: 'ERROR_INTERNO', message: 'Algo falló' },
    });
  }
}

module.exports = { register, login, getMe };
