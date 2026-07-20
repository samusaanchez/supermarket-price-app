const express = require('express');

const app = express();
const PORT = 3000;

app.get('/api/v1/ping', (req, res) => {
  res.json({ message: 'pong' });
});

app.listen(PORT, () => {
  console.log(`API escuchando en http://localhost:${PORT}`);
});