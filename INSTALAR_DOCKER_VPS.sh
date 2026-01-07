#!/bin/bash
# Script para instalar Docker y Docker Compose en el VPS
# Ejecutar en el VPS: bash <(curl -s https://raw.githubusercontent.com/docker/docker-install/master/install.sh)

echo "🐳 Instalando Docker..."

# Actualizar sistema
apt-get update

# Instalar dependencias
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Agregar clave GPG oficial de Docker
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Configurar repositorio
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Iniciar y habilitar Docker
systemctl start docker
systemctl enable docker

# Verificar instalación
docker --version
docker compose version

echo "✅ Docker instalado correctamente!"

