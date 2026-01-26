# ============================================
# Exportar datos desde Supabase usando pg_dump
# ============================================

$ErrorActionPreference = "Stop"

Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║          DESCARGAR BACKUP DESDE SUPABASE                     ║
╚══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

Write-Host "📋 OPCIÓN 1: Descarga Manual (Recomendado)" -ForegroundColor Green
Write-Host "   1. Ve a: https://supabase.com/dashboard" -ForegroundColor White
Write-Host "   2. Proyecto: urlbbkpuaiugputhnsqx" -ForegroundColor White
Write-Host "   3. Database → Backups → Download backup" -ForegroundColor White
Write-Host "   4. Guarda el archivo en: $(Get-Location)\backups\" -ForegroundColor White
Write-Host ""

Write-Host "📋 OPCIÓN 2: Usar pg_dump (Requiere PostgreSQL instalado localmente)" -ForegroundColor Yellow
Write-Host "   Necesitarás:" -ForegroundColor White
Write-Host "   - Host: db.urlbbkpuaiugputhnsqx.supabase.co" -ForegroundColor DarkGray
Write-Host "   - Puerto: 5432" -ForegroundColor DarkGray
Write-Host "   - Usuario: postgres" -ForegroundColor DarkGray
Write-Host "   - Database: postgres" -ForegroundColor DarkGray
Write-Host "   - Password: (tu password de Supabase)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "   Comando:" -ForegroundColor White
Write-Host '   $env:PGPASSWORD="TU_PASSWORD"; pg_dump -h db.urlbbkpuaiugputhnsqx.supabase.co -U postgres -d postgres > backups\backup_supabase.sql' -ForegroundColor DarkGray
Write-Host ""

Write-Host "📋 OPCIÓN 3: Usar Adminer Web" -ForegroundColor Cyan
Write-Host "   1. Abre: http://localhost:8081" -ForegroundColor White
Write-Host "   2. Conecta a Supabase con los datos de conexión" -ForegroundColor White
Write-Host "   3. Export → SQL format → Save" -ForegroundColor White
Write-Host ""

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

$opcion = Read-Host "`n¿Qué opción prefieres? (1/2/3)"

switch ($opcion) {
    "1" {
        Write-Host "`n🌐 Abriendo Dashboard de Supabase..." -ForegroundColor Cyan
        Start-Process "https://supabase.com/dashboard/project/urlbbkpuaiugputhnsqx/database/backups"
        
        Write-Host "`n⏳ Esperando descarga..." -ForegroundColor Yellow
        Write-Host "   Una vez descargues el archivo, guárdalo como:" -ForegroundColor White
        Write-Host "   $(Get-Location)\backups\backup_supabase.sql" -ForegroundColor Green
        
        Read-Host "`nPresiona Enter cuando hayas descargado el archivo"
        
        $archivoBackup = "backups\backup_supabase.sql"
        if (Test-Path $archivoBackup) {
            Write-Host "✅ Archivo encontrado" -ForegroundColor Green
            $restaurar = Read-Host "`n¿Restaurar en PostgreSQL local? (S/N)"
            if ($restaurar -eq "S" -or $restaurar -eq "s") {
                & ".\backup-auto.ps1" -DesdeSupabase -ArchivoSupabase $archivoBackup
            }
        } else {
            Write-Host "❌ Archivo no encontrado en: $archivoBackup" -ForegroundColor Red
        }
    }
    
    "2" {
        Write-Host "`n📝 Ingresa los datos de conexión de Supabase:" -ForegroundColor Cyan
        Write-Host "   (Los encuentras en: Settings → Database → Connection string)" -ForegroundColor DarkGray
        
        $password = Read-Host "`nPassword de Supabase" -AsSecureString
        $passwordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
        
        $fecha = Get-Date -Format 'yyyyMMdd_HHmmss'
        $archivoBackup = "backups\backup_supabase_$fecha.sql"
        
        Write-Host "`n🔄 Ejecutando pg_dump..." -ForegroundColor Cyan
        
        $env:PGPASSWORD = $passwordPlain
        & pg_dump -h db.urlbbkpuaiugputhnsqx.supabase.co -U postgres -d postgres > $archivoBackup
        
        if (Test-Path $archivoBackup) {
            $tamano = (Get-Item $archivoBackup).Length / 1KB
            $tamanoRedondeado = [math]::Round($tamano, 2)
            Write-Host "Backup creado: $archivoBackup ($tamanoRedondeado KB)" -ForegroundColor Green
            
            $restaurar = Read-Host "Restaurar en PostgreSQL local? (S/N)"
            if ($restaurar -eq "S" -or $restaurar -eq "s") {
                & ".\backup-auto.ps1" -DesdeSupabase -ArchivoSupabase $archivoBackup
            }
        }
    }
    
    "3" {
        Write-Host "`n🌐 Abriendo Adminer..." -ForegroundColor Cyan
        Start-Process "http://localhost:8081"
        
        Write-Host "`n📋 Datos de conexión a Supabase:" -ForegroundColor Cyan
        Write-Host "   Sistema: PostgreSQL" -ForegroundColor White
        Write-Host "   Servidor: db.urlbbkpuaiugputhnsqx.supabase.co" -ForegroundColor White
        Write-Host "   Usuario: postgres" -ForegroundColor White
        Write-Host "   Password: (tu password de Supabase)" -ForegroundColor White
        Write-Host "   Base de datos: postgres" -ForegroundColor White
        Write-Host ""
        Write-Host "   Luego: Export → SQL format → Save" -ForegroundColor Yellow
    }
    
    default {
        Write-Host "`n❌ Opción inválida" -ForegroundColor Red
    }
}

Write-Host "`n✅ Proceso completado" -ForegroundColor Green
