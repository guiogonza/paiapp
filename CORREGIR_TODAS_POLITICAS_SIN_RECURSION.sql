-- ============================================
-- CORREGIR TODAS LAS POLÍTICAS RLS (SIN RECURSIÓN)
-- ============================================
-- Este script corrige el error de recursión infinita en TODAS las políticas RLS
-- Incluye: profiles, vehicles, routes, expenses, maintenance, documents, remittances
-- Dashboard > SQL Editor > New Query > Pega este código > Run

-- ============================================
-- PASO 1: Crear función helper para evitar recursión
-- ============================================

-- Crear función helper que verifica el rol sin recursión
CREATE OR REPLACE FUNCTION public.is_owner_or_super_admin(user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  -- Esta función se ejecuta con privilegios elevados, evitando recursión
  RETURN EXISTS (
    SELECT 1 
    FROM public.profiles
    WHERE profiles.id = user_id
    AND profiles.role IN ('owner', 'super_admin')
  );
END;
$$;

-- Otorgar permisos de ejecución
GRANT EXECUTE ON FUNCTION public.is_owner_or_super_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_owner_or_super_admin(UUID) TO anon;

-- ============================================
-- PASO 2: CORREGIR POLÍTICAS DE PROFILES
-- ============================================

-- Eliminar políticas existentes de profiles
DROP POLICY IF EXISTS "Owners can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Owners can view driver profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Owners can insert profiles" ON public.profiles;
DROP POLICY IF EXISTS "Owners can update profiles" ON public.profiles;
DROP POLICY IF EXISTS "Owners and super_admin can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Owners and super_admin can view driver profiles" ON public.profiles;
DROP POLICY IF EXISTS "Owners and super_admin can insert profiles" ON public.profiles;
DROP POLICY IF EXISTS "Owners and super_admin can update profiles" ON public.profiles;

-- Crear políticas nuevas usando la función helper (sin recursión)
CREATE POLICY "Users can view their own profile"
  ON public.profiles
  FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "Owners and super_admin can view all profiles"
  ON public.profiles
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    public.is_owner_or_super_admin(auth.uid())
  );

CREATE POLICY "Owners and super_admin can view driver profiles"
  ON public.profiles
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    (
      role = 'driver' OR
      id = auth.uid() OR
      public.is_owner_or_super_admin(auth.uid())
    )
  );

CREATE POLICY "Owners and super_admin can insert profiles"
  ON public.profiles
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    (
      id = auth.uid() OR
      public.is_owner_or_super_admin(auth.uid())
    )
  );

CREATE POLICY "Owners and super_admin can update profiles"
  ON public.profiles
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    (
      id = auth.uid() OR
      public.is_owner_or_super_admin(auth.uid())
    )
  )
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    (
      id = auth.uid() OR
      public.is_owner_or_super_admin(auth.uid())
    )
  );

-- ============================================
-- PASO 3: CORREGIR POLÍTICAS DE VEHICLES
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
    public.is_owner_or_super_admin(auth.uid())
  );

CREATE POLICY "Owners and super_admin can insert vehicles"
  ON public.vehicles
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    public.is_owner_or_super_admin(auth.uid())
  );

CREATE POLICY "Owners and super_admin can update vehicles"
  ON public.vehicles
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    public.is_owner_or_super_admin(auth.uid())
  )
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    public.is_owner_or_super_admin(auth.uid())
  );

CREATE POLICY "Owners and super_admin can delete vehicles"
  ON public.vehicles
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL AND
    public.is_owner_or_super_admin(auth.uid())
  );

-- ============================================
-- PASO 4: CORREGIR POLÍTICAS DE ROUTES
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
      public.is_owner_or_super_admin(auth.uid())
    )
  );

CREATE POLICY "Users and super_admin can insert routes"
  ON public.routes
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = user_id OR
      public.is_owner_or_super_admin(auth.uid())
    )
  );

CREATE POLICY "Users and super_admin can update routes"
  ON public.routes
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = user_id OR
      public.is_owner_or_super_admin(auth.uid())
    )
  )
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = user_id OR
      public.is_owner_or_super_admin(auth.uid())
    )
  );

CREATE POLICY "Users and super_admin can delete routes"
  ON public.routes
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = user_id OR
      public.is_owner_or_super_admin(auth.uid())
    )
  );

-- ============================================
-- PASO 5: CORREGIR POLÍTICAS DE EXPENSES
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
      public.is_owner_or_super_admin(auth.uid())
    )
  );

