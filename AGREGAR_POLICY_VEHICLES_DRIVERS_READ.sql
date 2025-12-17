-- ============================================
-- Política RLS adicional para que los CONDUCTORES
-- puedan leer ÚNICAMENTE su vehículo asignado.
--
-- Úsalo DESPUÉS de haber ejecutado ACTUALIZAR_POLITICAS_VEHICLES.sql
-- (que deja las políticas para owners).
--
-- Pasos:
-- 1. Abre Supabase > SQL Editor > New query
-- 2. Copia y pega este script
-- 3. Ejecuta (Run)
-- ============================================

-- Eliminar la política previa si existía con el mismo nombre
DROP POLICY IF EXISTS "Drivers can read assigned vehicle" ON public.vehicles;

-- Permitir que un usuario con rol 'driver' pueda hacer SELECT
-- sobre la fila de vehicles cuyo id coincida con profiles.assigned_vehicle_id
CREATE POLICY "Drivers can read assigned vehicle"
  ON public.vehicles
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role = 'driver'
        AND p.assigned_vehicle_id = id
    )
  );

-- Verificar que la política quedó creada
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'vehicles'
ORDER BY policyname;


