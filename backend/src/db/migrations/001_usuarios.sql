CREATE TABLE usuarios (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email             VARCHAR(255) UNIQUE NOT NULL,
  password_hash     VARCHAR(255) NOT NULL,
  nombre            VARCHAR(255),
  confiabilidad     NUMERIC(5,2) DEFAULT 50 CHECK (confiabilidad BETWEEN 0 AND 100),
  tickets_subidos   INT DEFAULT 0,
  fotos_verificadas INT DEFAULT 0,
  errores           INT DEFAULT 0,
  reclamaciones     INT DEFAULT 0,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  last_login        TIMESTAMPTZ
);

CREATE INDEX idx_usuarios_email ON usuarios(email);