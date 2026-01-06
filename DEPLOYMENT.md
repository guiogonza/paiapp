# 🚀 Guía de Deployment en VPS

Esta guía te ayudará a desplegar PAI App en tu VPS usando Docker.

## 📋 Requisitos Previos

1. **VPS con:**
   - Docker instalado
   - Docker Compose instalado
   - Acceso SSH configurado
   - Puerto 80 (y opcionalmente 443) abierto

2. **Local:**
   - Docker instalado
   - Acceso SSH al VPS configurado
   - Git (para clonar el repositorio)

## 🔧 Instalación en el VPS

### 1. Instalar Docker y Docker Compose (si no están instalados)

```bash
# Conectarse al VPS
ssh root@TU_IP_VPS

# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Instalar Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Verificar instalación
docker --version
docker-compose --version
```

### 2. Preparar el directorio en el VPS

```bash
mkdir -p /opt/pai-app
cd /opt/pai-app
```

## 🚀 Métodos de Deployment

### Método 1: Usando el Script de Deployment (Recomendado)

```bash
# Desde tu máquina local
chmod +x deploy.sh
./deploy.sh TU_IP_VPS
```

El script:
1. Construye la imagen Docker localmente
2. La comprime y envía al VPS
3. La carga y ejecuta en el VPS
4. Limpia archivos temporales

### Método 2: Deployment Manual

#### Paso 1: Construir y etiquetar la imagen

```bash
# Desde tu máquina local
docker build -t pai-app:latest .
docker save pai-app:latest | gzip > pai-app-latest.tar.gz
```

#### Paso 2: Transferir al VPS

```bash
scp pai-app-latest.tar.gz docker-compose.yml root@TU_IP_VPS:/opt/pai-app/
```

#### Paso 3: Desplegar en el VPS

```bash
# Conectarse al VPS
ssh root@TU_IP_VPS

cd /opt/pai-app

# Cargar la imagen
docker load < pai-app-latest.tar.gz

# Ejecutar con docker-compose
docker-compose up -d

# Verificar que está corriendo
docker-compose ps
docker-compose logs -f
```

### Método 3: Clonar y Build Directo en el VPS

```bash
# En el VPS
cd /opt
git clone https://github.com/jpcuartasv-bit/pai_app.git pai-app
cd pai-app
docker-compose up -d --build
```

## 🔍 Verificación

1. **Verificar que el contenedor está corriendo:**
   ```bash
   docker ps
   # o
   docker-compose ps
   ```

2. **Ver logs:**
   ```bash
   docker-compose logs -f
   ```

3. **Acceder a la aplicación:**
   - Abre tu navegador en: `http://TU_IP_VPS`
   - Deberías ver la aplicación funcionando

## 🔄 Actualizaciones

Para actualizar la aplicación:

```bash
# Opción 1: Usar el script
./deploy.sh TU_IP_VPS

# Opción 2: Manual
# 1. Hacer pull de los cambios
git pull

# 2. Reconstruir y desplegar
docker-compose up -d --build
```

## 🛠️ Comandos Útiles

```bash
# Ver logs en tiempo real
docker-compose logs -f

# Detener la aplicación
docker-compose down

# Reiniciar la aplicación
docker-compose restart

# Ver estado
docker-compose ps

# Entrar al contenedor
docker exec -it pai-app sh

# Limpiar imágenes no usadas
docker system prune -a
```

## 🔒 Configurar HTTPS (Opcional)

Para configurar HTTPS con Let's Encrypt:

1. **Instalar Certbot:**
   ```bash
   apt-get update
   apt-get install certbot python3-certbot-nginx
   ```

2. **Obtener certificado:**
   ```bash
   certbot certonly --standalone -d tu-dominio.com
   ```

3. **Configurar nginx con SSL** (editar `nginx.conf`)

## 📊 Monitoreo

### Ver uso de recursos:
```bash
docker stats pai-app
```

### Ver logs de nginx:
```bash
docker exec pai-app tail -f /var/log/nginx/access.log
docker exec pai-app tail -f /var/log/nginx/error.log
```

## 🐛 Troubleshooting

### El contenedor no inicia:
```bash
docker-compose logs
docker-compose ps
```

### Puerto 80 ya está en uso:
```bash
# Ver qué está usando el puerto 80
netstat -tulpn | grep :80

# Cambiar el puerto en docker-compose.yml
ports:
  - "8080:80"  # Cambiar 80 por 8080
```

### Problemas de permisos:
```bash
chmod +x deploy.sh
```

## 📝 Variables de Entorno

Si necesitas configurar variables de entorno, crea un archivo `.env`:

```bash
# En el VPS
cd /opt/pai-app
nano .env
```

Y actualiza `docker-compose.yml` para usar el archivo `.env`.

## 🔐 Seguridad

1. **Firewall:**
   ```bash
   ufw allow 80/tcp
   ufw allow 443/tcp
   ufw enable
   ```

2. **Actualizar regularmente:**
   ```bash
   apt-get update && apt-get upgrade -y
   ```

3. **Backups:**
   - Configura backups regulares de la base de datos Supabase
   - Considera hacer backup de la configuración del VPS

## 📞 Soporte

Si encuentras problemas:
1. Revisa los logs: `docker-compose logs -f`
2. Verifica que Docker esté corriendo: `docker ps`
3. Verifica la conectividad: `curl http://localhost`

