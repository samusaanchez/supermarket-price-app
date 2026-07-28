# Estado del proyecto — App de comparación de precios

_Última actualización: 28 julio 2026_

Documento de retomada rápida. Resume qué está hecho, las decisiones tomadas y qué
queda pendiente. Complementa a las instrucciones del proyecto (no las sustituye).

---

## Resumen en una línea

Fase A (backend de tickets/OCR/reputación) **cerrada y probada**. Fase B (Flutter)
**muy avanzada**: subida de tickets, revisión híbrida, perfil, fotos de producto y
alta de supermercados hechos. Falta enchufar el OCR real (ML Kit, solo en móvil).

---

## Estado por fases

### Fase A — Backend — HECHO y probado

- Migración `012_tickets_ocr.sql`: `tickets`, `ticket_items`, `fotos`,
  `votos_fotos`, `reclamaciones`.
- Tickets: `POST /tickets` (subir foto), `GET /tickets` (mis tickets),
  `GET /tickets/:id` (con nombre de producto), `POST /tickets/emparejar`
  (clasifica líneas: auto / revisar / sin_match), `POST /tickets/:id/confirmar`
  (vuelca precios en transacción).
- Fotos de catálogo: `POST /fotos`, `GET /fotos?producto_id=`,
  `POST /fotos/:id/votos`, `DELETE /fotos/:id` (solo el dueño; borra archivo).
- Productos: `POST /productos` (alta; si ya existe devuelve el existente con
  `ya_existia:true`). `GET /productos/buscar` ahora acepta `supermercado_id`
  opcional (busca dentro de una tienda, con precio) y devuelve `foto_url`.
  `GET /productos` (catálogo) devuelve `foto_url` (mejor foto de comunidad).
- Supermercados: `POST /supermercados` (alta, entra activo — nivel 1).
- Auth: `GET /auth/me` devuelve confiabilidad y contadores.

### Fase B — Flutter — MUY AVANZADA

Hecho y probado en Chrome:

- **Subir ticket** (`upload_ticket_screen`): galería, cámara y arrastrar-soltar.
- **Mis tickets** (`mis_tickets_screen`) + **detalle** (`ticket_detail_screen`)
  con foto y productos; botón "Revisar y confirmar" en tickets pendientes.
- **Revisión híbrida** (`revision_screen`): añadir líneas (harán de OCR), Analizar
  (colores verde/ámbar/rojo), confirmar automáticas, cambiar producto (búsqueda),
  crear producto, descartar; las líneas OK se pliegan y solo se muestra lo que
  necesita atención. Confirmar → escribe precios.
- **Perfil** (`profile_screen`): avatar, confianza con estrellas, contadores,
  filas "próximamente" (contraseña, 2FA, apps conectadas, notificaciones), logout.
- **Fotos de producto** en la ficha: subir, votar 👍/👎, borrar las propias; la
  mejor foto se usa como icono del producto y sale en búsqueda y catálogo.
- **Buscador dentro del catálogo** de cada supermercado (con precio de la tienda).
- **Alta de supermercados** (`add_supermarket_screen`): formulario + mapa para
  marcar la ubicación tocando.
- ApiClient: elige host solo (Chrome → localhost; emulador Android → 10.0.2.2).

Pendiente en Fase B:

- **OCR con ML Kit**: NO corre en web. Se integra al probar en móvil/emulador;
  rellenará las líneas que hoy se meten a mano en la revisión.

### Entorno Android (a medias)

- Android Studio instalado, SDK descargado, **emulador Pixel creado**.
- La primera compilación (`flutter run` en el emulador) quedó a mitad. Para
  retomar: arrancar el emulador, `flutter run`, dejar terminar el build. La app ya
  apunta a `10.0.2.2` para hablar con el backend desde el emulador.

### Fase C — Reputación — PENDIENTE

- Endpoints de reclamaciones (la tabla ya existe).
- Puntos de confiabilidad al usuario (job diario, votos, reclamaciones).
- Reportar precio/foto incorrectos.

---

## Decisiones tomadas (importante)

- **Validación HÍBRIDA de tickets** — cambia la regla innegociable 5. El humano ya
  no confirma *todas* las líneas, solo las dudosas. Umbrales `pg_trgm`:
  `>=0.8` auto (verde), `0.4–0.8` revisar (ámbar), `<0.4` sin_match (rojo).
- **Tres tipos de "estrellas/votos" DISTINTOS** (no mezclar):
  1. **Confianza del usuario** (reputación): cuánto te fías de quien sube un dato.
  2. **Votos de fotos** (👍/👎): si una foto es buena/correcta.
  3. **Valoración del producto** (PENDIENTE, futura): cuánto *gusta* el producto,
     media de estrellas de la gente. Es opinión/gusto, sistema nuevo por construir.
- **OCR = ML Kit en el móvil** (gratis, privado). En Chrome se prueba con líneas a
  mano; el OCR es el último enchufe, en dispositivo. Alternativas valoradas y
  descartadas por ahora: OCR en backend (Tesseract) y modelos de visión en la nube
  (coste + privacidad).
- **Principio de diseño: tratar al usuario como "vago".** Minimizar campos, pedir lo
  mínimo, pre-rellenar todo lo posible. El diálogo de crear producto se pre-rellenará
  con el pipeline de normalización cuando llegue.
- **Alta de supermercados en dos niveles**: nivel 1 (hecho) = alta directa activa.
  Nivel 2 (pendiente) = enviados por usuarios → estado pendiente, detección de
  duplicados por coordenadas (~50 m), autocompletado con Nominatim, aprobación.
- **Precios**: upsert por (producto, sucursal), confianza congelada, en transacción.
- **`DELETE /fotos`**: solo el dueño; borra también el archivo físico.

---

## Para el futuro (ideas apuntadas)

- **Perfil como red social**: seguir gente, ver opiniones/valoraciones de productos,
  quizá vídeos. El perfil actual es la base sobre la que crecerá.
- **Valoración de productos** (las estrellas de "me gusta", ver arriba).
- **Cuenta**: cambiar contraseña, 2FA, apps conectadas, foto de perfil (hoy son
  filas "próximamente").
- **Cámara real** en móvil.
- **Pipeline de normalización** completo: `alias_marca` + regex de tamaño/
  presentación, para emparejar texto de OCR real.
- **Nivel 2 de supermercados** (moderación + duplicados + Nominatim).

Deuda técnica previa: interceptor de refresh token en Flutter; rehacer
`idx_productos_busqueda` sobre `unaccent(lower(...))`.

---

## Notas de entorno

- Migraciones: `npm run migrate` en `backend/`. Falta el archivo `007` (numeración
  salta de `006` a `008`); no bloquea nada.
- Pruebas por curl en PowerShell: el `-d` con **espacios** en el JSON rompe el
  comando. Solución: escribir el JSON a un archivo y usar `-d "@archivo.json"`.
- Backend: `npm start` (puerto 3000). Flutter web: `flutter run -d chrome`.
  Emulador: `flutter run` con el emulador abierto.
