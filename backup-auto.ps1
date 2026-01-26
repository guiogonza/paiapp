# ============================================
# Script de Backup Automático PostgreSQL Local
# ============================================

param(
    [switch]$DesdeSupabase,
    [string]$ArchivoSupabase = ""
)

$ErrorActionPreference = "Stop"

# Configuración
$carpetaBackups = "backups"
$fecha = Get-Date -Format 'yyyyMMdd_HHmmss'

# Crear carpeta de backups si no existe
if (!(Test-Path $carpetaBackups)) {
    New-Item -ItemType Directory -Force -Path $carpetaBackups | Out-Null
    Write-Host "✅ Carpeta de backups creada: $carpetaBackups" -ForegroundColor Green
}

# ============================================
# OPCIÓN 1: Backup desde PostgreSQL local
# ============================================
if (!$DesdeSupabase) {
    Write-Host "🔄 Creando backup desde PostgreSQL local..." -ForegroundColor Cyan
    
    $backupFile = "$carpetaBackups/backup_local_$fecha.sql"
    
    # Verificar que el contenedor está corriendo
    $contenedorActivo = docker ps --filter "name=pai-postgres" --format "{{.Names}}"
    
    if ($contenedorActivo -ne "pai-postgres") {
        Write-Host "❌ El contenedor pai-postgres no está corriendo" -ForegroundColor Red
        Write-Host "Ejecuta: docker compose -f docker-compose.local-db.yml up -d" -ForegroundColor Yellow
        exit 1
    }
    
    # Crear backup
    docker exec pai-postgres pg_dump -U postgres pai_app > $backupFile
    
    if (Test-Path $backupFile) {
        $tamano = (Get-Item $backupFile).Length / 1KB
        Write-Host "✅ Backup creado exitosamente: $backupFile ($([math]::Round($tamano, 2)) KB)" -ForegroundColor Green
    } else {
        Write-Host "❌ Error al crear backup" -ForegroundColor Red
        exit 1
    }
    
    # Limpiar backups antiguos (mantener solo últimos 7)
    Write-Host "🧹 Limpiando backups antiguos..." -ForegroundColor Cyan
    $backupsAntiguos = Get-ChildItem "$carpetaBackups/backup_local_*.sql" | 
        Sort-Object CreationTime -Descending | 
        Select-Object -Skip 7
    
    if ($backupsAntiguos) {
        $backupsAntiguos | ForEach-Object {
            Write-Host "  Eliminando: $($_.Name)" -ForegroundColor DarkGray
            Remove-Item $_.FullName
        }
        Write-Host "✅ Limpieza completada" -ForegroundColor Green
    } else {
        Write-Host "  No hay backups antiguos para eliminar" -ForegroundColor DarkGray
    }
}

# ============================================
# OPCIÓN 2: Restaurar backup desde Supabase
# ============================================
else {
    Write-Host "🔄 Restaurando backup desde Supabase..." -ForegroundColor Cyan
    
    if ($ArchivoSupabase -eq "") {
        Write-Host "❌ Debes especificar el archivo de backup con -ArchivoSupabase" -ForegroundColor Red
        Write-Host "Ejemplo: .\backup-auto.ps1 -DesdeSupabase -ArchivoSupabase 'backup_supabase.sql'" -ForegroundColor Yellow
        exit 1
    }
    
    if (!(Test-Path $ArchivoSupabase)) {
        Write-Host "❌ Archivo no encontrado: $ArchivoSupabase" -ForegroundColor Red
        exit 1
    }
    
    # Copiar archivo al contenedor
    Write-Host "📁 Copiando archivo al contenedor..." -ForegroundColor Cyan
    docker cp $ArchivoSupabase pai-postgres:/tmp/backup.sql
    
    # Restaurar
    Write-Host "🔄 Restaurando base de datos..." -ForegroundColor Cyan
    docker exec -i pai-postgres psql -U postgres -d pai_app -f /tmp/backup.sql
    
    Write-Host "✅ Backup restaurado exitosamente desde Supabase" -ForegroundColor Green
    
    # Crear copia local del backup restaurado
    Write-Host "💾 Creando copia de seguridad local..." -ForegroundColor Cyan
    $backupLocal = "$carpetaBackups/backup_from_supabase_$fecha.sql"
    Copy-Item $ArchivoSupabase $backupLocal
    Write-Host "✅ Copia guardada: $backupLocal" -ForegroundColor Green
}

# ============================================
# Mostrar estadísticas
# ============================================
Write-Host "`n📊 Estadísticas de backups:" -ForegroundColor Cyan
$todosBackups = Get-ChildItem "$carpetaBackups/*.sql" | Sort-Object CreationTime -Descending
Write-Host "  Total de backups: $($todosBackups.Count)" -ForegroundColor White
Write-Host "  Tamaño total: $([math]::Round(($todosBackups | Measure-Object -Property Length -Sum).Sum / 1MB, 2)) MB" -ForegroundColor White

if ($todosBackups.Count -gt 0) {
    Write-Host "`n  Últimos backups:" -ForegroundColor White
    $todosBackups | Select-Object -First 5 | ForEach-Object {
        $tamano = [math]::Round($_.Length / 1KB, 2)
        Write-Host "    - $($_.Name) ($tamano KB) - $($_.LastWriteTime)" -ForegroundColor DarkGray
    }
}

Write-Host "`n✅ Proceso completado" -ForegroundColor Green
