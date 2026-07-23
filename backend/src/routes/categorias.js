const express = require('express');
const controller = require('../controllers/categoriasController');
const { authRequired } = require('../middleware/auth');

const router = express.Router();

router.get('/', authRequired, controller.list);

module.exports = router;