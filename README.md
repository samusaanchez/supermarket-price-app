# Supermarket Price App

App móvil de comparación de precios de supermercados alimentada por crowdsourcing.
Los usuarios suben fotos de sus tickets, el sistema extrae productos y precios
mediante OCR, y construye un catálogo actualizado a diario con comparativas entre
supermercados.

Proyecto de aprendizaje personal. En desarrollo activo.

## Estado

- ✅ Setup del entorno (Flutter, Node, PostgreSQL, Git)
- ✅ Sistema de migraciones automáticas
- ✅ Autenticación (registro, login, refresh, JWT, middleware)
- ✅ Mapas con OpenStreetMap y marcadores por cadena de supermercado
- ✅ Geolocalización del usuario y botón "centrar en mí"
- ✅ Catálogo de productos con tabs por categoría, paginación y precio por unidad
- ✅ Buscador con `pg_trgm` (tolera acentos, mayúsculas y palabras pegadas)
- ✅ Listas de la compra con edición de cantidades
- ✅ Comparativa de precios por supermercado con desglose por producto
- 🚧 Subida de tickets con OCR (siguiente)
- ⏳ Sistema de reputación (voto de fotos, reclamaciones, confianza)
- ⏳ Testing y deploy a staging

## Funcionalidades actuales

- Registro e inicio de sesión con persistencia (los tokens sobreviven al cierre).
- Mapa interactivo con supermercados cercanos, cada uno con su color por cadena.
- Detalle de supermercado con lista de productos por categoría.
- Detalle de producto con precios en todos los supermercados, ordenados por precio,
  y con el "€ por unidad de referencia" (€/L, €/kg, €/ud) calculado al vuelo.
- Búsqueda global de productos por nombre o marca.
- Crear listas de compra, añadir productos desde el catálogo o el buscador,
  cambiar cantidades con actualización instantánea, quitar productos.
- Comparativa de precios: dada una lista, muestra el total en cada supermercado
  ordenado por disponibilidad y precio, con desglose por producto y aviso de
  los productos que no están disponibles en cada tienda.

## Stack

- **App:** Flutter + Dart (probada en Chrome; portable a iOS y Android)
- **Backend:** Node.js + Express + JWT
- **Base de datos:** PostgreSQL 14+ con extensiones `pg_trgm` y `unaccent`
- **Mapas:** OpenStreetMap con `flutter_map`
- **Almacenamiento seguro en móvil:** `flutter_secure_storage`

## Estructura
SupermarketApp/
├── mobile/ # App Flutter
├── backend/ # API REST en Node.js
└── docs/ # Documentación


## Modelo de datos

- `usuarios` — cuentas y puntuación de confianza.
- `supermercados` — sucursales con geolocalización.
- `categorias` — clasificación de productos.
- `productos` — catálogo maestro. Un producto se identifica por
  `(marca, tamaño, presentación, variante)`. Incluye cantidad estructurada
  (`cantidad_valor`, `cantidad_unidad`) para calcular precio por unidad.
- `precios` — precio actual de un producto en un supermercado. Un producto
  tiene tantas filas como supermercados donde se vende.
- `precios_historico` — histórico append-only para gráficas de tendencia.
- `listas_compra` — listas personales del usuario.
- `lista_items` — productos dentro de cada lista con cantidad.

## Ejecutar en local

### Requisitos

- Flutter 3.44+
- Node.js 18+
- PostgreSQL 14+

### Backend

```bash
cd backend
npm install
cp .env.example .env
# Editar .env con la contraseña real de PostgreSQL
npm run migrate
npm start
```

La API queda disponible en `http://localhost:3000/api/v1`.

### App

```bash
cd mobile
flutter pub get
flutter run -d chrome
```

## Licencia

Todos los derechos reservados. Código no distribuido.
