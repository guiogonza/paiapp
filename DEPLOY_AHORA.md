# 🚀 Deployment Rápido - Pasos a Seguir

La imagen Docker ya está construida y lista. Sigue estos pasos:

## Paso 1: Transferir archivos al VPS

**Desde tu terminal local**, ejecuta:

```bash
cd /Users/juanpablocuartas/Documents/Proyectos\ Flutter/pai_app

# Transferir la imagen y docker-compose
scp pai-app-latest.tar.gz docker-compose.yml root@82.208.21.130:/opt/pai-app/
```

Te pedirá la contraseña del VPS. Ingrésala cuando te la pida.

## Paso 2: Conectarse al VPS y desplegar

**En otra terminal** (o después del paso 1), conéctate al VPS:

```bash
ssh root@82.208.21.130
```

Una vez conectado, ejecuta:

```bash
# Crear directorio si no existe
mkdir -p /opt/pai-app
cd /opt/pai-app

# Verificar que los archivos estén ahí
ls -la

# Cargar la imagen Docker
docker load < pai-app-latest.tar.gz

# Verificar que Docker y Docker Compose estén instalados
docker --version
docker-compose --version

# Si no están instalados, instálalos:
# curl -fsSL https://get.docker.com -o get-docker.sh
# sh get-docker.sh
# curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
# chmod +x /usr/local/bin/docker-compose

# Desplegar la aplicación
docker-compose up -d

# Verificar que esté corriendo
docker-compose ps

# Ver logs
docker-compose logs -f
```

## Paso 3: Verificar

Abre tu navegador en: **http://82.208.21.130**

Deberías ver la aplicación funcionando.

## ✅ Comandos útiles después del deployment

```bash
# Ver logs en tiempo real
docker-compose logs -f

# Reiniciar
docker-compose restart

# Detener
docker-compose down

# Ver estado
docker-compose ps
```

