-- ---------- CATEGORÍAS ----------
CREATE TABLE categorias (
  id     SERIAL PRIMARY KEY,
  nombre VARCHAR(100) UNIQUE NOT NULL,
  icono  VARCHAR(50),
  orden  INT DEFAULT 0
);

CREATE INDEX idx_categorias_orden ON categorias(orden, nombre);

-- ---------- PRODUCTOS ----------
CREATE TABLE productos (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre              VARCHAR(500) NOT NULL,
  marca               VARCHAR(255) NOT NULL,
  tamano              VARCHAR(100) NOT NULL,
  presentacion        VARCHAR(100) NOT NULL,
  categoria_id        INT REFERENCES categorias(id),
  codigo_barras       VARCHAR(50),
  foto_url            VARCHAR(500),
  confianza_promedio  NUMERIC(5,2) DEFAULT 0,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT uq_producto UNIQUE (marca, tamano, presentacion)
);

CREATE INDEX idx_productos_categoria ON productos(categoria_id);
CREATE INDEX idx_productos_barras    ON productos(codigo_barras)
  WHERE codigo_barras IS NOT NULL;

-- Búsqueda difusa por nombre y marca (usa pg_trgm)
CREATE INDEX idx_productos_busqueda ON productos
  USING gin ((nombre || ' ' || marca) gin_trgm_ops);

-- ---------- PRECIOS (estado actual) ----------
CREATE TABLE precios (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  producto_id           UUID NOT NULL REFERENCES productos(id) ON DELETE CASCADE,
  supermercado_id       INT  NOT NULL REFERENCES supermercados(id),
  precio                NUMERIC(10,2) NOT NULL CHECK (precio > 0 AND precio < 10000),
  usuario_id            UUID REFERENCES usuarios(id),
  confianza_usuario     NUMERIC(5,2),
  fecha_actualizacion   TIMESTAMPTZ DEFAULT NOW(),
  fuente                VARCHAR(20) CHECK (fuente IN ('ticket','foto','manual')),
  CONSTRAINT uq_precio UNIQUE (producto_id, supermercado_id)
);

CREATE INDEX idx_precios_super  ON precios(supermercado_id);
CREATE INDEX idx_precios_fecha  ON precios(fecha_actualizacion DESC);

-- ---------- HISTÓRICO DE PRECIOS ----------
CREATE TABLE precios_historico (
  id              BIGSERIAL PRIMARY KEY,
  producto_id     UUID NOT NULL REFERENCES productos(id) ON DELETE CASCADE,
  supermercado_id INT  NOT NULL REFERENCES supermercados(id),
  precio          NUMERIC(10,2) NOT NULL,
  usuario_id      UUID REFERENCES usuarios(id),
  fecha           TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_hist_producto
  ON precios_historico(producto_id, supermercado_id, fecha DESC);