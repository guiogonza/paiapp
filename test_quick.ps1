# Test API Login
$baseUrl = 'http://localhost:3000'

Write-Host 'TEST: Login' -ForegroundColor Yellow
$loginBody = @{
    email = 'transmaq@rastrear.com.co'
    password = 'Carolina123'
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -Body $loginBody -ContentType 'application/json'
    Write-Host 'Login exitoso!' -ForegroundColor Green
    Write-Host "Token: $($response.token.Substring(0,20))..." -ForegroundColor Gray
    Write-Host "User ID: $($response.user.userId)" -ForegroundColor Gray
    Write-Host "Role: $($response.user.role)" -ForegroundColor Gray
    
    $global:token = $response.token
    $global:headers = @{ Authorization = "Bearer $($response.token)" }
    
    # Test 2: Obtener perfil
    Write-Host ''
    Write-Host 'TEST: Obtener perfil' -ForegroundColor Yellow
    $profile = Invoke-RestMethod -Uri "$baseUrl/profiles/me" -Headers $global:headers
    Write-Host "Perfil: $($profile.fullName) - $($profile.email)" -ForegroundColor Green
    
    # Test 3: Listar vehiculos
    Write-Host ''
    Write-Host 'TEST: Listar vehiculos' -ForegroundColor Yellow
    $vehicles = Invoke-RestMethod -Uri "$baseUrl/vehicles" -Headers $global:headers
    Write-Host "Vehiculos encontrados: $($vehicles.Count)" -ForegroundColor Green
    
    # Test 4: Listar conductores
    Write-Host ''
    Write-Host 'TEST: Listar conductores' -ForegroundColor Yellow
    $drivers = Invoke-RestMethod -Uri "$baseUrl/profiles/drivers" -Headers $global:headers
    Write-Host "Conductores encontrados: $($drivers.Count)" -ForegroundColor Green
    
    # Test 5: Listar gastos
    Write-Host ''
    Write-Host 'TEST: Listar gastos' -ForegroundColor Yellow
    $expenses = Invoke-RestMethod -Uri "$baseUrl/expenses" -Headers $global:headers
    Write-Host "Gastos encontrados: $($expenses.Count)" -ForegroundColor Green
    
    # Test 6: Listar ingresos
    Write-Host ''
    Write-Host 'TEST: Listar ingresos' -ForegroundColor Yellow
    $incomes = Invoke-RestMethod -Uri "$baseUrl/incomes" -Headers $global:headers
    Write-Host "Ingresos encontrados: $($incomes.Count)" -ForegroundColor Green
    
    # Test 7: Listar viajes
    Write-Host ''
    Write-Host 'TEST: Listar viajes' -ForegroundColor Yellow
    $trips = Invoke-RestMethod -Uri "$baseUrl/trips" -Headers $global:headers
    Write-Host "Viajes encontrados: $($trips.Count)" -ForegroundColor Green
    
    Write-Host ''
    Write-Host 'RESUMEN DE PRUEBAS COMPLETADO' -ForegroundColor Cyan
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host $_.ErrorDetails.Message -ForegroundColor Red
    }
}
