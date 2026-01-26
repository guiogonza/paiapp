# Script para construir APK usando Docker

Write-Host "Construyendo APK con Docker..." -ForegroundColor Cyan

# Construir la imagen de Docker
Write-Host "Paso 1/3: Construyendo imagen de Docker..." -ForegroundColor Yellow
docker build -f Dockerfile.flutter-build -t pai-app-builder .

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error al construir la imagen de Docker" -ForegroundColor Red
    exit 1
}

# Crear contenedor y construir APK
Write-Host "Paso 2/3: Construyendo APK..." -ForegroundColor Yellow
docker run --name pai-app-build-temp pai-app-builder

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error al construir el APK" -ForegroundColor Red
    docker rm pai-app-build-temp 2>$null
    exit 1
}

# Copiar APK del contenedor
Write-Host "Paso 3/3: Extrayendo APK..." -ForegroundColor Yellow
docker cp pai-app-build-temp:/app/build/app/outputs/flutter-apk/app-release.apk ./app-release.apk

if ($LASTEXITCODE -eq 0) {
    Write-Host "APK construido exitosamente!" -ForegroundColor Green
    $apkPath = Get-Item ./app-release.apk -ErrorAction SilentlyContinue
    if ($apkPath) {
        Write-Host "Ubicacion: $($apkPath.FullName)" -ForegroundColor Green
    }
}
else {
    Write-Host "Error al extraer el APK" -ForegroundColor Red
}

# Limpiar contenedor temporal
Write-Host "Limpiando..." -ForegroundColor Yellow
docker rm pai-app-build-temp

Write-Host "Proceso completado!" -ForegroundColor Cyan
