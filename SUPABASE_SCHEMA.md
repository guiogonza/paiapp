# Esquema de Base de Datos Supabase

**Fuente de la Verdad** - Este documento contiene la estructura real de las tablas en Supabase.  
**CRÍTICO:** Antes de escribir código que interactúe con Supabase, consulta este archivo.

---

## documents

Tabla para gestionar documentos de vehículos y conductores.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | Clave primaria |
| `vehicle_id` | uuid | ID del vehículo (nullable) |
| `driver_id` | uuid | ID del conductor (nullable) |
| `type` | text | Tipo de documento |
| `expiration_date` | date | Fecha de expiración |
| `document_url` | text | URL del documento (nullable) |
| `created_by` | uuid | ID del usuario que creó el registro |
| `created_at` | timestamp with time zone | Fecha de creación |
| `updated_at` | timestamp with time zone | Fecha de actualización |

**Notas:**
- Al menos uno de `vehicle_id` o `driver_id` debe estar presente (constraint CHECK)
- `created_by` es obligatorio

---

## driver_locations

Tabla para almacenar ubicaciones de conductores.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | Clave primaria |
| `user_id` | uuid | ID del usuario/conductor |
| `latitude` | double precision | Latitud |
| `longitude` | double precision | Longitud |
| `created_at` | timestamp with time zone | Fecha de creación |

---

## expenses

Tabla para registrar gastos de viajes.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | Clave primaria |
| `trip_id` | uuid | ID del viaje (routes.id) |
| `driver_id` | uuid | ID del conductor que registró el gasto |
| `type` | text | Tipo de gasto |
| `amount` | numeric | Monto del gasto |
| `description` | text | Descripción del gasto |
| `date` | date | Fecha del gasto |
| `receipt_url` | text | URL del recibo (nullable) |
| `created_at` | timestamp with time zone | Fecha de creación |

---

## maintenance

Tabla para registrar mantenimientos de vehículos.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | Clave primaria |
| `vehicle_id` | uuid | ID del vehículo |
| `service_type` | text | Tipo de servicio (Aceite, Llantas, Batería, Frenos, Filtro Aire, Otro) |
| `service_date` | date | Fecha del servicio |
| `km_at_service` | numeric | Kilometraje al momento del servicio |
| `next_change_km` | numeric | Próximo cambio en km (nullable) - usado como alert_km |
| `alert_date` | date | Fecha de alerta para próximo mantenimiento (nullable) |
| `cost` | numeric | Costo del servicio |
| `custom_service_name` | text | Nombre del servicio personalizado (solo para "Otro", nullable) |
| `tire_position` | integer | Posición de la llanta (1-22, solo para "Llantas", nullable) |
| `provider_name` | text | Nombre del proveedor (nullable) |
| `receipt_url` | text | URL del recibo (nullable) |
| `created_by` | uuid | ID del usuario que creó el registro |
| `created_at` | timestamp with time zone | Fecha de creación |

**Notas:**
- `created_by` es obligatorio
- Al registrar mantenimiento, actualizar `vehicles.current_mileage` con `km_at_service`
- `next_change_km` se calcula automáticamente según reglas (Aceite: +10,000 km, Llantas: +9,000 km, etc.)
- `alert_date` se calcula automáticamente para Batería (+4 años) o se define manualmente
- Para tipo "Otro", `custom_service_name` es obligatorio y `alert_date` es obligatorio
- Para tipo "Llantas", `tire_position` (1-22) es obligatorio para identificar la posición específica de la llanta

---

## profiles

Tabla de perfiles de usuarios.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | Clave primaria (coincide con auth.users.id) |
| `email` | text | Email del usuario |
| `full_name` | text | Nombre completo (nullable) |
| `role` | text | Rol del usuario ('owner' o 'driver') |
| `created_at` | timestamp with time zone | Fecha de creación |

**Notas:**
- `id` es la clave primaria y coincide con `auth.users.id`
- `email` y `full_name` existen en esta tabla (agregadas manualmente)
- Para obtener email desde auth.users, usar JOIN: `select('*, auth.users(email)')`

---

## remittances

Tabla para gestionar remisiones/memorandos.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | Clave primaria |
| `trip_id` | uuid | ID del viaje (routes.id) |
| `user_id` | uuid | ID del usuario |
| `receiver_name` | text | Nombre del receptor |
| `status` | text | Estado: 'pendiente_completar', 'pendiente_cobrar', 'cobrado' |
| `document_type` | text | Tipo de documento (nullable) |
| `receipt_url` | text | URL del recibo/memorando (nullable) |
| `signature_url` | text | URL de la firma (nullable) |
| `notes` | text | Notas (nullable) |
| `created_at` | timestamp with time zone | Fecha de creación |
| `updated_at` | timestamp with time zone | Fecha de actualización |

