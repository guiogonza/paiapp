-- ============================================
-- Script para diagnosticar vehículos y conductores del usuario
-- ============================================
-- Ejecuta este script en el SQL Editor de Supabase
-- Dashboard > SQL Editor > New Query > Pega este código > Run

-- 1. Verificar el usuario jpcuartasv@hotmail.com (o jpcuartav@hotmail.com)
SELECT 
  id,
  email,
  full_name,
  role,
  assigned_vehicle_id,
  created_at
FROM public.profiles
WHERE email LIKE '%jpcuartasv@hotmail.com%' 
   OR email LIKE '%jpcuartav@hotmail.com%';

-- 2. Ver TODOS los vehículos en la base de datos
SELECT 
  v.id,
  v.plate,
  v.brand,
  v.model,
  v.year,
  v.owner_id,
  v.gps_device_id,
  v.current_mileage,
  v.vehicle_type,
  p.email as owner_email,
  v.created_at
FROM public.vehicles v
LEFT JOIN public.profiles p ON v.owner_id = p.id
ORDER BY v.created_at DESC;

-- 3. Ver vehículos del usuario específico (usar el ID del paso 1)
-- Reemplaza 'AQUI_EL_ID_DEL_USUARIO' con el ID real obtenido en el paso 1
SELECT 
  v.id,
  v.plate,
  v.brand,
  v.model,
  v.year,
  v.owner_id,
  v.gps_device_id,
  v.current_mileage,
  v.vehicle_type,
  p.email as owner_email
FROM public.vehicles v
LEFT JOIN public.profiles p ON v.owner_id = p.id
WHERE v.owner_id = 'AQUI_EL_ID_DEL_USUARIO';  -- Cambiar por el ID real

-- 4. Ver políticas RLS de la tabla vehicles
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,  -- Condición USING
  with_check  -- Condición WITH CHECK
FROM pg_policies
WHERE tablename = 'vehicles'
ORDER BY policyname;

-- 5. Ver conductores asignados a vehículos
SELECT 
  p.id,
  p.email,
  p.full_name,
  p.role,
  p.assigned_vehicle_id,
  v.plate as vehicle_plate
FROM public.profiles p
LEFT JOIN public.vehicles v ON p.assigned_vehicle_id = v.id
WHERE p.role = 'driver'
ORDER BY p.created_at DESC;

-- 6. Verificar si hay vehículos sin owner_id
SELECT 
  COUNT(*) as vehicles_sin_owner,
  COUNT(*) FILTER (WHERE owner_id IS NULL) as sin_owner_id
FROM public.vehicles;

-- 7. Ver todos los vehículos SIN owner_id (pueden ser los de ejemplo)
SELECT 
  v.id,
  v.plate,
  v.brand,
  v.model,
  v.year,
  v.owner_id,
  v.created_at
FROM public.vehicles v
WHERE v.owner_id IS NULL
ORDER BY v.created_at DESC;

