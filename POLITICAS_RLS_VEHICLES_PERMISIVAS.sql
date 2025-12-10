-- Script para crear politicas RLS PERMISIVAS (temporal para diagnostico)
-- ADVERTENCIA: Estas politicas son muy permisivas, solo para diagnostico
-- Ejecuta este script SOLO si quieres permitir temporalmente a TODOS los usuarios autenticados crear vehiculos

-- Eliminar politicas existentes
DROP POLICY IF EXISTS "Owners can read vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Owners can insert vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Owners can update vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Owners can delete vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Authenticated users can read vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Authenticated users can insert vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Authenticated users can update vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Authenticated users can delete vehicles" ON public.vehicles;

-- Politicas PERMISIVAS: Cualquier usuario autenticado puede hacer todo
-- SOLO PARA DIAGNOSTICO - NO USAR EN PRODUCCION

CREATE POLICY "Authenticated users can read vehicles"
  ON public.vehicles
  FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can insert vehicles"
  ON public.vehicles
  FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can update vehicles"
  ON public.vehicles
  FOR UPDATE
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can delete vehicles"
  ON public.vehicles
  FOR DELETE
  USING (auth.uid() IS NOT NULL);

-- Verificar las politicas creadas
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd
FROM pg_policies
WHERE tablename = 'vehicles'
ORDER BY policyname;
