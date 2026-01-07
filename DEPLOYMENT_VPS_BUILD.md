# 🔧 Solución: Construir directamente en el VPS

Si el error persiste, es mejor construir la imagen directamente en el VPS para asegurar la arquitectura correcta.

## Opción 1: Construir en el VPS (Recomendado)

### 1. Transferir el código fuente al VPS

**Desde tu Mac:**

```bash
cd /Users/juanpablocuartas/Documents/Proyectos\ Flutter/pai_app

# Crear un tarball del proyecto (sin build, node_modules, etc.)
tar --exclude='build' \
    --exclude='.dart_tool' \
    --exclude='.flutter-plugins' \
    --exclude='.flutter-plugins-dependencies' \
    --exclude='android' \
    --exclude='ios' \
    --exclude='macos' \
    --exclude='windows' \
    --exclude='linux' \
    --exclude='.git' \
    -czf pai-app-source.tar.gz \
    Dockerfile docker-compose.yml nginx.conf pubspec.yaml pubspec.lock lib/ assets/ web/ .dockerignore

# Transferir al VPS
scp pai-app-source.tar.gz root@82.208.21.130:/opt/pai-app/
```

### 2. En el VPS - Construir la imagen

**En el VPS:**

```bash
cd /opt/pai-app

# Detener todo
docker compose down
docker rmi pai-app:latest 2>/dev/null || true

# Extraer el código
tar -xzf pai-app-source.tar.gz

# Construir la imagen directamente en el VPS
docker build -t pai-app:latest .

# Verificar
docker images | grep pai-app

# Desplegar
docker compose up -d

# Ver logs
docker compose logs -f
```

## Opción 2: Usar imagen base diferente

Si sigue fallando, puede ser un problema con nginx:alpine. Prueba cambiar el Dockerfile a usar nginx:latest (no alpine).

## Verificación de Arquitectura

**En el VPS, ejecuta:**

```bash
uname -m
# Debe mostrar: x86_64

docker info | grep Architecture
# Debe mostrar: Architecture: x86_64

# Verificar qué arquitectura tiene la imagen
docker inspect pai-app:latest | grep -i arch
```

