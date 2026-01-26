# Script para construir e instalar APK en el emulador

Write-Host "Construyendo e instalando APK en el emulador..." -ForegroundColor Cyan

# Agregar Flutter al PATH
$env:PATH = "C:\Flutter\flutter\bin;" + $env:PATH

# Cambiar al directorio del proyecto
Set-Location "c:\Users\guiog\OneDrive\Documentos\Proyecto JP\pai_app"

# Esperar a que Gradle no esté bloqueado
Write-Host "Esperando a que Gradle este disponible..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Construir APK
Write-Host "`nConstruyendo APK de release..." -ForegroundColor Yellow
flutter build apk --release

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nAPK construido exitosamente!" -ForegroundColor Green
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    
    if (Test-Path $apkPath) {
        Write-Host "Ubicacion: $(Resolve-Path $apkPath)" -ForegroundColor Green
        
        # Instalar en el emulador
        Write-Host "`nInstalando en el emulador..." -ForegroundColor Yellow
        $adbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
        
        if (Test-Path $adbPath) {
            & $adbPath install -r $apkPath
            Write-Host "`nAPK instalado en el emulador!" -ForegroundColor Green
            Write-Host "Busca 'pai_app' en el cajon de aplicaciones del emulador." -ForegroundColor Cyan
        } else {
            Write-Host "No se encontro adb. Instala manualmente el APK:" -ForegroundColor Yellow
            Write-Host "Arrastra el archivo $apkPath al emulador" -ForegroundColor White
        }
    }
} else {
    Write-Host "`nError al construir el APK" -ForegroundColor Red
}

Write-Host "`nPresiona Enter para salir..." -ForegroundColor Gray
Read-Host
