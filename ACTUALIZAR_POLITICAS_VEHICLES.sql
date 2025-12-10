-- ============================================
-- Script para actualizar políticas RLS de vehicles
-- ============================================
-- Ejecuta este script en el SQL Editor de Supabase si tienes error 401 al crear/editar vehículos
-- Dashboard > SQL Editor > New Query > Pega este código > Run

-- Eliminar políticas existentes (si existen)
DROP POLICY IF EXISTS "Owners can read vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Owners can insert vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Owners can update vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Owners can delete vehicles" ON public.vehicles;

-- Política para lectura: permitir a usuarios autenticados con rol 'owner'
CREATE POLICY "Owners can read vehicles"
  ON public.vehicles
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'owner'
    )
  );

-- Política para inserción: permitir a usuarios autenticados con rol 'owner'
CREATE POLICY "Owners can insert vehicles"
  ON public.vehicles
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'owner'
    )
  );

-- Política para actualización: permitir a usuarios autenticados con rol 'owner'
CREATE POLICY "Owners can update vehicles"
  ON public.vehicles
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'owner'
    )
  )
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'owner'
    )
  );

-- Política para eliminación: permitir a usuarios autenticados con rol 'owner'
CREATE POLICY "Owners can delete vehicles"
  ON public.vehicles
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'owner'
    )
  );

-- Verificar las políticas creadas
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'vehicles'
ORDER BY policyname;

