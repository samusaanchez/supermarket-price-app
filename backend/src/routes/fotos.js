const express = require('express');
const controller = require('../controllers/fotosController');
const { authRequired } = require('../middleware/auth');
const { upload } = require('../middleware/upload');

const router = express.Router();

router.use(authRequired);

router.post('/', upload.single('foto'), controller.crear);
router.get('/', controller.listar);
router.post('/:id/votos', controller.votar);
router.delete('/:id', controller.eliminar);

module.exports = router;
