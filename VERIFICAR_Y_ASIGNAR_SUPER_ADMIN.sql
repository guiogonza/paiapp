-- Script para verificar y asignar rol super_admin
-- IMPORTANTE: Ejecutar en Supabase SQL Editor

-- ============================================
-- PASO 1: Ver TODOS los usuarios en profiles
-- ============================================
-- Esto te mostrará todos los emails que existen en la base de datos
SELECT id, email, role, full_name, created_at 
FROM profiles 
ORDER BY created_at DESC;

-- ============================================
-- PASO 2: Buscar por email (case-insensitive)
-- ============================================
-- Si el email existe pero con mayúsculas/minúsculas diferentes
SELECT id, email, role, full_name 
FROM profiles 
WHERE LOWER(email) = LOWER('jpcuartasv@pai.com');

-- ============================================
-- PASO 3: Si NO existe el perfil, crearlo
-- ============================================
-- Primero necesitas el ID del usuario de auth.users
-- Ve a Authentication > Users en Supabase y busca el ID del usuario jpcuartasv@pai.com
-- Luego ejecuta esto (reemplaza 'USER_ID_FROM_AUTH' con el UUID real):

-- INSERT INTO profiles (id, email, role, full_name)
-- VALUES (
--   'USER_ID_FROM_AUTH',  -- Reemplaza con el UUID de auth.users
--   'jpcuartasv@pai.com',
--   'super_admin',
--   'Super Admin'
-- )
-- ON CONFLICT (id) DO UPDATE 
-- SET role = 'super_admin';

-- ============================================
-- PASO 4: Si SÍ existe, actualizar el rol
-- ============================================
-- Opción A: Por email (si encontraste el email correcto en el Paso 1)
UPDATE profiles 
SET role = 'super_admin' 
WHERE LOWER(email) = LOWER('jpcuartasv@pai.com');

-- Opción B: Por ID (si conoces el UUID del usuario)
-- UPDATE profiles 
-- SET role = 'super_admin' 
-- WHERE id = 'USER_ID_UUID';  -- Reemplaza con el UUID real

-- ============================================
-- PASO 5: Verificar que se actualizó correctamente
-- ============================================
SELECT id, email, role, full_name 
FROM profiles 
WHERE role = 'super_admin';

-- ============================================
-- PASO 6: Verificar usuarios en auth.users
-- ============================================
-- Para encontrar el ID del usuario en auth.users
SELECT id, email, created_at 
FROM auth.users 
WHERE email = 'jpcuartasv@pai.com'
ORDER BY created_at DESC;

