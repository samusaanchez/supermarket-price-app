const jwt = require('jsonwebtoken');

const SECRET = process.env.JWT_SECRET;
const ACCESS_EXPIRES = process.env.JWT_EXPIRES_IN || '1h';
const REFRESH_EXPIRES = process.env.REFRESH_TOKEN_EXPIRES_IN || '7d';

if (!SECRET) {
  throw new Error('JWT_SECRET no está definido en el .env');
}

function signAccessToken(userId) {
  return jwt.sign({ sub: userId, type: 'access' }, SECRET, {
    expiresIn: ACCESS_EXPIRES,
  });
}

function signRefreshToken(userId) {
  return jwt.sign({ sub: userId, type: 'refresh' }, SECRET, {
    expiresIn: REFRESH_EXPIRES,
  });
}

function verify(token) {
  return jwt.verify(token, SECRET);
}

module.exports = { signAccessToken, signRefreshToken, verify };