**Notas:**
- El estado inicial es `'pendiente_completar'`
- Cuando el conductor finaliza, cambia a `'pendiente_cobrar'`
- Cuando el dueño marca como cobrado, cambia a `'cobrado'`

---

## routes

Tabla de viajes/rutas.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | Clave primaria |
| `user_id` | uuid | ID del usuario que creó el viaje |
| `vehicle_id` | uuid | ID del vehículo |
| `driver_name` | text | Nombre/email del conductor (nullable) |
| `client_name` | text | Nombre del cliente |
| `origin` | text | Origen |
| `destination` | text | Destino |
| `start_location` | text | Ubicación de inicio (nullable) |
| `end_location` | text | Ubicación de fin (nullable) |
| `start_date` | timestamp with time zone | Fecha de inicio |
| `end_date` | timestamp with time zone | Fecha de fin (nullable) |
| `budget_amount` | numeric | Presupuesto (nullable) |
| `revenue_amount` | numeric | Ingreso real (nullable) |
| `description` | text | Descripción (nullable) |
| `created_at` | timestamp with time zone | Fecha de creación |

**Notas:**
- `driver_name` es un texto (email o nombre), no una FK
- Al crear un viaje, se crea automáticamente una remisión (trigger)

---

## vehicle_history

Tabla para almacenar historial de ubicaciones de vehículos.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | Clave primaria |
| `vehicle_id` | text | ID del vehículo (text, no uuid) |
| `plate` | text | Placa del vehículo |
| `lat` | double precision | Latitud |
| `lng` | double precision | Longitud |
| `timestamp` | timestamp with time zone | Fecha y hora del punto |
| `speed` | double precision | Velocidad (nullable) |
| `heading` | double precision | Dirección/rumbo (nullable) |
| `altitude` | double precision | Altitud (nullable) |
| `valid` | boolean | Si el punto es válido |
| `created_at` | timestamp with time zone | Fecha de creación en BD |

**Notas:**
- `vehicle_id` es TEXT, no UUID (viene del API de GPS)
- Los datos se obtienen del API externo de GPS

---

## vehicles

Tabla de vehículos.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | Clave primaria |
| `owner_id` | uuid | ID del dueño (FK a profiles.id) |
| `user_id` | uuid | ID del usuario (nullable, posiblemente legacy) |
| `plate` | text | Placa del vehículo |
| `brand` | text | Marca |
| `model` | text | Modelo |
| `year` | integer | Año |
| `driver_name` | text | Nombre del conductor asignado (nullable) |
| `gps_device_id` | text | ID del dispositivo GPS (nullable) |
| `current_mileage` | numeric | Kilometraje actual en km (nullable) |
| `image_url` | text | URL de la imagen (nullable) |
| `created_at` | timestamp with time zone | Fecha de creación |

**Notas:**
- `owner_id` es obligatorio y debe coincidir con `profiles.id` del usuario owner
- `gps_device_id` se sincroniza desde el API de GPS
- `current_mileage` se actualiza cuando se registra mantenimiento

---

## Relaciones Clave

- `vehicles.owner_id` → `profiles.id` (FK)
- `expenses.trip_id` → `routes.id` (FK)
- `expenses.driver_id` → `profiles.id` (FK)
- `remittances.trip_id` → `routes.id` (FK)
- `remittances.user_id` → `profiles.id` (FK)
- `maintenance.vehicle_id` → `vehicles.id` (FK)
- `maintenance.created_by` → `profiles.id` (FK)
- `documents.vehicle_id` → `vehicles.id` (FK, nullable)
- `documents.driver_id` → `profiles.id` (FK, nullable)
- `documents.created_by` → `profiles.id` (FK)

---

## Triggers Importantes

- **Creación automática de remisión:** Al insertar en `routes`, se crea automáticamente un registro en `remittances` con status `'pendiente_completar'`

---

## Políticas RLS

- Los usuarios con `role = 'owner'` pueden ver y gestionar todos los recursos
- Los usuarios con `role = 'driver'` solo pueden ver sus propios recursos
- RLS está habilitado en todas las tablas

---

**Última actualización:** 2025-01-XX  
**Versión del esquema:** Basado en schema_summary de Supabase

