-- ============================================
-- Script ALTERNATIVO: Mantener super_admin PERO actualizar políticas RLS
-- para que super_admin también pueda acceder a vehículos
-- ============================================
-- Esta opción permite que el usuario mantenga su rol de super_admin
-- pero también pueda acceder a vehículos como si fuera owner

-- Opción 1: Actualizar políticas RLS para incluir super_admin
-- Ejecuta primero esto para permitir que super_admin también acceda a vehículos

-- Eliminar políticas existentes
DROP POLICY IF EXISTS "Owners can read vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Owners can insert vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Owners can update vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Owners can delete vehicles" ON public.vehicles;

-- Política para lectura: permitir a usuarios con rol 'owner' o 'super_admin'
CREATE POLICY "Owners and super_admin can read vehicles"
  ON public.vehicles
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('owner', 'super_admin')
    )
  );

-- Política para inserción: permitir a usuarios con rol 'owner' o 'super_admin'
CREATE POLICY "Owners and super_admin can insert vehicles"
  ON public.vehicles
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('owner', 'super_admin')
    )
  );

-- Política para actualización: permitir a usuarios con rol 'owner' o 'super_admin'
CREATE POLICY "Owners and super_admin can update vehicles"
  ON public.vehicles
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('owner', 'super_admin')
    )
  )
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('owner', 'super_admin')
    )
  );

-- Política para eliminación: permitir a usuarios con rol 'owner' o 'super_admin'
CREATE POLICY "Owners and super_admin can delete vehicles"
  ON public.vehicles
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('owner', 'super_admin')
    )
  );

-- Verificar las políticas creadas
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

