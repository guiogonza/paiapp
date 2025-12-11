-- ============================================
-- Script para actualizar el role de pepe@pai.com a 'driver'
-- ============================================
-- Ejecuta este script en el SQL Editor de Supabase
-- Dashboard > SQL Editor > New Query > Pega este codigo > Run

-- Actualizar el role de pepe@pai.com a 'driver'
UPDATE public.profiles
SET role = 'driver'
WHERE email = 'pepe@pai.com';

-- Verificar que se actualizó correctamente
SELECT 
  id,
  email,
  full_name,
  role,
  created_at
FROM public.profiles
WHERE email = 'pepe@pai.com';

