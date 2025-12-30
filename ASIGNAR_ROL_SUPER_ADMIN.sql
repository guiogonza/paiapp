-- Script para asignar el rol 'super_admin' a un usuario
-- IMPORTANTE: Solo ejecutar para usuarios de confianza

-- Opción 1: Actualizar por email
UPDATE profiles 
SET role = 'super_admin' 
WHERE email = 'jpcuartasv@pai.com';

-- Opción 2: Actualizar por ID de usuario (si conoces el UUID)
-- UPDATE profiles 
-- SET role = 'super_admin' 
-- WHERE id = '9314cf29-512f-4c53-9601-d67da952b597';

-- Verificar que se actualizó correctamente
SELECT id, email, role, full_name 
FROM profiles 
WHERE email = 'jpcuartasv@pai.com';

-- NOTA: Después de ejecutar este script, el usuario debe:
-- 1. Cerrar sesión
-- 2. Volver a iniciar sesión
-- 3. El botón de Super Admin aparecerá en el AppBar (icono de seguridad rojo)

