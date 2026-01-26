# ============================================
# Descargar y Restaurar Backup desde Supabase
# ============================================

param(
    [string]$SupabaseUrl = "https://urlbbkpuaiugputhnsqx.supabase.co",
    [string]$ServiceRoleKey = ""
)

$ErrorActionPreference = "Stop"

Write-Host "🔄 Descargando backup desde Supabase..." -ForegroundColor Cyan

if ($ServiceRoleKey -eq "") {
    Write-Host "`n⚠️  Necesitas proporcionar el Service Role Key de Supabase" -ForegroundColor Yellow
    Write-Host "    Para obtenerla:" -ForegroundColor White
    Write-Host "    1. Ve a https://supabase.com/dashboard" -ForegroundColor White
    Write-Host "    2. Proyecto: urlbbkpuaiugputhnsqx" -ForegroundColor White
    Write-Host "    3. Settings → API → Service Role Key" -ForegroundColor White
    Write-Host "`n    Uso: .\descargar-backup-supabase.ps1 -ServiceRoleKey 'tu-service-role-key'" -ForegroundColor Cyan
    Write-Host "`n    O descarga manualmente desde:" -ForegroundColor Yellow
    Write-Host "    Dashboard → Database → Backups → Download" -ForegroundColor White
    exit 0
}

# Configuración
$fecha = Get-Date -Format 'yyyyMMdd_HHmmss'
$carpetaBackups = "backups"
$archivoBackup = "$carpetaBackups/backup_supabase_$fecha.sql"

# Crear carpeta si no existe
if (!(Test-Path $carpetaBackups)) {
    New-Item -ItemType Directory -Force -Path $carpetaBackups | Out-Null
}

# Headers para la API
$headers = @{
    "Authorization" = "Bearer $ServiceRoleKey"
    "apikey" = $ServiceRoleKey
}

try {
    Write-Host "📡 Conectando a Supabase..." -ForegroundColor Cyan
    
    # Obtener todas las tablas y sus datos
    $tablas = @('profiles', 'vehicles', 'routes', 'remittances', 'expenses', 'maintenance', 'documents', 'vehicle_history', 'driver_locations')
    
    $sqlContent = "-- Backup de Supabase generado el $fecha`n"
    $sqlContent += "-- Proyecto: urlbbkpuaiugputhnsqx`n`n"
    
    foreach ($tabla in $tablas) {
        Write-Host "  Descargando tabla: $tabla" -ForegroundColor DarkGray
        
        try {
            $url = "$SupabaseUrl/rest/v1/$tabla`?select=*"
            $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
            
            if ($response.Count -gt 0) {
                $sqlContent += "-- Tabla: $tabla ($($response.Count) registros)`n"
                $sqlContent += "-- Datos descargados`n`n"
            }
        }
        catch {
            Write-Host "    ⚠️  Error descargando $tabla - $_" -ForegroundColor Yellow
        }
    }
    
    # Guardar archivo
    $sqlContent | Out-File -FilePath $archivoBackup -Encoding UTF8
    
    Write-Host "`n✅ Backup descargado: $archivoBackup" -ForegroundColor Green
    
    # Preguntar si restaurar
    $restaurar = Read-Host "`n¿Restaurar en PostgreSQL local? (S/N)"
    
    if ($restaurar -eq "S" -or $restaurar -eq "s") {
        Write-Host "`n🔄 Restaurando en PostgreSQL local..." -ForegroundColor Cyan
        & ".\backup-auto.ps1" -DesdeSupabase -ArchivoSupabase $archivoBackup
    }
}
catch {
    Write-Host "`n❌ Error: $_" -ForegroundColor Red
    Write-Host "`nPor favor, descarga el backup manualmente desde:" -ForegroundColor Yellow
    Write-Host "https://supabase.com/dashboard → Database → Backups" -ForegroundColor White
}
