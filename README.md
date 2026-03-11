# Midnight Hammer

Comandos para levantar el servidor Node autoritativo y el cliente Flutter web.

## Requisitos

- Node.js 20+ (con npm)
- Flutter SDK (con soporte web habilitado)
- Chrome/Edge para ejecutar el cliente web

## 1) Instalar dependencias

Servidor:

```powershell
cd server_nodejs
npm install --cache .npm-cache --no-audit --no-fund
```

Cliente:

```powershell
cd client_flutter
flutter pub get
```

## 2) Levantar en desarrollo (dos terminales)

Terminal A - servidor:

```powershell
cd server_nodejs
npm start
```

Terminal B - cliente Flutter web:

```powershell
cd client_flutter
flutter run -d chrome
```

## 3) Verificaciones rápidas

Tests del servidor:

```powershell
cd server_nodejs
npm test
```

Tests del cliente:

```powershell
cd client_flutter
flutter test
```

## 4) Build web de producción

```powershell
cd client_flutter
flutter build web --release
```

Salida: `client_flutter/build/web`
