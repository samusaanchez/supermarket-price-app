const express = require('express');
const controller = require('../controllers/productosController');
const { authRequired } = require('../middleware/auth');

const router = express.Router();

router.get('/', authRequired, controller.list);
router.get('/buscar', authRequired, controller.buscar);
router.get('/barcode/:codigo', authRequired, controller.porCodigo);
router.post('/', authRequired, controller.crear);
router.get('/:id', authRequired, controller.getById);
router.post('/:id/valoraciones', authRequired, controller.valorar);

module.exports = router;