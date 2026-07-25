# Estado del proyecto — App de comparación de precios

_Última actualización: 25 julio 2026_

Documento de retomada rápida. Resume qué está hecho, las decisiones tomadas y qué
queda pendiente. Complementa a las instrucciones del proyecto (no las sustituye).

---

## Resumen en una línea

Fase A (backend de tickets/OCR/reputación) **cerrada y probada**. Fase B (Flutter)
**a medias**: subida de tickets y consulta hechas; falta la pantalla de revisión.
Modelo de validación cambiado a **híbrido** (ver decisiones).

---

## Estado por fases

### Fase A — Backend de tickets, fotos y reputación — HECHO

- Migración `012_tickets_ocr.sql`: tablas `tickets`, `ticket_items`, `fotos`,
  `votos_fotos`, `reclamaciones`. Aplicada y verificada.
- Ciclo de tickets completo y probado por curl:
  - `POST /tickets` — sube la foto (multipart, campo `foto`), crea ticket `pendiente`.
  - `GET /tickets` — lista mis tickets (con `num_items`, supermercado, estado).
  - `GET /tickets/:id` — ticket + líneas, con nombre de producto (JOIN).
  - `POST /tickets/emparejar` — **cerebro del híbrido**: recibe líneas de texto,
    devuelve candidatos + clasificación (`auto` / `revisar` / `sin_match`).
  - `POST /tickets/:id/confirmar` — vuelca precios en transacción (upsert en
    `precios` + append en `precios_historico`), marca ticket `completado`.
- Fotos de catálogo y votación (probado):
  - `POST /fotos` (multipart + `producto_id`), `GET /fotos?producto_id=`,
    `POST /fotos/:id/votos` (voto ±1, recuento y estado por umbrales).
- Alta de productos (probado):
  - `POST /productos` — crea producto nuevo; si ya existe (UNIQUE marca+tamaño+
    presentación+variante) devuelve el existente con `ya_existia: true`.

### Fase B — Flutter — A MEDIAS

Hecho y probado en Chrome:

- `ApiClient`: método `postMultipart` (subida de archivos con reintento de token)
  y constante `origin` para construir URLs de imágenes.
- `TicketsService`: `subir`, `list`, `getById`.
- Pantalla **Subir ticket** (`upload_ticket_screen.dart`): elegir de galería o
  cámara **y arrastrar y soltar** la imagen; previsualización; subida.
- Pantalla **Mis tickets** (`mis_tickets_screen.dart`): lista con miniatura,
  estado y nº de productos; botón "+" para subir; refresco al volver.
- Pantalla **Detalle de ticket** (`ticket_detail_screen.dart`): foto grande +
  lista de productos con precio.
- Entrada desde la `AppBar` del mapa (icono 🧾 → Mis tickets).
- Dependencias nuevas: `image_picker`, `http_parser`, `desktop_drop`.

Pendiente en Fase B:

- **Pantalla de revisión híbrida**: por cada línea llamar a `emparejar`, pintar
  verde/ámbar/rojo, confirmar automáticas, corregir dudosas, crear producto en las
  `sin_match`, y llamar a `confirmar`. (La pieza más grande que falta.)
- **OCR con ML Kit**: NO corre en web. Se integra al probar en móvil/emulador;
  rellenará las líneas que hoy se meten a mano.

### Fase C — Reputación — PENDIENTE

- Endpoints de reclamaciones (la tabla ya existe).
- Puntos de confiabilidad al usuario (job diario, votos, reclamaciones).
- Reportar precio/foto incorrectos + estrella ⭐ en la UI.

---

## Decisiones tomadas (importante)

- **Modelo de validación HÍBRIDO** — cambia la regla innegociable 5. El humano ya
  no confirma *todas* las líneas, solo las dudosas. Umbrales de similitud `pg_trgm`:
  - `>= 0.8` → **auto** (auto-aceptada, verde).
  - `0.4 – 0.8` → **revisar** (candidato propuesto, ámbar).
  - `< 0.4` o sin match → **sin_match** (elegir o crear producto, rojo).
- **OCR solo en móvil**: se construye la UI y se prueba en Chrome con líneas a mano;
  el OCR es el último enchufe, en dispositivo.
- **Precios por sucursal** (regla 6), nunca propagados entre tiendas.
- **`confirmar`**: upsert en `precios` (sobrescribe y el anterior queda en histórico),
  confianza del usuario **congelada** en el momento, todo en una transacción.
- **`ticket_items.producto_id`** con `ON DELETE SET NULL` (no perder histórico).
- **Votos de fotos**: no puedes votar tu propia foto; `verificada` con 3👍 y 0👎;
  `rechazada` con 3👎; contadores recalculados desde la tabla de votos.
- **`POST /productos`** en conflicto devuelve el producto existente (no falla), para
  no cortar el flujo de "crear desde ticket".
- Fotos y tickets se guardan en `backend/uploads/` (ignorado por Git), servidos en
  `/uploads`. Paso intermedio antes de Firebase.

---

## Para el futuro (ideas apuntadas)

- **Apartado de cuenta / perfil** de usuario (ahí vivirá la confiabilidad, stats…).
- **Cámara real** en móvil (el picker ya está; en Chrome solo va galería).
- **Pipeline de normalización** completo: `alias_marca` + regex de tamaño/
  presentación, para emparejar texto de OCR real ("C.COLA 2L BOT" → Coca-Cola).
- **Fase C** entera (reclamaciones + confiabilidad).

Deuda técnica previa (de las instrucciones): interceptor de refresh token en Flutter;
rehacer `idx_productos_busqueda` sobre `unaccent(lower(...))`.

---

## Notas de entorno

- Migraciones: en `backend/`, `npm run migrate`. Falta el archivo `007` (la
  numeración salta de `006` a `008`); no bloquea nada.
- Pruebas por curl en PowerShell: el `-d` con **espacios** en el JSON rompe el
  comando. Solución: escribir el JSON a un archivo y usar `-d "@archivo.json"`.
- Backend: `npm start` (puerto 3000). Flutter: `flutter run -d chrome` desde `mobile/`.
