const express = require('express');
const controller = require('../controllers/supermercadosController');
const { authRequired } = require('../middleware/auth');

const router = express.Router();

router.get('/', authRequired, controller.list);
router.post('/', authRequired, controller.crear);
router.get('/:id', authRequired, controller.getById);

module.exports = router;