-- Añadimos columna 'variante' para distinguir Coca-Cola vs Coca-Cola Zero,
-- Plátano vs Manzana vs Tomate (todos "Sin marca 1kg granel"), etc.
ALTER TABLE productos
  ADD COLUMN variante VARCHAR(100) NOT NULL DEFAULT '';

-- Reemplazamos el UNIQUE antiguo por uno que incluye la variante.
ALTER TABLE productos DROP CONSTRAINT uq_producto;
ALTER TABLE productos ADD CONSTRAINT uq_producto
  UNIQUE (marca, tamano, presentacion, variante);