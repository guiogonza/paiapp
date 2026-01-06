-- ============================================
-- Script para verificar el usuario super_admin
-- ============================================
-- Ejecuta este script en el SQL Editor de Supabase
-- Dashboard > SQL Editor > New Query > Pega este código > Run

-- Ver todos los usuarios con rol super_admin
SELECT 
  id,
  email,
  full_name,
  role,
  created_at,
  updated_at
FROM public.profiles
WHERE role = 'super_admin'
ORDER BY created_at DESC;

-- Ver todos los usuarios y sus roles (para referencia)
SELECT 
  id,
  email,
  full_name,
  role,
  created_at
FROM public.profiles
ORDER BY 
  CASE role
    WHEN 'super_admin' THEN 1
    WHEN 'owner' THEN 2
    WHEN 'driver' THEN 3
    ELSE 4
  END,
  created_at DESC;

-- Verificar específicamente si pai@admin.com es super_admin
SELECT 
  id,
  email,
  full_name,
  role,
  created_at
FROM public.profiles
WHERE email = 'pai@admin.com';

