# 🔧 Arreglar Deployment - Error "exec format error"

## El Problema

El error persiste porque la imagen anterior (incorrecta) sigue en el VPS. Necesitas eliminarla completamente y cargar la nueva.

## ✅ Solución Paso a Paso

### 1. En el VPS - Limpiar TODO

**Ejecuta estos comandos en el VPS:**

```bash
cd /opt/pai-app

# Detener y eliminar contenedores
docker compose down

# Eliminar TODAS las imágenes de pai-app
docker images | grep pai-app
docker rmi pai-app:latest pai-app:amd64 2>/dev/null || true

# Limpiar imágenes huérfanas
docker image prune -f

# Verificar que no queden imágenes
docker images | grep pai-app
# No debería mostrar nada
```

### 2. Desde tu Mac - Transferir la nueva imagen

**Ejecuta en tu terminal local:**

```bash
cd /Users/juanpablocuartas/Documents/Proyectos\ Flutter/pai_app
scp pai-app-amd64-fixed.tar.gz root@82.208.21.130:/opt/pai-app/
```

### 3. En el VPS - Cargar y desplegar

**Vuelve al VPS y ejecuta:**

```bash
cd /opt/pai-app

# Verificar que el archivo esté ahí
ls -lh pai-app-amd64-fixed.tar.gz

# Cargar la imagen
docker load < pai-app-amd64-fixed.tar.gz

# Verificar la arquitectura de la imagen cargada
docker inspect pai-app:latest | grep Architecture
# Debe mostrar: "Architecture": "amd64"

# Desplegar
docker compose up -d

# Verificar que está corriendo
docker compose ps

# Ver logs
docker compose logs -f
```

### 4. Si sigue fallando - Verificar arquitectura del VPS

**En el VPS:**

```bash
# Verificar arquitectura del sistema
uname -m
# Debe mostrar: x86_64

# Verificar arquitectura que Docker puede ejecutar
docker info | grep Architecture
```

### 5. Verificar en el navegador

Abre: **http://82.208.21.130**

## 🔍 Debugging

Si aún hay problemas, ejecuta en el VPS:

```bash
# Ver logs detallados
docker compose logs --tail=50

# Ver información del contenedor
docker inspect pai-app

# Verificar que nginx esté corriendo dentro del contenedor
docker exec pai-app ps aux
```

