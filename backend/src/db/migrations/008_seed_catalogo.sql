-- ---------- CATEGORÍAS ----------
INSERT INTO categorias (nombre, icono, orden) VALUES
  ('Frutas y verduras',   'eco',            1),
  ('Carnes y pescados',   'set_meal',       2),
  ('Lácteos y huevos',    'egg',            3),
  ('Bebidas',             'local_drink',    4),
  ('Panadería',           'bakery_dining',  5),
  ('Higiene y limpieza',  'soap',           6);

-- ---------- PRODUCTOS ----------
-- Frutas y verduras
INSERT INTO productos (nombre, marca, tamano, presentacion, variante, categoria_id) VALUES
  ('Plátano de Canarias', 'Sin marca', '1kg', 'granel', 'platano',  1),
  ('Manzana Golden',      'Sin marca', '1kg', 'granel', 'manzana',  1),
  ('Tomate pera',         'Sin marca', '1kg', 'granel', 'tomate',   1),
  ('Aguacate',            'Sin marca', '1ud', 'unidad', 'aguacate', 1);

-- Carnes y pescados
INSERT INTO productos (nombre, marca, tamano, presentacion, variante, categoria_id) VALUES
  ('Pechuga de pollo fileteada', 'Sin marca',  '500g', 'bandeja', 'pollo',   2),
  ('Merluza congelada',          'Pescanova',  '400g', 'bolsa',   '',        2),
  ('Salmón fresco',              'Sin marca',  '300g', 'filete',  'salmon',  2);

-- Lácteos y huevos
INSERT INTO productos (nombre, marca, tamano, presentacion, variante, categoria_id) VALUES
  ('Leche entera',         'Hacendado',                   '1L',    'brick',  '',       3),
  ('Leche entera',         'Central Lechera Asturiana',   '1L',    'brick',  '',       3),
  ('Yogur natural pack 4', 'Danone',                      '4x125g', 'pack',  '',       3),
  ('Huevos frescos M',     'Sin marca',                   '12ud',  'cartón', 'huevos', 3),
  ('Queso curado',         'García Baquero',              '300g',  'cuña',   '',       3);

-- Bebidas
INSERT INTO productos (nombre, marca, tamano, presentacion, variante, categoria_id) VALUES
  ('Coca-Cola',          'Coca-Cola',  '2L',    'botella', '',      4),
  ('Coca-Cola Zero',     'Coca-Cola',  '2L',    'botella', 'zero',  4),
  ('Agua mineral',       'Bezoya',     '1.5L',  'botella', '',      4),
  ('Cerveza rubia pack', 'Mahou',      '6x33cl', 'pack',   '',      4);

-- Panadería
INSERT INTO productos (nombre, marca, tamano, presentacion, variante, categoria_id) VALUES
  ('Pan de molde integral', 'Bimbo',      '460g', 'bolsa',  '',         5),
  ('Baguette',              'Sin marca',  '250g', 'unidad', 'baguette', 5);

-- Higiene y limpieza
INSERT INTO productos (nombre, marca, tamano, presentacion, variante, categoria_id) VALUES
  ('Gel de ducha',         'Sanex',   '600ml', 'botella', '', 6),
  ('Pasta de dientes',     'Colgate', '75ml',  'tubo',    '', 6),
  ('Detergente cápsulas',  'Ariel',   '38ud',  'caja',    '', 6);

