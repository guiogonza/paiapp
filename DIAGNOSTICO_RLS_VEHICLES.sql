-- Script de diagnostico para verificar politicas RLS de vehicles
-- Ejecuta este script en el SQL Editor de Supabase
-- IMPORTANTE: Cambia 'luisr@rastrear.com.co' por tu email

-- 1. Verificar que el usuario existe en auth.users
SELECT 
  id,
  email,
  created_at,
  email_confirmed_at
FROM auth.users
WHERE email = 'luisr@rastrear.com.co';

-- 2. Verificar que el perfil existe en profiles con el ID correcto
SELECT 
  id,
  role,
  full_name,
  created_at
FROM public.profiles
WHERE id = (SELECT id FROM auth.users WHERE email = 'luisr@rastrear.com.co');

-- 3. Verificar que el perfil tiene role = 'owner'
SELECT 
  p.id,
  p.role,
  au.email,
  CASE 
    WHEN p.role = 'owner' THEN 'Rol correcto: owner'
    ELSE 'Rol incorrecto: ' || p.role
  END as estado_rol
FROM public.profiles p
JOIN auth.users au ON au.id = p.id
WHERE au.email = 'luisr@rastrear.com.co';

-- 4. Verificar las politicas RLS actuales de vehicles
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'vehicles'
ORDER BY policyname;

-- 5. Verificar si RLS esta habilitado en la tabla vehicles
SELECT 
  schemaname,
  tablename,
  rowsecurity as rls_habilitado
FROM pg_tables
WHERE tablename = 'vehicles';

-- 6. Probar manualmente si el usuario puede insertar (simulacion)
SELECT 
  au.id as user_id,
  au.email,
  p.id as profile_id,
  p.role,
  CASE 
    WHEN p.role = 'owner' THEN 'Puede crear vehiculos'
    ELSE 'NO puede crear vehiculos (rol: ' || p.role || ')'
  END as puede_crear
FROM auth.users au
LEFT JOIN public.profiles p ON p.id = au.id
WHERE au.email = 'luisr@rastrear.com.co';
