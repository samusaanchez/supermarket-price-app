const express = require('express');
const controller = require('../controllers/productosController');
const { authRequired } = require('../middleware/auth');

const router = express.Router();

router.get('/', authRequired, controller.list);
router.get('/buscar', authRequired, controller.buscar);
router.get('/:id', authRequired, controller.getById);

module.exports = router;