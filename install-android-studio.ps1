# Script para instalar Android Studio

Write-Host "Instalando Android Studio..." -ForegroundColor Cyan

# URL de descarga de Android Studio
$androidStudioUrl = "https://dl.google.com/dl/android/studio/install/2024.2.1.12/android-studio-2024.2.1.12-windows.exe"
$installerPath = "$env:TEMP\android-studio-installer.exe"

# Descargar Android Studio
Write-Host "Descargando Android Studio (aproximadamente 1.1 GB)..." -ForegroundColor Yellow
Write-Host "Esto puede tomar varios minutos dependiendo de tu conexion..." -ForegroundColor Yellow

try {
    Invoke-WebRequest -Uri $androidStudioUrl -OutFile $installerPath -UseBasicParsing
    Write-Host "Descarga completada!" -ForegroundColor Green
} catch {
    Write-Host "Error al descargar Android Studio: $_" -ForegroundColor Red
    exit 1
}

# Ejecutar instalador
Write-Host "`nIniciando instalador de Android Studio..." -ForegroundColor Yellow
Write-Host "IMPORTANTE: Durante la instalacion:" -ForegroundColor Yellow
Write-Host "  1. Acepta la instalacion de Android SDK" -ForegroundColor Yellow
Write-Host "  2. Acepta la instalacion de Android Virtual Device (AVD)" -ForegroundColor Yellow
Write-Host "  3. Usa la configuracion estandar (Standard Setup)" -ForegroundColor Yellow

Start-Process -FilePath $installerPath -Wait

Write-Host "`nInstalacion completada!" -ForegroundColor Green
Write-Host "`nPasos siguientes:" -ForegroundColor Cyan
Write-Host "1. Abre Android Studio" -ForegroundColor White
Write-Host "2. Completa el asistente de configuracion inicial" -ForegroundColor White
Write-Host "3. Ve a Tools > Device Manager" -ForegroundColor White
Write-Host "4. Crea un nuevo dispositivo virtual (recomendado: Pixel 7 con Android 13)" -ForegroundColor White
Write-Host "5. Ejecuta: flutter emulators" -ForegroundColor White
Write-Host "6. Ejecuta: flutter run" -ForegroundColor White

# Limpiar archivo temporal
Remove-Item $installerPath -ErrorAction SilentlyContinue

Write-Host "`nPresiona cualquier tecla para salir..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
