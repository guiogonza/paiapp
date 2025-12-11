-- ============================================
-- Script para verificar el estado de pepe@pai.com
-- ============================================
-- Ejecuta este script en el SQL Editor de Supabase
-- Dashboard > SQL Editor > New Query > Pega este codigo > Run

-- NOTA: auth.users no es directamente accesible desde el SQL Editor
-- Solo podemos verificar en public.profiles

-- 1. Verificar si existe en profiles y su role
SELECT 
  id,
  email,
  full_name,
  role,
  created_at,
  updated_at
FROM public.profiles
WHERE email = 'pepe@pai.com';

-- 2. Verificar TODOS los perfiles con role='driver'
SELECT 
  id,
  email,
  full_name,
  role,
  created_at
FROM public.profiles
WHERE role = 'driver'
ORDER BY created_at DESC;

-- 3. Verificar el conteo de conductores
SELECT 
  COUNT(*) as total_drivers,
  STRING_AGG(email, ', ') as driver_emails
FROM public.profiles
WHERE role = 'driver';

-- 4. Verificar TODOS los perfiles (para diagnóstico)
SELECT 
  id,
  email,
  full_name,
  role,
  created_at
FROM public.profiles
ORDER BY created_at DESC
LIMIT 20;

