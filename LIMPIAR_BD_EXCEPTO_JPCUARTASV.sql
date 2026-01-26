-- ============================================
-- ELIMINAR TODOS LOS DATOS EXCEPTO USUARIO jpcuartasv
-- ============================================
-- ⚠️ ADVERTENCIA: Esta operación es IRREVERSIBLE
-- Copia y ejecuta en el SQL Editor de Supabase
-- Dashboard: https://supabase.com/dashboard
-- Proyecto: urlbbkpuaiugputhnsqx

-- ============================================
-- PASO 1: Identificar el ID del usuario jpcuartasv
-- ============================================
-- Ejecuta primero para verificar que existe:
SELECT id, email, full_name, role 
FROM public.profiles 
WHERE email LIKE '%jpcuartasv%' OR email LIKE '%jp%cuartas%';

-- ============================================
-- PASO 2: ELIMINAR DATOS (ejecutar después de verificar)
-- ============================================

-- 2.1 Eliminar historial de ubicaciones de vehículos
-- (No tiene FK directa con profiles, eliminar todo)
DELETE FROM public.vehicle_history;

-- 2.2 Eliminar ubicaciones de conductores que no sean jpcuartasv
DELETE FROM public.driver_locations
WHERE user_id NOT IN (
    SELECT id FROM public.profiles 
    WHERE email LIKE '%jpcuartasv%'
);

-- 2.3 Eliminar gastos de viajes que no sean de jpcuartasv
DELETE FROM public.expenses
WHERE driver_id NOT IN (
    SELECT id FROM public.profiles 
    WHERE email LIKE '%jpcuartasv%'
);

-- 2.4 Eliminar documentos que no sean creados por jpcuartasv
DELETE FROM public.documents
WHERE created_by NOT IN (
    SELECT id FROM public.profiles 
    WHERE email LIKE '%jpcuartasv%'
);

-- 2.5 Eliminar mantenimientos que no sean creados por jpcuartasv
DELETE FROM public.maintenance
WHERE created_by NOT IN (
    SELECT id FROM public.profiles 
    WHERE email LIKE '%jpcuartasv%'
);

-- 2.6 Eliminar remisiones de viajes que no sean de jpcuartasv
DELETE FROM public.remittances
WHERE user_id NOT IN (
    SELECT id FROM public.profiles 
    WHERE email LIKE '%jpcuartasv%'
);

-- 2.7 Eliminar rutas/viajes que no sean de jpcuartasv
DELETE FROM public.routes
WHERE user_id NOT IN (
    SELECT id FROM public.profiles 
    WHERE email LIKE '%jpcuartasv%'
);

-- 2.8 Eliminar vehículos que no sean de jpcuartasv
DELETE FROM public.vehicles
WHERE owner_id NOT IN (
    SELECT id FROM public.profiles 
    WHERE email LIKE '%jpcuartasv%'
);

-- 2.9 Eliminar perfiles que no sean jpcuartasv
DELETE FROM public.profiles
WHERE email NOT LIKE '%jpcuartasv%';

-- ============================================
-- PASO 3: VERIFICAR RESULTADO
-- ============================================
SELECT 'profiles' as tabla, COUNT(*) as registros FROM public.profiles
UNION ALL
SELECT 'vehicles', COUNT(*) FROM public.vehicles
UNION ALL
SELECT 'routes', COUNT(*) FROM public.routes
UNION ALL
SELECT 'remittances', COUNT(*) FROM public.remittances
UNION ALL
SELECT 'expenses', COUNT(*) FROM public.expenses
UNION ALL
SELECT 'maintenance', COUNT(*) FROM public.maintenance
UNION ALL
SELECT 'documents', COUNT(*) FROM public.documents
UNION ALL
SELECT 'vehicle_history', COUNT(*) FROM public.vehicle_history
UNION ALL
SELECT 'driver_locations', COUNT(*) FROM public.driver_locations
ORDER BY registros DESC;

-- ============================================
-- PASO 4: VERIFICAR QUE SOLO QUEDA jpcuartasv
-- ============================================
SELECT id, email, full_name, role, created_at
FROM public.profiles;

SELECT id, plate, brand, model, owner_id
FROM public.vehicles;