CREATE POLICY "Users and super_admin can insert expenses"
  ON public.expenses
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = driver_id OR
      public.is_owner_or_super_admin(auth.uid())
    )
  );

CREATE POLICY "Users and super_admin can update expenses"
  ON public.expenses
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = driver_id OR
      public.is_owner_or_super_admin(auth.uid())
    )
  );

CREATE POLICY "Users and super_admin can delete expenses"
  ON public.expenses
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = driver_id OR
      public.is_owner_or_super_admin(auth.uid())
    )
  );

-- ============================================
-- PASO 6: CORREGIR POLÍTICAS DE MAINTENANCE
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
      public.is_owner_or_super_admin(auth.uid())
    )
  );

CREATE POLICY "Users and super_admin can insert maintenance"
  ON public.maintenance
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = created_by OR
      public.is_owner_or_super_admin(auth.uid())
    )
  );

CREATE POLICY "Users and super_admin can update maintenance"
  ON public.maintenance
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = created_by OR
      public.is_owner_or_super_admin(auth.uid())
    )
  );

CREATE POLICY "Users and super_admin can delete maintenance"
  ON public.maintenance
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = created_by OR
      public.is_owner_or_super_admin(auth.uid())
    )
  );

-- ============================================
-- PASO 7: CORREGIR POLÍTICAS DE DOCUMENTS
-- ============================================

DROP POLICY IF EXISTS "Owners can view all documents" ON public.documents;
DROP POLICY IF EXISTS "Owners can insert documents" ON public.documents;
DROP POLICY IF EXISTS "Owners can update documents" ON public.documents;
DROP POLICY IF EXISTS "Owners can delete documents" ON public.documents;
DROP POLICY IF EXISTS "Owners and super_admin can view all documents" ON public.documents;
DROP POLICY IF EXISTS "Owners and super_admin can insert documents" ON public.documents;
DROP POLICY IF EXISTS "Owners and super_admin can update documents" ON public.documents;
DROP POLICY IF EXISTS "Owners and super_admin can delete documents" ON public.documents;

CREATE POLICY "Owners and super_admin can view all documents"
  ON public.documents
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = created_by OR
      public.is_owner_or_super_admin(auth.uid())
    )
  );

CREATE POLICY "Owners and super_admin can insert documents"
  ON public.documents
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = created_by OR
      public.is_owner_or_super_admin(auth.uid())
    )
  );

CREATE POLICY "Owners and super_admin can update documents"
  ON public.documents
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = created_by OR
      public.is_owner_or_super_admin(auth.uid())
    )
  );

CREATE POLICY "Owners and super_admin can delete documents"
  ON public.documents
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = created_by OR
      public.is_owner_or_super_admin(auth.uid())
    )
  );

-- ============================================
-- PASO 8: CORREGIR POLÍTICAS DE REMITTANCES
-- ============================================

DROP POLICY IF EXISTS "Users can read remittances" ON public.remittances;
DROP POLICY IF EXISTS "Users can insert remittances" ON public.remittances;
DROP POLICY IF EXISTS "Users can update remittances" ON public.remittances;
DROP POLICY IF EXISTS "Users can delete remittances" ON public.remittances;
DROP POLICY IF EXISTS "Users and super_admin can read remittances" ON public.remittances;
DROP POLICY IF EXISTS "Users and super_admin can insert remittances" ON public.remittances;
DROP POLICY IF EXISTS "Users and super_admin can update remittances" ON public.remittances;
DROP POLICY IF EXISTS "Users and super_admin can delete remittances" ON public.remittances;

CREATE POLICY "Users and super_admin can read remittances"
  ON public.remittances
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = user_id OR
      public.is_owner_or_super_admin(auth.uid())
    )
  );

CREATE POLICY "Users and super_admin can insert remittances"
  ON public.remittances
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = user_id OR
      public.is_owner_or_super_admin(auth.uid())
    )
  );

CREATE POLICY "Users and super_admin can update remittances"
  ON public.remittances
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = user_id OR
      public.is_owner_or_super_admin(auth.uid())
    )
  );

CREATE POLICY "Users and super_admin can delete remittances"
  ON public.remittances
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL AND
    (
      auth.uid() = user_id OR
      public.is_owner_or_super_admin(auth.uid())
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

-- ============================================
-- Verificar función creada
-- ============================================
SELECT 
  routine_name,
  routine_type,
  security_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'is_owner_or_super_admin';

