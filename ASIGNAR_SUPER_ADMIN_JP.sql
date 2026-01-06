-- ============================================
-- Script para asignar rol super_admin a jpcuartasv@hotmail.com
-- ============================================
-- Ejecuta este script en el SQL Editor de Supabase
-- Dashboard > SQL Editor > New Query > Pega este código > Run

-- Verificar el usuario actual antes de actualizar
SELECT 
  id,
  email,
  full_name,
  role,
  created_at
FROM public.profiles
WHERE email = 'jpcuartasv@hotmail.com';

-- Asignar rol super_admin
UPDATE public.profiles
SET role = 'super_admin'
WHERE email = 'jpcuartasv@hotmail.com';

-- Verificar que se actualizó correctamente
SELECT 
  id,
  email,
  full_name,
  role,
  created_at
FROM public.profiles
WHERE email = 'jpcuartasv@hotmail.com';

-- Ver todos los super_admin para confirmar
SELECT 
  id,
  email,
  full_name,
  role,
  created_at
FROM public.profiles
WHERE role = 'super_admin'
ORDER BY created_at DESC;

