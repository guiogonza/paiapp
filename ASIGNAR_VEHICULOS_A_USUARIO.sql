-- ============================================
-- Script para asignar vehículos existentes al usuario
-- ============================================
-- IMPORTANTE: Primero ejecuta DIAGNOSTICAR_VEHICULOS_USUARIO.sql para obtener los IDs

-- Paso 1: Obtener el ID del usuario jpcuartasv@hotmail.com
-- Ejecuta esto primero y copia el ID que te devuelva
SELECT id, email, full_name, role
FROM public.profiles
WHERE email = 'jpcuartasv@hotmail.com';

-- Paso 2: Ver vehículos que NO tienen owner_id asignado
-- Estos pueden ser los vehículos de ejemplo que necesitas asignar
SELECT 
  id,
  plate,
  brand,
  model,
  year,
  owner_id
FROM public.vehicles
WHERE owner_id IS NULL
ORDER BY created_at DESC;

-- Paso 3: Asignar vehículos al usuario
-- Reemplaza:
-- - 'ID_DEL_USUARIO' con el ID obtenido en el Paso 1
-- - 'ID_DEL_VEHICULO' con los IDs de los vehículos del Paso 2

-- Ejemplo: Asignar un vehículo específico
UPDATE public.vehicles
SET owner_id = 'ID_DEL_USUARIO'  -- Cambiar por el ID real del usuario
WHERE id = 'ID_DEL_VEHICULO'  -- Cambiar por el ID del vehículo
  AND owner_id IS NULL;  -- Solo actualizar si no tiene owner

-- Ejemplo: Asignar TODOS los vehículos sin owner al usuario
-- ⚠️ CUIDADO: Esto asignará TODOS los vehículos sin owner
UPDATE public.vehicles
SET owner_id = 'ID_DEL_USUARIO'  -- Cambiar por el ID real del usuario
WHERE owner_id IS NULL;

-- Paso 4: Asignar conductores a vehículos
-- Asignar un conductor específico a un vehículo
UPDATE public.profiles
SET assigned_vehicle_id = 'ID_DEL_VEHICULO'  -- Cambiar por el ID del vehículo
WHERE id = 'ID_DEL_CONDUCTOR'  -- Cambiar por el ID del conductor
  AND role = 'driver';

-- Paso 5: Verificar que se asignaron correctamente
SELECT 
  v.id,
  v.plate,
  v.brand,
  v.model,
  v.owner_id,
  p.email as owner_email
FROM public.vehicles v
LEFT JOIN public.profiles p ON v.owner_id = p.id
WHERE p.email = 'jpcuartasv@hotmail.com';

-- Paso 6: Ver conductores asignados a vehículos del usuario
SELECT 
  p.id,
  p.email,
  p.full_name,
  p.assigned_vehicle_id,
  v.plate as vehicle_plate,
  v.owner_id,
  owner.email as owner_email
FROM public.profiles p
LEFT JOIN public.vehicles v ON p.assigned_vehicle_id = v.id
LEFT JOIN public.profiles owner ON v.owner_id = owner.id
WHERE owner.email = 'jpcuartasv@hotmail.com'
  AND p.role = 'driver';

