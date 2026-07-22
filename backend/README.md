# Supermarket Price App

App móvil de comparación de precios de supermercados alimentada por crowdsourcing.
Los usuarios suben fotos de sus tickets, el sistema extrae productos y precios
mediante OCR, y construye un catálogo de precios actualizado a diario con
comparativas entre supermercados.

Proyecto de aprendizaje personal. En desarrollo.

## Estado

- ✅ Setup del entorno (Flutter, Node, PostgreSQL)
- ✅ Sistema de migraciones automáticas
- ✅ Autenticación (registro, login, JWT, middleware)
- ✅ Pantallas de login y registro en Flutter con persistencia de sesión
- 🚧 Mapas y supermercados (siguiente)
- ⏳ Catálogo de productos
- ⏳ Subida de tickets + OCR
- ⏳ Sistema de reputación
- ⏳ Listas de compra con comparativas

## Stack

- **App:** Flutter + Dart
- **Backend:** Node.js + Express
- **Base de datos:** PostgreSQL
- **Autenticación:** JWT (access + refresh tokens)
- **Almacenamiento seguro en móvil:** flutter_secure_storage

## Estructura
SupermarketApp/
├── mobile/ # App Flutter (iOS + Android + web)
├── backend/ # API REST en Node.js
└── docs/ # Documentación
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