# Sincronización BD Local ↔ Producción
**Fecha:** 29 de enero de 2026  
**Estado:** ✅ SINCRONIZADO

## 📊 Resumen de Tablas

Ambas bases de datos (Local y Producción) tienen las siguientes 10 tablas:

1. ✅ `profiles` - Usuarios del sistema
2. ✅ `vehicles` - Vehículos
3. ✅ `vehicle_history` - Historial de ubicaciones
4. ✅ `documents` - Documentos de vehículos
5. ✅ `trips` - Viajes/recorridos
6. ✅ `expenses` - Gastos
7. ✅ `maintenance` - Mantenimientos
8. ✅ `remisiones` - Documentos de envío
9. ✅ `gps_credentials` - Credenciales GPS
10. ✅ `user_settings` - Configuraciones de usuario

## 🔧 Correcciones Aplicadas

### 1. Tabla `documents`
- ✅ Agregada columna `driver_id UUID` en ambas BD
- ✅ Relación con `profiles(id)` configurada

### 2. Tabla `user_settings`
- ✅ Tabla creada en ambas BD
- Columnas:
  - `id` (UUID, PK)
  - `user_id` (UUID, FK a profiles)
  - `setting_key` (VARCHAR(100))
  - `setting_value` (TEXT)
  - `created_at` (TIMESTAMP)
  - `updated_at` (TIMESTAMP)
- ✅ Constraint único en (user_id, setting_key)

### 3. Tabla `maintenance`
- ✅ Columnas adicionales agregadas:
  - `service_date` (DATE)
  - `km_at_service` (DECIMAL)
  - `alert_date` (DATE)
  - `custom_service_name` (VARCHAR)
  - `tire_position` (VARCHAR)
  - `created_by` (UUID, FK a profiles)
  - `provider_name` (VARCHAR)
- ✅ Índices creados en campos nuevos

## 📋 Estructura Completa por Tabla

### profiles (11 columnas)
- id, email, password_hash, full_name, role, assigned_vehicle_id, phone, avatar_url, is_active, created_at, updated_at

### vehicles (13 columnas)
- id, placa, marca, modelo, ano, color, tipo, capacidad_carga, gps_device_id, owner_id, is_active, created_at, updated_at

### vehicle_history (12 columnas)
- id, vehicle_id, driver_id, latitude, longitude, speed, altitude, heading, accuracy, address, recorded_at, created_at

### documents (13 columnas)
- id, vehicle_id, document_type, document_number, issue_date, expiry_date, alert_date, document_url, notes, is_archived, created_at, updated_at, driver_id

### trips (26 columnas)
- id, vehicle_id, driver_id, driver_name, client_name, start_time, end_time, start_date, end_date, start_latitude, start_longitude, end_latitude, end_longitude, start_address, end_address, start_location, end_location, distance_km, duration_minutes, fuel_consumed, revenue_amount, budget_amount, status, notes, created_at, updated_at

### expenses (12 columnas)
- id, vehicle_id, trip_id, driver_id, expense_type, amount, currency, description, receipt_url, expense_date, created_at, updated_at

### maintenance (23 columnas)
- id, vehicle_id, maintenance_type, description, cost, odometer_reading, scheduled_date, completed_date, next_maintenance_date, next_maintenance_km, workshop_name, invoice_number, notes, status, created_at, updated_at, service_date, km_at_service, alert_date, custom_service_name, tire_position, created_by, provider_name

### remisiones (18 columnas)
- id, vehicle_id, driver_id, trip_id, remision_number, origin_address, destination_address, cargo_description, weight_kg, client_name, client_phone, delivery_status, signature_url, photo_urls, notes, created_at, updated_at, delivered_at

### gps_credentials (10 columnas)
- id, user_id, gps_email, gps_password_encrypted, gps_api_key, gps_platform, is_active, last_sync_at, created_at, updated_at

### user_settings (6 columnas)
- id, user_id, setting_key, setting_value, created_at, updated_at

## 🎯 Estado de Sincronización

| Componente | Local | Producción | Estado |
|------------|-------|------------|--------|
| Tablas | 10 | 10 | ✅ Igual |
| Columnas totales | 144 | 144 | ✅ Igual |
| Índices | ✅ | ✅ | ✅ Sincronizados |
| Foreign Keys | ✅ | ✅ | ✅ Sincronizados |
| Triggers | ✅ | ✅ | ✅ Sincronizados |

## 📝 Archivos Actualizados

1. ✅ `/database/init.sql` - Schema local actualizado
2. ✅ `/database/migrate_maintenance.sql` - Migración de maintenance
3. ✅ `/database/sync_prod_local.sql` - Script de sincronización completo
4. ✅ `/api/server.js` - Endpoints corregidos para usar nombres correctos de columnas

## ✅ Conclusión

**Ambas bases de datos están ahora completamente sincronizadas** con la misma estructura de tablas, columnas, índices, constraints y triggers. El registro de mantenimiento funciona correctamente tanto en local como en producción.
