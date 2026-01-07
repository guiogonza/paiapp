# 🔧 Solución: Error "exec format error"

El error se debía a que la imagen estaba construida para ARM (Mac) y el VPS es x86_64 (amd64).

## ✅ Imagen corregida

He construido una nueva imagen para la arquitectura correcta: `pai-app-latest-amd64.tar.gz`

## 📤 Pasos para desplegar

### 1. Detener el contenedor actual en el VPS

**En el VPS:**
```bash
cd /opt/pai-app
docker compose down
docker rmi pai-app:latest  # Eliminar la imagen incorrecta
```

### 2. Transferir la nueva imagen desde tu Mac

**Desde tu máquina local:**
```bash
cd /Users/juanpablocuartas/Documents/Proyectos\ Flutter/pai_app
scp pai-app-latest-amd64.tar.gz root@82.208.21.130:/opt/pai-app/
```

### 3. Cargar y desplegar en el VPS

**En el VPS:**
```bash
cd /opt/pai-app

# Cargar la nueva imagen
docker load < pai-app-latest-amd64.tar.gz

# Desplegar
docker compose up -d

# Verificar
docker compose ps
docker compose logs -f
```

### 4. Verificar

Abre: **http://82.208.21.130**

## 🔍 Verificar arquitectura

Para verificar que la imagen es correcta:
```bash
docker inspect pai-app:latest | grep Architecture
# Debe mostrar: "Architecture": "amd64"
```

