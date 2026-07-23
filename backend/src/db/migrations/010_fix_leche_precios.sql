-- Borramos todos los precios de leche entera. Vamos a reinsertarlos
-- correctamente, distinguiendo por marca (no solo por nombre).
DELETE FROM precios_historico
WHERE producto_id IN (SELECT id FROM productos WHERE nombre = 'Leche entera');

DELETE FROM precios
WHERE producto_id IN (SELECT id FROM productos WHERE nombre = 'Leche entera');

-- Reinsertamos, esta vez uniendo también por marca.
INSERT INTO precios (producto_id, supermercado_id, precio, usuario_id, confianza_usuario, fuente)
SELECT p.id, s.id, precio, '792a69d8-1993-416a-ac9d-63b842c4e1d2', 50, 'manual'
FROM (VALUES
  ('Hacendado',                   1, 0.85::numeric),
  ('Central Lechera Asturiana',   2, 1.15),
  ('Central Lechera Asturiana',   3, 1.09),
  ('Central Lechera Asturiana',   5, 1.19)
) AS v(marca_prod, supermercado_id, precio)
JOIN productos p ON p.nombre = 'Leche entera' AND p.marca = v.marca_prod
JOIN supermercados s ON s.id = v.supermercado_id;

INSERT INTO precios_historico (producto_id, supermercado_id, precio, usuario_id)
SELECT producto_id, supermercado_id, precio, usuario_id
FROM precios
WHERE producto_id IN (SELECT id FROM productos WHERE nombre = 'Leche entera');