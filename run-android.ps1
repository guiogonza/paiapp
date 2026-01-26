# Script para ejecutar la app en el emulador de Android

Write-Host "Preparando para ejecutar la app en el emulador..." -ForegroundColor Cyan

# Agregar Flutter al PATH
$env:PATH = "C:\Flutter\flutter\bin;" + $env:PATH

# Verificar emuladores disponibles
Write-Host "`nEmuladores disponibles:" -ForegroundColor Yellow
flutter emulators

Write-Host "`n¿Quieres iniciar un emulador? (S/N): " -NoNewline -ForegroundColor Yellow
$respuesta = Read-Host

if ($respuesta -eq "S" -or $respuesta -eq "s") {
    Write-Host "`nListando emuladores..." -ForegroundColor Yellow
    $emuladores = flutter emulators 2>&1 | Select-String "•" 
    
    if ($emuladores) {
        Write-Host "Ingresa el ID del emulador a iniciar: " -NoNewline -ForegroundColor Yellow
        $emulatorId = Read-Host
        
        Write-Host "`nIniciando emulador $emulatorId..." -ForegroundColor Yellow
        Start-Process flutter -ArgumentList "emulators --launch $emulatorId" -NoNewWindow
        
        Write-Host "Esperando a que el emulador inicie (30 segundos)..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
    } else {
        Write-Host "No se encontraron emuladores. Crea uno en Android Studio primero." -ForegroundColor Red
        exit 1
    }
}

# Cambiar al directorio del proyecto
Set-Location "c:\Users\guiog\OneDrive\Documentos\Proyecto JP\pai_app"

# Ejecutar la app
Write-Host "`nEjecutando la aplicacion en el emulador..." -ForegroundColor Cyan
flutter run

Write-Host "`nApp finalizada." -ForegroundColor Green
