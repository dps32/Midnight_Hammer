#!/bin/bash
# Script para deploy de la carpeta server_nodejs al servidor remoto

set -e

# Función de limpieza
cleanup() {
    ssh-agent -k 2>/dev/null || true
    cd "$ORIGINAL_DIR" 2>/dev/null || true
}
trap cleanup EXIT

ORIGINAL_DIR=$(pwd)
cd "$(dirname "$0")"  # Cambiar al directorio del script
source ./config.env

# Parámetros opcionales: usuario, ruta RSA, puerto SSH
USER=${1:-$DEFAULT_USER}
RSA_PATH=${2:-"$DEFAULT_RSA_PATH"}
SSH_PORT=${3:-$DEFAULT_SSH_PORT}
RSA_PATH="${RSA_PATH%$'\r'}"  # Elimina retornos de carro si existen

HOST="$DEFAULT_HOST"
ZIP_NAME="server-package.zip"

echo "🔧 Configuración:"
echo "   Usuario: $USER"
echo "   Host: $HOST"
echo "   Puerto SSH: $SSH_PORT"
echo "   Puerto servidor: $DEFAULT_SERVER_PORT"
echo "   Ruta RSA: $RSA_PATH"
echo ""

# Verificar que la clave existe
if [[ ! -f "$RSA_PATH" ]]; then
    echo "❌ Error: No se encontró la clave privada: $RSA_PATH"
    exit 1
fi

# Generar build si es necesario (descomenta si necesitas)
# echo "🔨 Generando build..."
# bash ../buildFlutterWeb.sh
# cd ..
# ./getAssets.sh

# Crear paquete ZIP
echo "📦 Creando paquete para despliegue..."
rm -f "$ZIP_NAME"
zip -r "$ZIP_NAME" . -x "proxmox/*" "node_modules/*" "data" "data/*" ".gitignore" ".DS_Store"

# Transferir y desplegar
echo "🚀 Iniciando despliegue al servidor..."

eval "$(ssh-agent -s)" >/dev/null
ssh-add "$RSA_PATH"

scp -P "$SSH_PORT" "$ZIP_NAME" "$USER@$HOST:~/server-package.zip"
rm -f "$ZIP_NAME"

ssh -tt -p "$SSH_PORT" -o UpdateHostKeys=no \
    "$USER@$HOST" \
    bash -s -- "$DEFAULT_SERVER_PORT" << 'EOF'
set -e

SERVER_PORT="$1"
APP_DIR="$HOME/nodejs_server"
PKG="$HOME/server-package.zip"
TMP_DIR="$(mktemp -d)"

echo "📁 Desempaquetando en directorio temporal..."
export PATH="$HOME/.npm-global/bin:/usr/local/bin:$PATH"

mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Detener solo nuestra aplicación si está corriendo
echo "⏹️  Deteniendo aplicación existente..."
if command -v pm2 >/dev/null 2>&1; then
    pm2 delete app >/dev/null 2>&1 || true
fi

# Esperar a que el puerto se libere
echo "⏳ Esperando a que el puerto se libere..."
for i in {1..10}; do
    ss -tln | grep -q ":$SERVER_PORT " && sleep 1 || break
done

# Limpiar directorio de la app (manteniendo data si existe)
echo "🧹 Limpiando directorio de aplicación..."
find "$APP_DIR" -mindepth 1 -maxdepth 1 -name "data" -prune -o -exec rm -rf {} + 2>/dev/null || true

# Desempaquetar de forma segura
echo "📂 Desempaquetando archivos..."
unzip -q -o "$PKG" -d "$TMP_DIR"
rm -f "$PKG"

# Detectar raíz del proyecto
if [[ -f "$TMP_DIR/package.json" ]]; then
    echo "🎯 Encontrado package.json en raíz"
    rsync -a --delete --exclude 'data/' "$TMP_DIR/" "$APP_DIR/"
elif [[ -f "$TMP_DIR/nodejs_server/package.json" ]]; then
    echo "🎯 Encontrado package.json en nodejs_server/"
    rsync -a --delete --exclude 'data/' "$TMP_DIR/nodejs_server/" "$APP_DIR/"
elif [[ -f "$TMP_DIR/nodejs_web/package.json" ]]; then
    echo "🎯 Encontrado package.json en nodejs_web/"
    rsync -a --delete --exclude 'data/' "$TMP_DIR/nodejs_web/" "$APP_DIR/"
else
    echo "❌ Error: No se encontró package.json dentro del ZIP"
    exit 1
fi

rm -rf "$TMP_DIR"

# Instalar dependencias
echo "📥 Instalando dependencias de producción..."
cd "$APP_DIR"
npm install --omit=dev

# Iniciar aplicación con PM2 global
echo "▶️  Iniciando aplicación con PM2..."
pm2 start server/app.js --name app --update-env
pm2 save

echo "✅ Despliegue completado. Estado actual de PM2:"
pm2 status
exit
EOF

echo "🎉 ¡Despliegue exitoso!"