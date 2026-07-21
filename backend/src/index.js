require('dotenv').config();
const express = require('express');
const authRoutes = require('./routes/auth');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.get('/api/v1/ping', (req, res) => {
  res.json({ message: 'pong' });
});

app.use('/api/v1/auth', authRoutes);

app.listen(PORT, () => {
  console.log(`API escuchando en http://localhost:${PORT}`);
});