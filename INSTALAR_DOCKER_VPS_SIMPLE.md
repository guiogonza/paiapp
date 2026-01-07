# 🐳 Instalar Docker en el VPS - Comandos Rápidos

Ejecuta estos comandos **en el VPS** (uno por uno):

## Instalación Rápida de Docker

```bash
# 1. Actualizar sistema
apt-get update

# 2. Instalar dependencias
apt-get install -y ca-certificates curl gnupg lsb-release

# 3. Agregar clave GPG de Docker
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 4. Agregar repositorio de Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. Instalar Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 6. Iniciar Docker
systemctl start docker
systemctl enable docker

# 7. Verificar instalación
docker --version
docker compose version
```

## Después de instalar Docker

Una vez instalado, continúa con el deployment:

```bash
# Ir al directorio
cd /opt/pai-app

# Cargar la imagen
docker load < pai-app-latest.tar.gz

# Desplegar (nota: usa 'docker compose' en lugar de 'docker-compose')
docker compose up -d

# Verificar
docker compose ps
docker compose logs -f
```

## ⚠️ Nota Importante

Docker Compose ahora se usa como plugin: `docker compose` (con espacio) en lugar de `docker-compose` (con guión).

Si el archivo `docker-compose.yml` usa la versión antigua, actualízalo o usa:
```bash
docker compose -f docker-compose.yml up -d
```

