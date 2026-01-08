# 🚀 Desplegar Cambios de super_admin a Producción

## Estado actual:

✅ **SQL ejecutado**: Las políticas RLS ya están actualizadas en Supabase (producción)
⚠️ **Código Flutter**: Los cambios en `splash_page.dart` y `login_page.dart` están solo en local

## Para probar en producción:

### Opción 1: Probar con las políticas SQL (recomendado primero)

1. Abre: **http://82.208.21.130**
2. Inicia sesión con: `jpcuartasv@hotmail.com`
3. **Actualmente**: Deberías ver los vehículos y tener acceso (las políticas SQL ya funcionan)
4. **Redirección**: Podría redirigir al dashboard correcto (dependiendo del código actual en producción)

### Opción 2: Desplegar código actualizado a producción

Para que la redirección de `super_admin` funcione correctamente, necesitas desplegar el código actualizado:

#### Paso 1: Construir nueva imagen Docker

```bash
cd /Users/juanpablocuartas/Documents/Proyectos\ Flutter/pai_app

# Construir para linux/amd64
docker build --platform linux/amd64 -t pai-app:latest .
```

#### Paso 2: Transferir y desplegar en VPS

**Opción A: Construir directamente en el VPS (Recomendado)**

```bash
# 1. Crear tarball del código
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
    --exclude='*.tar.gz' \
    --exclude='*.sql' \
    --exclude='*.md' \
    -czf pai-app-source.tar.gz \
    Dockerfile docker-compose.yml nginx.conf pubspec.yaml pubspec.lock lib/ assets/ web/ .dockerignore

# 2. Transferir al VPS
scp pai-app-source.tar.gz root@82.208.21.130:/opt/pai-app/

# 3. En el VPS (Termius):
cd /opt/pai-app
tar -xzf pai-app-source.tar.gz
docker compose down
docker build -t pai-app:latest .
docker compose up -d
docker compose logs -f
```

**Opción B: Usar el script de deployment (si funciona)**

```bash
./deploy.sh 82.208.21.130 root
```

## Recomendación:

1. **Primero prueba** con las políticas SQL (ya deberías poder ver vehículos)
2. Si todo funciona excepto la redirección, entonces despliega el código
3. Si todo funciona bien, puedes dejarlo así o desplegar para asegurar la redirección correcta

## Verificación después del deployment:

1. Abre: **http://82.208.21.130**
2. Inicia sesión con: `jpcuartasv@hotmail.com`
3. Deberías:
   - ✅ Ver el OwnerDashboardPage automáticamente
   - ✅ Ver vehículos y tener acceso completo
   - ✅ Todas las funcionalidades disponibles

