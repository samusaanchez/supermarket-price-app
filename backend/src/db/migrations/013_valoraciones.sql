-- ---------- VALORACIONES DE PRODUCTO ----------
-- Cada usuario puntúa un producto en dos ejes (1-5):
--  calidad = cómo de bueno es el producto.
--  precio  = cómo de buen precio le parece (5 = ganga, 1 = caro).
-- Una valoración por usuario y producto (se puede cambiar -> upsert).
CREATE TABLE valoraciones (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  producto_id UUID NOT NULL REFERENCES productos(id) ON DELETE CASCADE,
  usuario_id  UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  calidad     SMALLINT NOT NULL CHECK (calidad BETWEEN 1 AND 5),
  precio      SMALLINT NOT NULL CHECK (precio  BETWEEN 1 AND 5),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT uq_valoracion UNIQUE (producto_id, usuario_id)
);

CREATE INDEX idx_valoraciones_producto ON valoraciones(producto_id);
