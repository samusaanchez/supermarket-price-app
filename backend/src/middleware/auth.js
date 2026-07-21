const tokenService = require('../services/token');

function authRequired(req, res, next) {
  const header = req.headers.authorization;

  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({
      error: {
        code: 'TOKEN_FALTA',
        message: 'Falta el token de autenticación',
      },
    });
  }

  const token = header.slice(7); // quita "Bearer "

  try {
    const payload = tokenService.verify(token);

    if (payload.type !== 'access') {
      return res.status(401).json({
        error: {
          code: 'TOKEN_TIPO_INVALIDO',
          message: 'Se esperaba un access token',
        },
      });
    }

    req.userId = payload.sub;
    next();
  } catch (err) {
    return res.status(401).json({
      error: {
        code: 'TOKEN_INVALIDO',
        message: 'Token inválido o expirado',
      },
    });
  }
}

module.exports = { authRequired };