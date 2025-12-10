-- ============================================
-- Script para crear perfil de usuario automáticamente
-- ============================================
-- Ejecuta este script en el SQL Editor de Supabase
-- Dashboard > SQL Editor > New Query > Pega este código > Run
-- IMPORTANTE: Cambia 'luisr@rastrear.com.co' por el email correcto

-- Crear perfil para el usuario si no existe
-- Este script busca el usuario por email y crea su perfil con rol 'owner'
INSERT INTO public.profiles (id, role, full_name, created_at, updated_at)
SELECT 
  au.id,
  'owner' as role,  -- Cambia a 'driver' si es necesario
  COALESCE(au.raw_user_meta_data->>'full_name', 'Usuario') as full_name,
  NOW() as created_at,
  NOW() as updated_at
FROM auth.users au
WHERE au.email = 'luisr@rastrear.com.co'  -- ⚠️ CAMBIA ESTE EMAIL
  AND NOT EXISTS (
    SELECT 1 FROM public.profiles p 
    WHERE p.id = au.id
  )
ON CONFLICT (id) DO UPDATE
SET 
  role = EXCLUDED.role,
  updated_at = NOW();

-- Verificar que se creó correctamente
SELECT 
  p.id,
  p.role,
  p.full_name,
  au.email,
  p.created_at
FROM public.profiles p
JOIN auth.users au ON au.id = p.id
WHERE au.email = 'luisr@rastrear.com.co';  -- ⚠️ CAMBIA ESTE EMAIL

