require('dotenv').config();
const express = require('express');
const cors = require('cors');
const authRoutes = require('./routes/auth');
const supermercadosRoutes = require('./routes/supermercados');

const app = express();
const PORT = process.env.PORT || 3000;
const categoriasRoutes = require('./routes/categorias');
const productosRoutes = require('./routes/productos');
const listasRoutes = require('./routes/listas');

app.use(cors());
app.use(express.json());

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