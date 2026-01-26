-- ============================================
-- VERIFICAR DATOS EN SUPABASE
-- ============================================
-- Copia y ejecuta cada sección en el SQL Editor de Supabase
-- Dashboard: https://supabase.com/dashboard
-- Proyecto: urlbbkpuaiugputhnsqx

-- ============================================
-- 1. RESUMEN DE TODAS LAS TABLAS
-- ============================================
SELECT 
    tablename as tabla,
    (SELECT COUNT(*) FROM public.profiles WHERE tablename = 'profiles') as perfiles,
    (SELECT COUNT(*) FROM public.vehicles WHERE tablename = 'vehicles') as vehiculos
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('profiles', 'vehicles', 'routes', 'remittances', 'expenses', 'documents', 'vehicle_history', 'app_logs')
LIMIT 1;

-- ============================================
-- 2. VER USUARIOS/PERFILES
-- ============================================
SELECT 
    id,
    email,
    full_name,
    role,
    assigned_vehicle_id,
    created_at
FROM public.profiles
ORDER BY created_at DESC;

-- ============================================
-- 3. VER VEHÍCULOS
-- ============================================
SELECT 
    id,
    plate,
    brand,
    model,
    year,
    vehicle_type,
    owner_id,
    gps_device_id,
    created_at
FROM public.vehicles
ORDER BY created_at DESC;

-- ============================================
-- 4. VER RUTAS/VIAJES
-- ============================================
SELECT 
    id,
    origin,
    destination,
    start_location,
    end_location,
    status,
    driver_id,
    vehicle_id,
    created_at
FROM public.routes
ORDER BY created_at DESC
LIMIT 20;

-- ============================================
-- 5. VER REMISIONES
-- ============================================
SELECT 
    id,
    remittance_number,
    route_id,
    status,
    created_at
FROM public.remittances
ORDER BY created_at DESC
LIMIT 20;

-- ============================================
-- 6. VER GASTOS
-- ============================================
SELECT 
    id,
    trip_id,
    type,
    amount,
    date,
    description
FROM public.expenses
ORDER BY date DESC
LIMIT 20;

-- ============================================
-- 7. VER DOCUMENTOS
-- ============================================
SELECT 
    id,
    name,
    document_type,
    vehicle_id,
    expiration_date,
    is_archived
FROM public.documents
ORDER BY expiration_date ASC
LIMIT 20;

-- ============================================
-- 8. VER HISTORIAL DE VEHÍCULOS
-- ============================================
SELECT 
    id,
    vehicle_id,
    latitude,
    longitude,
    speed,
    timestamp
FROM public.vehicle_history
ORDER BY timestamp DESC
LIMIT 20;

-- ============================================
-- 9. VER LOGS DE LA APP
-- ============================================
SELECT 
    id,
    user_id,
    action,
    details,
    created_at
FROM public.app_logs
ORDER BY created_at DESC
LIMIT 20;

-- ============================================
-- 10. CONTEO RÁPIDO DE TODAS LAS TABLAS
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
SELECT 'documents', COUNT(*) FROM public.documents
UNION ALL
SELECT 'vehicle_history', COUNT(*) FROM public.vehicle_history
UNION ALL
SELECT 'app_logs', COUNT(*) FROM public.app_logs
ORDER BY registros DESC;
