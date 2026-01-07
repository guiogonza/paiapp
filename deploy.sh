#!/bin/bash

# Script de deployment para VPS
# Uso: ./deploy.sh [IP_DEL_VPS]

set -e

VPS_IP="${1:-}"
VPS_USER="${2:-root}"  # Segundo parámetro es el usuario
APP_NAME="pai-app"
REMOTE_DIR="/opt/pai-app"

if [ -z "$VPS_IP" ]; then
    echo "❌ Error: Debes proporcionar la IP del VPS"
    echo "Uso: ./deploy.sh <IP_DEL_VPS> [USUARIO]"
    echo "Ejemplo: ./deploy.sh 192.168.1.100 root"
    echo "Ejemplo: ./deploy.sh 192.168.1.100 ubuntu"
    exit 1
fi

echo "📋 Configuración:"
echo "   VPS IP: $VPS_IP"
echo "   Usuario: $VPS_USER"
echo ""

echo "🚀 Iniciando deployment de PAI App a $VPS_IP..."

# 1. Construir la imagen Docker localmente
echo "📦 Construyendo imagen Docker..."
docker build -t $APP_NAME:latest .

# 2. Guardar la imagen como tar
echo "💾 Guardando imagen..."
docker save $APP_NAME:latest | gzip > $APP_NAME-latest.tar.gz

# 3. Agregar VPS a known_hosts si no está
echo "🔐 Configurando SSH..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keyscan -H $VPS_IP >> ~/.ssh/known_hosts 2>/dev/null || true
chmod 600 ~/.ssh/known_hosts 2>/dev/null || true

# 4. Crear directorio remoto si no existe
echo "📁 Creando directorio en VPS..."
ssh $VPS_USER@$VPS_IP "mkdir -p $REMOTE_DIR"

# 5. Copiar archivos al VPS
echo "📤 Copiando archivos al VPS..."
scp $APP_NAME-latest.tar.gz docker-compose.yml $VPS_USER@$VPS_IP:$REMOTE_DIR/

# 6. Cargar imagen en el VPS y ejecutar
echo "🔄 Desplegando en VPS..."
ssh $VPS_USER@$VPS_IP << EOF
    cd $REMOTE_DIR
    docker load < $APP_NAME-latest.tar.gz
    docker-compose down || true
    docker-compose up -d
    docker system prune -f
    rm -f $APP_NAME-latest.tar.gz
EOF

# 7. Limpiar archivos locales
echo "🧹 Limpiando archivos locales..."
rm -f $APP_NAME-latest.tar.gz

echo "✅ Deployment completado!"
echo "🌐 La aplicación está disponible en: http://$VPS_IP"
echo ""
echo "Para ver los logs: ssh $VPS_USER@$VPS_IP 'cd $REMOTE_DIR && docker-compose logs -f'"
echo "Para detener: ssh $VPS_USER@$VPS_IP 'cd $REMOTE_DIR && docker-compose down'"
echo "Para reiniciar: ssh $VPS_USER@$VPS_IP 'cd $REMOTE_DIR && docker-compose restart'"

