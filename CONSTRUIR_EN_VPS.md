# 🔧 Construir Imagen Docker Directamente en el VPS

Esta es la solución más segura para evitar problemas de arquitectura.

## 📤 Paso 1: Transferir Código Fuente al VPS

**Desde tu Mac (Terminal local):**

```bash
cd /Users/juanpablocuartas/Documents/Proyectos\ Flutter/pai_app
scp pai-app-source.tar.gz root@82.208.21.130:/opt/pai-app/
```

## 🔨 Paso 2: Construir en el VPS

**En Termius (conectado al VPS):**

```bash
# Ir al directorio
cd /opt/pai-app

# Detener todo lo que esté corriendo
docker compose down 2>/dev/null || true
docker rmi pai-app:latest 2>/dev/null || true

# Extraer el código fuente
tar -xzf pai-app-source.tar.gz

# Verificar que Dockerfile esté ahí
ls -la Dockerfile

# Construir la imagen DIRECTAMENTE en el VPS
# Esto asegura que sea para la arquitectura correcta
docker build -t pai-app:latest .

# Verificar que se construyó
docker images | grep pai-app

# Verificar la arquitectura
docker inspect pai-app:latest | grep Architecture
# Debe mostrar: "Architecture": "amd64" o "x86_64"

# Desplegar
docker compose up -d

# Ver logs
docker compose logs -f
```

## ✅ Verificación

1. **Verificar contenedor:**
   ```bash
   docker compose ps
   # Debe mostrar "Up" en lugar de "Restarting"
   ```

2. **Ver logs:**
   ```bash
   docker compose logs --tail=50
   # No debe mostrar "exec format error"
   ```

3. **Abrir en navegador:**
   - **http://82.208.21.130**

## 🔍 Si Sigue Fallando

**Verificar arquitectura del VPS:**

```bash
# Ver arquitectura del sistema
uname -m
# Debe ser: x86_64

# Ver qué arquitecturas soporta Docker
docker info | grep -i arch

# Ver arquitectura de la imagen construida
docker inspect pai-app:latest | grep -A 5 Architecture
```

**Si el VPS es ARM (aarch64):**

Necesitarías construir para ARM:
```bash
docker build --platform linux/arm64 -t pai-app:latest .
```

