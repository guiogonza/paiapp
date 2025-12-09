-- ============================================
-- Script para actualizar políticas RLS de vehicle_history
-- ============================================
-- Ejecuta este script en el SQL Editor de Supabase si tienes error 401
-- Dashboard > SQL Editor > New Query > Pega este código > Run

-- Eliminar políticas existentes (si existen)
DROP POLICY IF EXISTS "Users can read vehicle history" ON public.vehicle_history;
DROP POLICY IF EXISTS "Users can insert vehicle history" ON public.vehicle_history;
DROP POLICY IF EXISTS "Users can update vehicle history" ON public.vehicle_history;
DROP POLICY IF EXISTS "Users can delete vehicle history" ON public.vehicle_history;

-- Política más permisiva para lectura: permitir a usuarios autenticados
CREATE POLICY "Users can read vehicle history"
  ON public.vehicle_history
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL  -- Usuario autenticado
  );

-- Política más permisiva para inserción: permitir a usuarios autenticados
CREATE POLICY "Users can insert vehicle history"
  ON public.vehicle_history
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL  -- Usuario autenticado
  );

-- Política para actualización (opcional)
CREATE POLICY "Users can update vehicle history"
  ON public.vehicle_history
  FOR UPDATE
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

-- Política para eliminación (opcional)
CREATE POLICY "Users can delete vehicle history"
  ON public.vehicle_history
  FOR DELETE
  USING (auth.uid() IS NOT NULL);

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
WHERE tablename = 'vehicle_history';

