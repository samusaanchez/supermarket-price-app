const express = require('express');
const controller = require('../controllers/reclamacionesController');
const { authRequired } = require('../middleware/auth');

const router = express.Router();

router.use(authRequired);

router.post('/', controller.crear);
router.get('/', controller.listMias);

module.exports = router;
