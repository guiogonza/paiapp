# Script para ejecutar en dispositivo físico Android

Write-Host "Ejecutando app en dispositivo fisico Android..." -ForegroundColor Cyan

# Agregar Flutter al PATH
$env:PATH = "C:\Flutter\flutter\bin;" + $env:PATH

# Cambiar al directorio del proyecto
Set-Location "c:\Users\guiog\OneDrive\Documentos\Proyecto JP\pai_app"

# Verificar dispositivos conectados
Write-Host "`nDispositivos conectados:" -ForegroundColor Yellow
flutter devices

Write-Host "`n¿El dispositivo aparece en la lista? (S/N): " -NoNewline -ForegroundColor Yellow
$respuesta = Read-Host

if ($respuesta -eq "S" -or $respuesta -eq "s") {
    Write-Host "`nEjecutando la aplicacion..." -ForegroundColor Cyan
    flutter run
} else {
    Write-Host "`nAsegurate de:" -ForegroundColor Red
    Write-Host "1. Tener la depuracion USB activada" -ForegroundColor White
    Write-Host "2. Haber aceptado la autorizacion en el celular" -ForegroundColor White
    Write-Host "3. El cable USB este conectado correctamente" -ForegroundColor White
}
