-- =========================================================
--  SEMANAS 9-12 · FASE A · Tablas de tickets, OCR y reputación
-- =========================================================
--  El OCR escribe SIEMPRE en tickets/ticket_items (borrador).
--  Nunca toca 'precios' ni 'productos' hasta que el usuario confirma.
-- =========================================================

-- ---------- TICKETS (foto subida por el usuario) ----------
CREATE TABLE tickets (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id       UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  -- Nullable: al subir la foto aún no sabemos la tienda; se elige en la revisión.
  supermercado_id  INT REFERENCES supermercados(id),
  foto_url         VARCHAR(500) NOT NULL,
  estado           VARCHAR(20) NOT NULL DEFAULT 'pendiente'
                     CHECK (estado IN ('pendiente','procesando','completado','error')),
  -- Datos opcionales que el usuario puede confirmar en la revisión.
  total_ticket     NUMERIC(10,2) CHECK (total_ticket IS NULL OR total_ticket >= 0),
  fecha_compra     DATE,
  error_mensaje    TEXT,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_tickets_usuario ON tickets(usuario_id, created_at DESC);
CREATE INDEX idx_tickets_estado  ON tickets(estado);

-- ---------- TICKET_ITEMS (líneas extraídas por el OCR) ----------
CREATE TABLE ticket_items (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id          UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  -- Texto original tal cual lo leyó el OCR. Nunca se pierde.
  texto_ocr          TEXT NOT NULL,
  -- Nullable: se rellena en la revisión al elegir/crear el producto.
  producto_id        UUID REFERENCES productos(id) ON DELETE SET NULL,
  -- Lo que leyó el OCR (crudo) y lo que confirma el usuario (lo que irá a 'precios').
  precio_ocr         NUMERIC(10,2),
  precio_confirmado  NUMERIC(10,2) CHECK (precio_confirmado IS NULL OR precio_confirmado > 0),
  -- Frescos de peso variable: peso de ESTA compra (registro, no toca el catálogo).
  peso               NUMERIC(10,3) CHECK (peso IS NULL OR peso > 0),
  es_peso_variable   BOOLEAN NOT NULL DEFAULT FALSE,
  cantidad           INT NOT NULL DEFAULT 1 CHECK (cantidad > 0),
  estado             VARCHAR(20) NOT NULL DEFAULT 'pendiente'
                       CHECK (estado IN ('pendiente','confirmado','descartado')),
  orden              INT NOT NULL DEFAULT 0,
  created_at         TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ticket_items_ticket ON ticket_items(ticket_id, orden);

-- ---------- FOTOS (fotos de producto para el catálogo) ----------
CREATE TABLE fotos (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  producto_id      UUID NOT NULL REFERENCES productos(id) ON DELETE CASCADE,
  usuario_id       UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  url              VARCHAR(500) NOT NULL,
  votos_positivos  INT NOT NULL DEFAULT 0,
  votos_negativos  INT NOT NULL DEFAULT 0,
  estado           VARCHAR(20) NOT NULL DEFAULT 'pendiente'
                     CHECK (estado IN ('pendiente','verificada','rechazada')),
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_fotos_producto ON fotos(producto_id, estado);

-- ---------- VOTOS_FOTOS (un voto por usuario y foto) ----------
CREATE TABLE votos_fotos (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  foto_id     UUID NOT NULL REFERENCES fotos(id) ON DELETE CASCADE,
  usuario_id  UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  voto        SMALLINT NOT NULL CHECK (voto IN (-1, 1)),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT uq_voto_foto_usuario UNIQUE (foto_id, usuario_id)
);

CREATE INDEX idx_votos_foto ON votos_fotos(foto_id);

-- ---------- RECLAMACIONES (reportes de precio o foto incorrectos) ----------
CREATE TABLE reclamaciones (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id   UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  tipo         VARCHAR(20) NOT NULL CHECK (tipo IN ('precio','foto')),
  -- Solo uno de los dos se rellena según el tipo.
  precio_id    UUID REFERENCES precios(id) ON DELETE CASCADE,
  foto_id      UUID REFERENCES fotos(id) ON DELETE CASCADE,
  motivo       TEXT,
  estado       VARCHAR(20) NOT NULL DEFAULT 'pendiente'
                 CHECK (estado IN ('pendiente','resuelta','rechazada')),
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  resolved_at  TIMESTAMPTZ,
  -- Coherencia: el objetivo reclamado debe corresponder con el tipo.
  CONSTRAINT chk_reclamacion_objetivo CHECK (
    (tipo = 'precio' AND precio_id IS NOT NULL AND foto_id IS NULL) OR
    (tipo = 'foto'   AND foto_id   IS NOT NULL AND precio_id IS NULL)
  )
);

CREATE INDEX idx_reclamaciones_estado ON reclamaciones(estado, created_at DESC);
