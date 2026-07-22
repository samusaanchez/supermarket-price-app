CREATE TABLE supermercados (
  id         SERIAL PRIMARY KEY,
  nombre     VARCHAR(255) NOT NULL,
  cadena     VARCHAR(100),
  lat        NUMERIC(9,6) NOT NULL,
  lng        NUMERIC(9,6) NOT NULL,
  direccion  TEXT,
  horario    VARCHAR(255),
  activo     BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_super_geo ON supermercados(lat, lng);
CREATE INDEX idx_super_activo ON supermercados(activo) WHERE activo = TRUE;