const bcrypt = require('bcrypt');

const BCRYPT_COST = 10;

async function hash(plainPassword) {
  return bcrypt.hash(plainPassword, BCRYPT_COST);
}

async function verify(plainPassword, storedHash) {
  return bcrypt.compare(plainPassword, storedHash);
}

module.exports = { hash, verify };