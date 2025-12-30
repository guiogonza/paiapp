-- Script para asignar rol super_admin a un usuario
-- IMPORTANTE: Ejecutar en Supabase SQL Editor

-- Opción 1: Actualizar usuario existente por email
UPDATE profiles 
SET role = 'super_admin' 
WHERE email = 'jpcuartasv@pai.com';

-- Verificar que se actualizó correctamente
SELECT id, email, role, full_name 
FROM profiles 
WHERE email = 'jpcuartasv@pai.com';

-- Opción 2: Ver todos los usuarios y sus roles
SELECT id, email, role, full_name, created_at 
FROM profiles 
ORDER BY created_at DESC;

