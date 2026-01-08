-- ============================================
-- ACTUALIZAR TODAS LAS POLÍTICAS RLS PARA INCLUIR super_admin
-- ============================================
-- Este script actualiza TODAS las políticas RLS para que super_admin
-- tenga acceso completo como si fuera owner (vehículos, viajes, gastos, mantenimiento, etc.)
-- Dashboard > SQL Editor > New Query > Pega este código > Run

-- ============================================
-- 1. VEHICLES - Actualizar políticas
-- ============================================
DROP POLICY IF EXISTS "Owners can read vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Owners can insert vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Owners can update vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Owners can delete vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Owners and super_admin can read vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Owners and super_admin can insert vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Owners and super_admin can update vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Owners and super_admin can delete vehicles" ON public.vehicles;

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
DROP POLICY IF EXISTS "Users and super_admin can read routes" ON public.routes;
DROP POLICY IF EXISTS "Users and super_admin can insert routes" ON public.routes;
DROP POLICY IF EXISTS "Users and super_admin can update routes" ON public.routes;
DROP POLICY IF EXISTS "Users and super_admin can delete routes" ON public.routes;

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
  )
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
DROP POLICY IF EXISTS "Users and super_admin can read expenses" ON public.expenses;
DROP POLICY IF EXISTS "Users and super_admin can insert expenses" ON public.expenses;
DROP POLICY IF EXISTS "Users and super_admin can update expenses" ON public.expenses;
DROP POLICY IF EXISTS "Users and super_admin can delete expenses" ON public.expenses;

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
-- 4. MAINTENANCE (Mantenimiento) - Actualizar políticas
-- ============================================
DROP POLICY IF EXISTS "Owners can read maintenance" ON public.maintenance;
DROP POLICY IF EXISTS "Owners can insert maintenance" ON public.maintenance;
DROP POLICY IF EXISTS "Owners can update maintenance" ON public.maintenance;
DROP POLICY IF EXISTS "Owners can delete maintenance" ON public.maintenance;
DROP POLICY IF EXISTS "Users and super_admin can read maintenance" ON public.maintenance;
DROP POLICY IF EXISTS "Users and super_admin can insert maintenance" ON public.maintenance;
DROP POLICY IF EXISTS "Users and super_admin can update maintenance" ON public.maintenance;
DROP POLICY IF EXISTS "Users and super_admin can delete maintenance" ON public.maintenance;

CREATE POLICY "Users and super_admin can read maintenance"
  ON public.maintenance
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = created_by OR
      EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role IN ('owner', 'super_admin')
      )
    )
  );

CREATE POLICY "Users and super_admin can insert maintenance"
  ON public.maintenance
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = created_by OR
      EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role IN ('owner', 'super_admin')
      )
    )
  );

CREATE POLICY "Users and super_admin can update maintenance"
  ON public.maintenance
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = created_by OR
      EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role IN ('owner', 'super_admin')
      )
    )
  );

CREATE POLICY "Users and super_admin can delete maintenance"
  ON public.maintenance
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = created_by OR
      EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role IN ('owner', 'super_admin')
      )
    )
  );

-- ============================================
-- 5. DOCUMENTS - Actualizar políticas
-- ============================================
DROP POLICY IF EXISTS "Owners can view all documents" ON public.documents;
DROP POLICY IF EXISTS "Owners can insert documents" ON public.documents;
DROP POLICY IF EXISTS "Owners can update documents" ON public.documents;
DROP POLICY IF EXISTS "Owners can delete documents" ON public.documents;

CREATE POLICY "Owners and super_admin can view all documents"
  ON public.documents
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = created_by OR
      EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role IN ('owner', 'super_admin')
      )
    )
  );

CREATE POLICY "Owners and super_admin can insert documents"
  ON public.documents
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = created_by OR
      EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role IN ('owner', 'super_admin')
      )
    )
  );

CREATE POLICY "Owners and super_admin can update documents"
  ON public.documents
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = created_by OR
      EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role IN ('owner', 'super_admin')
      )
    )
  );

CREATE POLICY "Owners and super_admin can delete documents"
  ON public.documents
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = created_by OR
      EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role IN ('owner', 'super_admin')
      )
    )
  );

-- ============================================
-- 6. REMITTANCES - Actualizar políticas
-- ============================================
DROP POLICY IF EXISTS "Users can read remittances" ON public.remittances;
DROP POLICY IF EXISTS "Users can insert remittances" ON public.remittances;
DROP POLICY IF EXISTS "Users can update remittances" ON public.remittances;
DROP POLICY IF EXISTS "Users can delete remittances" ON public.remittances;

CREATE POLICY "Users and super_admin can read remittances"
  ON public.remittances
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

CREATE POLICY "Users and super_admin can insert remittances"
  ON public.remittances
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

CREATE POLICY "Users and super_admin can update remittances"
  ON public.remittances
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

CREATE POLICY "Users and super_admin can delete remittances"
  ON public.remittances
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
-- 7. PROFILES - Actualizar políticas (si existen)
-- ============================================
DROP POLICY IF EXISTS "Owners can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Owners can view driver profiles" ON public.profiles;
DROP POLICY IF EXISTS "Owners can insert profiles" ON public.profiles;
DROP POLICY IF EXISTS "Owners can update profiles" ON public.profiles;

CREATE POLICY "Owners and super_admin can view all profiles"
  ON public.profiles
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = id OR
      EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid()
        AND p.role IN ('owner', 'super_admin')
      )
    )
  );

CREATE POLICY "Owners and super_admin can view driver profiles"
  ON public.profiles
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    (
      role = 'driver' OR
      EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid()
        AND p.role IN ('owner', 'super_admin')
      )
    )
  );

CREATE POLICY "Owners and super_admin can insert profiles"
  ON public.profiles
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
      AND p.role IN ('owner', 'super_admin')
    )
  );

CREATE POLICY "Owners and super_admin can update profiles"
  ON public.profiles
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = id OR
      EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid()
        AND p.role IN ('owner', 'super_admin')
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
WHERE tablename IN ('vehicles', 'routes', 'expenses', 'maintenance', 'documents', 'remittances', 'profiles')
ORDER BY tablename, policyname;

