# 🚀 Deployment Manual - Instrucciones Paso a Paso

Si el script automático tiene problemas con SSH, puedes hacer el deployment manualmente:

## Paso 1: Construir la imagen Docker localmente

```bash
cd /Users/juanpablocuartas/Documents/Proyectos\ Flutter/pai_app
docker build -t pai-app:latest .
docker save pai-app:latest | gzip > pai-app-latest.tar.gz
```

## Paso 2: Conectarse al VPS y preparar el entorno

```bash
# Conectarse al VPS (acepta la clave SSH cuando te lo pida)
ssh root@82.208.21.130

# En el VPS, instalar Docker si no está instalado
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Instalar Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Crear directorio
mkdir -p /opt/pai-app
cd /opt/pai-app
```

## Paso 3: Transferir archivos al VPS

**Desde tu máquina local** (en otra terminal):

```bash
cd /Users/juanpablocuartas/Documents/Proyectos\ Flutter/pai_app
scp pai-app-latest.tar.gz docker-compose.yml root@82.208.21.130:/opt/pai-app/
```

## Paso 4: Desplegar en el VPS

**En el VPS**:

```bash
cd /opt/pai-app

# Cargar la imagen
docker load < pai-app-latest.tar.gz

# Ejecutar con docker-compose
docker-compose up -d

# Verificar que está corriendo
docker-compose ps
docker-compose logs -f
```

## Paso 5: Verificar

Abre tu navegador en: **http://82.208.21.130**

## Comandos útiles en el VPS

```bash
# Ver logs
docker-compose logs -f

# Detener
docker-compose down

# Reiniciar
docker-compose restart

# Ver estado
docker-compose ps
```

## Actualizar la aplicación

Cuando necesites actualizar:

1. **En local:** Reconstruir y guardar la imagen
2. **Transferir** el nuevo tar.gz al VPS
3. **En VPS:** `docker load < pai-app-latest.tar.gz && docker-compose up -d --force-recreate`

