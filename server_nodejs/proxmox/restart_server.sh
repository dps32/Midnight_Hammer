#!/bin/bash
# Script para reiniciar el servidor Node.js en el servidor remoto

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

echo "🔧 Configuración:"
echo "   Usuario: $USER"
echo "   Host: $HOST"
echo "   Puerto SSH: $SSH_PORT"
echo "   Ruta RSA: $RSA_PATH"
echo ""

# Verificar que la clave existe
if [[ ! -f "$RSA_PATH" ]]; then
    echo "❌ Error: No se encontró la clave privada: $RSA_PATH"
    exit 1
fi

# Reiniciar servicio
echo "🔄 Reiniciando servicio Node.js..."

eval "$(ssh-agent -s)" >/dev/null
ssh-add "$RSA_PATH"

ssh -t -p "$SSH_PORT" -o UpdateHostKeys=no \
    "$USER@$HOST" << 'EOF'
echo "⏹️  Deteniendo aplicación..."
if command -v pm2 >/dev/null 2>&1; then
    pm2 stop app || true
    pm2 delete app || true
fi

echo "▶️  Iniciando aplicación..."
# Asumimos que la aplicación ya está desplegada en ~/nodejs_server
cd ~/nodejs_server
pm2 start server/app.js --name app --update-env
pm2 save

echo "✅ Servicio reiniciado. Estado actual de PM2:"
pm2 status
exit
EOF

echo "🎉 ¡Reinicio completado!"