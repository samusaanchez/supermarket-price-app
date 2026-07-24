const express = require('express');
const controller = require('../controllers/listasController');
const { authRequired } = require('../middleware/auth');

const router = express.Router();

router.use(authRequired);

router.get('/', controller.list);
router.post('/', controller.create);
router.get('/:id', controller.getById);
router.patch('/:id', controller.rename);
router.delete('/:id', controller.remove);
router.post('/:id/items', controller.addItem);
router.patch('/:id/items/:itemId', controller.updateItem);
router.delete('/:id/items/:itemId', controller.removeItem);

module.exports = router;