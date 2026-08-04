const express = require('express');
const controller = require('../controllers/ticketsController');
const { authRequired } = require('../middleware/auth');
const { upload } = require('../middleware/upload');

const router = express.Router();

router.use(authRequired);

// El campo del formulario con la imagen debe llamarse "foto".
router.post('/', upload.single('foto'), controller.create);
router.get('/', controller.list);
router.post('/emparejar', controller.emparejar);
router.get('/:id', controller.getById);
router.post('/:id/ocr', controller.ocr);
router.post('/:id/confirmar', controller.confirmar);

module.exports = router;
