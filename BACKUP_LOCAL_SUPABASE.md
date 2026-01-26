# 🔄 Backup Local de Supabase con Docker

Guía para crear un respaldo local de tu base de datos de Supabase usando PostgreSQL en Docker.

---

## 📋 Pasos

### 1. Exportar datos de Supabase

#### Opción A: Desde el Dashboard (Recomendado)
1. Ve a https://supabase.com/dashboard
2. Selecciona proyecto `urlbbkpuaiugputhnsqx`
3. Ve a **Database** → **Backups**
4. Click en **Download backup** (archivo .sql)

#### Opción B: Usando pg_dump
```powershell
# Necesitas las credenciales de conexión directa (Database Settings → Connection String)
pg_dump -h db.urlbbkpuaiugputhnsqx.supabase.co -U postgres -d postgres > backup_supabase.sql
```

---

### 2. Configurar PostgreSQL local con Docker

El archivo `docker-compose.local-db.yml` ya está creado con:
- PostgreSQL 15
- Volumen persistente para los datos
- Configuración de usuario y contraseña
- Puerto 5432 expuesto

---

### 3. Iniciar PostgreSQL local

```powershell
# Iniciar contenedor
docker compose -f docker-compose.local-db.yml up -d

# Verificar que está corriendo
docker compose -f docker-compose.local-db.yml ps
```

---

### 4. Restaurar backup en PostgreSQL local

```powershell
# Copiar archivo SQL al contenedor
docker cp backup_supabase.sql pai-postgres:/tmp/backup.sql

# Restaurar en la base de datos
docker exec -i pai-postgres psql -U postgres -d pai_app < backup_supabase.sql

# O si ya copiaste el archivo:
docker exec -it pai-postgres psql -U postgres -d pai_app -f /tmp/backup.sql
```

---

### 5. Verificar datos restaurados

```powershell
# Conectarse a PostgreSQL
docker exec -it pai-postgres psql -U postgres -d pai_app

# Dentro de psql, ejecutar:
# \dt              -- Ver todas las tablas
# \d+ profiles     -- Ver estructura de tabla profiles
# SELECT COUNT(*) FROM profiles;
# SELECT COUNT(*) FROM vehicles;
# \q               -- Salir
```

---

## 🔧 Comandos Útiles

### Gestión del contenedor
```powershell
# Detener
docker compose -f docker-compose.local-db.yml down

# Detener y eliminar volumen (BORRA TODOS LOS DATOS)
docker compose -f docker-compose.local-db.yml down -v

# Ver logs
docker compose -f docker-compose.local-db.yml logs -f
```

### Crear nuevo backup desde local
```powershell
# Exportar datos locales
docker exec pai-postgres pg_dump -U postgres pai_app > backup_local_$(Get-Date -Format 'yyyyMMdd_HHmmss').sql
```

### Conectarse desde la aplicación Flutter
```dart
// En caso de querer usar la BD local en desarrollo
await Supabase.initialize(
  url: 'http://localhost:54321', // Supabase local (requiere supabase CLI)
  anonKey: 'tu-anon-key-local',
);
```

---

## 📁 Estructura de archivos generada

```
pai_app/
├── docker-compose.local-db.yml    # Configuración PostgreSQL
├── postgres-data/                 # Volumen persistente (creado automáticamente)
└── backups/                       # Carpeta para guardar backups
    ├── backup_supabase.sql        # Backup descargado de Supabase
    └── backup_local_YYYYMMDD.sql  # Backups locales
```

---

## ⚠️ Notas Importantes

1. **Volumen persistente:** Los datos se guardan en `./postgres-data/` y persisten aunque detengas el contenedor

2. **Credenciales locales:**
   - Usuario: `postgres`
   - Password: `postgres123`
   - Base de datos: `pai_app`
   - Puerto: `5432`

3. **Seguridad:** Esta configuración es solo para desarrollo local. No uses estas credenciales en producción.

4. **Supabase CLI:** Para una réplica completa de Supabase localmente (con Auth, Storage, etc.), usa:
   ```powershell
   npx supabase init
   npx supabase start
   ```

---

## 🚀 Automatización de Backups

Puedes crear un script PowerShell para backups automáticos:

```powershell
# backup-auto.ps1
$fecha = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupFile = "backups/backup_local_$fecha.sql"

# Crear carpeta si no existe
New-Item -ItemType Directory -Force -Path backups

# Exportar
docker exec pai-postgres pg_dump -U postgres pai_app > $backupFile

# Mantener solo últimos 7 backups
Get-ChildItem backups/*.sql | 
    Sort-Object CreationTime -Descending | 
    Select-Object -Skip 7 | 
    Remove-Item

Write-Host "Backup creado: $backupFile"
```

Ejecutar diariamente con Programador de Tareas de Windows.
