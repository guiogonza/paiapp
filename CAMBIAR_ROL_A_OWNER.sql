-- ============================================
-- Script para cambiar el rol de jpcuartasv@hotmail.com a 'owner'
-- ============================================
-- Ejecuta este script en el SQL Editor de Supabase
-- Dashboard > SQL Editor > New Query > Pega este código > Run

-- Paso 1: Verificar el usuario actual
SELECT 
  id,
  email,
  role,
  full_name,
  created_at
FROM public.profiles
WHERE email = 'jpcuartasv@hotmail.com';

-- Paso 2: Cambiar el rol a 'owner'
UPDATE public.profiles
SET role = 'owner'
WHERE email = 'jpcuartasv@hotmail.com';

-- Paso 3: Verificar que se cambió correctamente
SELECT 
  id,
  email,
  role,
  full_name,
  updated_at
FROM public.profiles
WHERE email = 'jpcuartasv@hotmail.com';

-- ⚠️ NOTA: Si quieres que el usuario tenga AMBOS roles (super_admin Y owner),
-- puedes ejecutar este script alternativo en su lugar (ver CAMBIAR_ROL_MULTIPLE.sql)

