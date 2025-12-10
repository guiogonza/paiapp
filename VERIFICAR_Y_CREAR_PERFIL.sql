-- ============================================
-- Script para verificar y crear perfil de usuario
-- ============================================
-- Ejecuta este script en el SQL Editor de Supabase
-- Dashboard > SQL Editor > New Query > Pega este código > Run

-- IMPORTANTE: Reemplaza 'EMAIL_DEL_USUARIO' con el email real (ej: 'luisr@rastrear.com.co')
-- y 'ID_DEL_USUARIO' con el UUID del usuario de auth.users

-- Paso 1: Verificar si el usuario existe en auth.users
-- (Ejecuta esto primero para obtener el ID del usuario)
SELECT 
  id,
  email,
  created_at
FROM auth.users
WHERE email = 'luisr@rastrear.com.co';  -- Cambia por el email correcto

-- Paso 2: Verificar si el perfil existe en profiles
-- (Reemplaza 'ID_DEL_USUARIO' con el ID obtenido en el Paso 1)
SELECT 
  id,
  role,
  full_name,
  created_at
FROM public.profiles
WHERE id = 'ID_DEL_USUARIO';  -- Cambia por el ID real del usuario

-- Paso 3: Si el perfil NO existe, créalo
-- (Reemplaza 'ID_DEL_USUARIO' con el ID obtenido en el Paso 1)
-- Descomenta las siguientes líneas y ejecuta:

/*
INSERT INTO public.profiles (id, role, full_name, created_at, updated_at)
VALUES (
  'ID_DEL_USUARIO',  -- Cambia por el ID real del usuario
  'owner',            -- o 'driver' según corresponda
  'Luis Rastrear',    -- Nombre completo (opcional)
  NOW(),
  NOW()
)
ON CONFLICT (id) DO UPDATE
SET 
  role = EXCLUDED.role,
  updated_at = NOW();
*/

-- Paso 4: Verificar que el perfil se creó correctamente
SELECT 
  id,
  role,
  full_name,
  created_at
FROM public.profiles
WHERE id = 'ID_DEL_USUARIO';  -- Cambia por el ID real del usuario

