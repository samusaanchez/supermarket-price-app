-- Añadimos cantidad estructurada para calcular precio por unidad de referencia.
-- El campo 'tamano' sigue siendo el texto de display ("2L", "500g"),
-- estos dos campos son la versión "para calcular".
ALTER TABLE productos
  ADD COLUMN cantidad_valor  NUMERIC(10,3),
  ADD COLUMN cantidad_unidad VARCHAR(10);

-- Restricción: si un campo se rellena, el otro también.
ALTER TABLE productos ADD CONSTRAINT chk_cantidad_ambos
  CHECK (
    (cantidad_valor IS NULL AND cantidad_unidad IS NULL) OR
    (cantidad_valor IS NOT NULL AND cantidad_unidad IS NOT NULL)
  );

-- Restricción: unidades permitidas.
ALTER TABLE productos ADD CONSTRAINT chk_cantidad_unidad
  CHECK (cantidad_unidad IS NULL OR cantidad_unidad IN ('L', 'ml', 'kg', 'g', 'ud'));

-- Rellenamos los 21 productos existentes.
UPDATE productos SET cantidad_valor = 2,     cantidad_unidad = 'L'  WHERE nombre = 'Coca-Cola'          AND variante = '';
UPDATE productos SET cantidad_valor = 2,     cantidad_unidad = 'L'  WHERE nombre = 'Coca-Cola Zero'     AND variante = 'zero';
UPDATE productos SET cantidad_valor = 1.5,   cantidad_unidad = 'L'  WHERE nombre = 'Agua mineral';
UPDATE productos SET cantidad_valor = 1980,  cantidad_unidad = 'ml' WHERE nombre = 'Cerveza rubia pack'; -- 6 x 330 ml

UPDATE productos SET cantidad_valor = 1,     cantidad_unidad = 'L'  WHERE nombre = 'Leche entera';
UPDATE productos SET cantidad_valor = 500,   cantidad_unidad = 'g'  WHERE nombre = 'Yogur natural pack 4'; -- 4 x 125 g
UPDATE productos SET cantidad_valor = 12,    cantidad_unidad = 'ud' WHERE nombre = 'Huevos frescos M';
UPDATE productos SET cantidad_valor = 300,   cantidad_unidad = 'g'  WHERE nombre = 'Queso curado';

UPDATE productos SET cantidad_valor = 1,     cantidad_unidad = 'kg' WHERE nombre = 'Plátano de Canarias';
UPDATE productos SET cantidad_valor = 1,     cantidad_unidad = 'kg' WHERE nombre = 'Manzana Golden';
UPDATE productos SET cantidad_valor = 1,     cantidad_unidad = 'kg' WHERE nombre = 'Tomate pera';
UPDATE productos SET cantidad_valor = 1,     cantidad_unidad = 'ud' WHERE nombre = 'Aguacate';

UPDATE productos SET cantidad_valor = 500,   cantidad_unidad = 'g'  WHERE nombre = 'Pechuga de pollo fileteada';
UPDATE productos SET cantidad_valor = 400,   cantidad_unidad = 'g'  WHERE nombre = 'Merluza congelada';
UPDATE productos SET cantidad_valor = 300,   cantidad_unidad = 'g'  WHERE nombre = 'Salmón fresco';

UPDATE productos SET cantidad_valor = 460,   cantidad_unidad = 'g'  WHERE nombre = 'Pan de molde integral';
UPDATE productos SET cantidad_valor = 250,   cantidad_unidad = 'g'  WHERE nombre = 'Baguette';

UPDATE productos SET cantidad_valor = 600,   cantidad_unidad = 'ml' WHERE nombre = 'Gel de ducha';
UPDATE productos SET cantidad_valor = 75,    cantidad_unidad = 'ml' WHERE nombre = 'Pasta de dientes';
UPDATE productos SET cantidad_valor = 38,    cantidad_unidad = 'ud' WHERE nombre = 'Detergente cápsulas';