-- ---------- LISTAS DE LA COMPRA ----------
CREATE TABLE listas_compra (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id  UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  nombre      VARCHAR(255) NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_listas_usuario ON listas_compra(usuario_id, updated_at DESC);

-- ---------- ITEMS DE UNA LISTA ----------
CREATE TABLE lista_items (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lista_id     UUID NOT NULL REFERENCES listas_compra(id) ON DELETE CASCADE,
  producto_id  UUID NOT NULL REFERENCES productos(id) ON DELETE CASCADE,
  cantidad     INT NOT NULL DEFAULT 1 CHECK (cantidad > 0 AND cantidad <= 999),
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT uq_lista_producto UNIQUE (lista_id, producto_id)
);

CREATE INDEX idx_lista_items_lista ON lista_items(lista_id);