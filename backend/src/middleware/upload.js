const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Carpeta física donde se guardan las fotos (backend/uploads).
const UPLOAD_DIR = path.join(__dirname, '..', '..', 'uploads');

// Se crea al arrancar si no existe.
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOAD_DIR),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const unico = `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`;
    cb(null, unico);
  },
});

// Solo aceptamos imágenes.
function fileFilter(req, file, cb) {
  cb(null, file.mimetype.startsWith('image/'));
}

const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
});

module.exports = { upload, UPLOAD_DIR };
