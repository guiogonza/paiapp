-- ============================================
-- Script para crear datos de ejemplo (vehículos y conductores)
-- ============================================
-- Ejecuta este script en el SQL Editor de Supabase
-- IMPORTANTE: Primero obtén el ID del usuario con DIAGNOSTICAR_VEHICULOS_USUARIO.sql

-- Paso 1: Obtener el ID del usuario jpcuartasv@hotmail.com
-- Ejecuta esto primero:
SELECT id, email, full_name, role
FROM public.profiles
WHERE email = 'jpcuartasv@hotmail.com';

-- Paso 2: Crear vehículos de ejemplo
-- Reemplaza 'ID_DEL_USUARIO' con el ID obtenido en el Paso 1

INSERT INTO public.vehicles (
  owner_id,
  plate,
  brand,
  model,
  year,
  vehicle_type,
  current_mileage,
  gps_device_id
) VALUES
  -- Vehículo 1
  (
    'ID_DEL_USUARIO',  -- Cambiar por el ID real
    'ABC123',
    'Mercedes-Benz',
    'Actros',
    2020,
    'turbo_sencillo',
    50000.0,
    NULL  -- O el gps_device_id si lo tienes
  ),
  -- Vehículo 2
  (
    'ID_DEL_USUARIO',  -- Cambiar por el ID real
    'XYZ789',
    'Scania',
    'R450',
    2021,
    'doble_troque',
    35000.0,
    NULL
  ),
  -- Vehículo 3
  (
    'ID_DEL_USUARIO',  -- Cambiar por el ID real
    'DEF456',
    'Volvo',
    'FH16',
    2022,
    'mini_mula_18',
    20000.0,
    NULL
  )
ON CONFLICT (plate) DO NOTHING;  -- Si la placa ya existe, no hacer nada

-- Paso 3: Crear conductores de ejemplo (si no existen)
-- Primero asegúrate de que los usuarios existen en auth.users
-- Si no existen, créalos desde la app o desde Supabase Auth

-- Asignar vehículos a conductores existentes
-- Reemplaza los IDs según corresponda:

-- Conductor 1
UPDATE public.profiles
SET assigned_vehicle_id = (
  SELECT id FROM public.vehicles 
  WHERE plate = 'ABC123' AND owner_id = 'ID_DEL_USUARIO'
  LIMIT 1
)
WHERE email = 'conductor1@ejemplo.com'  -- Cambiar por el email del conductor
  AND role = 'driver';

-- Conductor 2
UPDATE public.profiles
SET assigned_vehicle_id = (
  SELECT id FROM public.vehicles 
  WHERE plate = 'XYZ789' AND owner_id = 'ID_DEL_USUARIO'
  LIMIT 1
)
WHERE email = 'conductor2@ejemplo.com'  -- Cambiar por el email del conductor
  AND role = 'driver';

-- Paso 4: Verificar que se crearon correctamente
SELECT 
  v.id,
  v.plate,
  v.brand,
  v.model,
  v.year,
  v.vehicle_type,
  v.owner_id,
  p.email as owner_email
FROM public.vehicles v
LEFT JOIN public.profiles p ON v.owner_id = p.id
WHERE p.email = 'jpcuartasv@hotmail.com'
ORDER BY v.created_at DESC;

-- Paso 5: Ver conductores con vehículos asignados
SELECT 
  p.id,
  p.email,
  p.full_name,
  p.role,
  p.assigned_vehicle_id,
  v.plate as vehicle_plate
FROM public.profiles p
LEFT JOIN public.vehicles v ON p.assigned_vehicle_id = v.id
WHERE v.owner_id = 'ID_DEL_USUARIO'  -- Cambiar por el ID real
  AND p.role = 'driver';