-- ---------- PRECIOS ----------
INSERT INTO precios (producto_id, supermercado_id, precio, usuario_id, confianza_usuario, fuente)
SELECT p.id, s.id, precio, '792a69d8-1993-416a-ac9d-63b842c4e1d2', 50, 'manual'
FROM (VALUES
  ('Coca-Cola',      '2L',    'botella', '',      1, 1.95::numeric),
  ('Coca-Cola',      '2L',    'botella', '',      2, 1.89),
  ('Coca-Cola',      '2L',    'botella', '',      3, 1.79),
  ('Coca-Cola',      '2L',    'botella', '',      5, 2.10),
  ('Coca-Cola Zero', '2L',    'botella', 'zero',  1, 1.95),
  ('Coca-Cola Zero', '2L',    'botella', 'zero',  5, 2.10),
  ('Agua mineral',   '1.5L',  'botella', '',      1, 0.55),
  ('Agua mineral',   '1.5L',  'botella', '',      2, 0.49),
  ('Agua mineral',   '1.5L',  'botella', '',      3, 0.45),
  ('Cerveza rubia pack', '6x33cl', 'pack', '',    1, 4.20),
  ('Cerveza rubia pack', '6x33cl', 'pack', '',    5, 4.35),
  ('Leche entera',   '1L',    'brick', '',        1, 0.85),
  ('Leche entera',   '1L',    'brick', '',        2, 1.15),
  ('Leche entera',   '1L',    'brick', '',        3, 1.09),
  ('Leche entera',   '1L',    'brick', '',        5, 1.19),
  ('Yogur natural pack 4', '4x125g', 'pack', '',  1, 1.85),
  ('Yogur natural pack 4', '4x125g', 'pack', '',  2, 1.95),
  ('Yogur natural pack 4', '4x125g', 'pack', '',  5, 2.05),
  ('Huevos frescos M', '12ud', 'cartón', 'huevos', 1, 2.20),
  ('Huevos frescos M', '12ud', 'cartón', 'huevos', 2, 2.35),
  ('Huevos frescos M', '12ud', 'cartón', 'huevos', 3, 2.15),
  ('Huevos frescos M', '12ud', 'cartón', 'huevos', 4, 2.05),
  ('Queso curado',   '300g',  'cuña', '',         1, 4.95),
  ('Queso curado',   '300g',  'cuña', '',         5, 5.20),
  ('Pan de molde integral', '460g', 'bolsa', '',  1, 1.79),
  ('Pan de molde integral', '460g', 'bolsa', '',  2, 1.85),
  ('Pan de molde integral', '460g', 'bolsa', '',  5, 1.99),
  ('Gel de ducha',   '600ml', 'botella', '',      1, 3.50),
  ('Gel de ducha',   '600ml', 'botella', '',      2, 3.75),
  ('Pasta de dientes', '75ml', 'tubo', '',        1, 1.99),
  ('Pasta de dientes', '75ml', 'tubo', '',        2, 2.15),
  ('Pasta de dientes', '75ml', 'tubo', '',        5, 2.25),
  ('Detergente cápsulas', '38ud', 'caja', '',     1, 9.95),
  ('Detergente cápsulas', '38ud', 'caja', '',     5, 10.99),
  ('Plátano de Canarias', '1kg', 'granel', 'platano',  1, 1.85),
  ('Plátano de Canarias', '1kg', 'granel', 'platano',  2, 1.99),
  ('Plátano de Canarias', '1kg', 'granel', 'platano',  5, 2.15),
  ('Manzana Golden', '1kg', 'granel', 'manzana',  1, 1.65),
  ('Manzana Golden', '1kg', 'granel', 'manzana',  2, 1.75),
  ('Tomate pera',    '1kg', 'granel', 'tomate',   1, 1.99),
  ('Tomate pera',    '1kg', 'granel', 'tomate',   3, 1.89),
  ('Aguacate',       '1ud', 'unidad', 'aguacate', 1, 0.95),
  ('Aguacate',       '1ud', 'unidad', 'aguacate', 5, 1.10),
  ('Pechuga de pollo fileteada', '500g', 'bandeja', 'pollo', 1, 3.75),
  ('Pechuga de pollo fileteada', '500g', 'bandeja', 'pollo', 2, 3.99),
  ('Pechuga de pollo fileteada', '500g', 'bandeja', 'pollo', 5, 4.25),
  ('Merluza congelada', '400g', 'bolsa', '',      1, 4.50),
  ('Merluza congelada', '400g', 'bolsa', '',      5, 4.85),
  ('Salmón fresco',  '300g', 'filete', 'salmon',  5, 5.99),
  ('Baguette',       '250g', 'unidad', 'baguette', 1, 0.55),
  ('Baguette',       '250g', 'unidad', 'baguette', 2, 0.60)
) AS v(nombre_prod, tam, pres, vari, supermercado_id, precio)
JOIN productos p ON p.nombre = v.nombre_prod
                AND p.tamano = v.tam
                AND p.presentacion = v.pres
                AND p.variante = v.vari
JOIN supermercados s ON s.id = v.supermercado_id;

INSERT INTO precios_historico (producto_id, supermercado_id, precio, usuario_id)
SELECT producto_id, supermercado_id, precio, usuario_id
FROM precios;