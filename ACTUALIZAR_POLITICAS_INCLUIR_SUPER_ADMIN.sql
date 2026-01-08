-- ============================================
-- ACTUALIZAR POLÍTICAS RLS PARA INCLUIR super_admin
-- ============================================
-- Este script actualiza TODAS las políticas RLS para que super_admin
-- también tenga acceso a los recursos (vehículos, viajes, gastos, etc.)
-- Dashboard > SQL Editor > New Query > Pega este código > Run

-- ============================================
-- 1. VEHICLES - Actualizar políticas
-- ============================================
DROP POLICY IF EXISTS "Owners can read vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Owners can insert vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Owners can update vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Owners can delete vehicles" ON public.vehicles;

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

-- ============================================
-- 2. ROUTES (Viajes) - Actualizar políticas
-- ============================================
DROP POLICY IF EXISTS "Users can read routes" ON public.routes;
DROP POLICY IF EXISTS "Users can insert routes" ON public.routes;
DROP POLICY IF EXISTS "Users can update routes" ON public.routes;
DROP POLICY IF EXISTS "Users can delete routes" ON public.routes;

CREATE POLICY "Users and super_admin can read routes"
  ON public.routes
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = user_id OR
      EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role IN ('owner', 'super_admin')
      )
    )
  );

CREATE POLICY "Users and super_admin can insert routes"
  ON public.routes
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = user_id OR
      EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role IN ('owner', 'super_admin')
      )
    )
  );

CREATE POLICY "Users and super_admin can update routes"
  ON public.routes
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = user_id OR
      EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role IN ('owner', 'super_admin')
      )
    )
  );

CREATE POLICY "Users and super_admin can delete routes"
  ON public.routes
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = user_id OR
      EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role IN ('owner', 'super_admin')
      )
    )
  );

-- ============================================
-- 3. EXPENSES (Gastos) - Actualizar políticas
-- ============================================
DROP POLICY IF EXISTS "Users can read expenses" ON public.expenses;
DROP POLICY IF EXISTS "Users can insert expenses" ON public.expenses;
DROP POLICY IF EXISTS "Users can update expenses" ON public.expenses;
DROP POLICY IF EXISTS "Users can delete expenses" ON public.expenses;

CREATE POLICY "Users and super_admin can read expenses"
  ON public.expenses
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = driver_id OR
      EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role IN ('owner', 'super_admin')
      )
    )
  );

CREATE POLICY "Users and super_admin can insert expenses"
  ON public.expenses
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = driver_id OR
      EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role IN ('owner', 'super_admin')
      )
    )
  );

CREATE POLICY "Users and super_admin can update expenses"
  ON public.expenses
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = driver_id OR
      EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role IN ('owner', 'super_admin')
      )
    )
  );

CREATE POLICY "Users and super_admin can delete expenses"
  ON public.expenses
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = driver_id OR
      EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role IN ('owner', 'super_admin')
      )
    )
  );

-- ============================================
-- Verificar todas las políticas actualizadas
-- ============================================
SELECT 
  tablename,
  policyname,
  cmd
FROM pg_policies
WHERE tablename IN ('vehicles', 'routes', 'expenses')
ORDER BY tablename, policyname;

