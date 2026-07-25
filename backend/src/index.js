require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const authRoutes = require('./routes/auth');
const supermercadosRoutes = require('./routes/supermercados');

const app = express();
const PORT = process.env.PORT || 3000;
const categoriasRoutes = require('./routes/categorias');
const productosRoutes = require('./routes/productos');
const listasRoutes = require('./routes/listas');
const ticketsRoutes = require('./routes/tickets');
const fotosRoutes = require('./routes/fotos');

app.use(cors());
app.use(express.json());

// Sirve las fotos subidas (backend/uploads) en /uploads.
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

app.get('/api/v1/ping', (req, res) => {
  res.json({ message: 'pong' });
});

app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/supermercados', supermercadosRoutes);

app.listen(PORT, () => {
  console.log(`API escuchando en http://localhost:${PORT}`);
});

app.use('/api/v1/categorias', categoriasRoutes);
app.use('/api/v1/productos', productosRoutes);
app.use('/api/v1/listas', listasRoutes);
app.use('/api/v1/tickets', ticketsRoutes);
app.use('/api/v1/fotos', fotosRoutes);