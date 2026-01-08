-- ============================================
-- CORREGIR POLÍTICAS RLS DE PROFILES (SIN RECURSIÓN)
-- ============================================
-- Este script corrige el error de recursión infinita en las políticas de profiles
-- Dashboard > SQL Editor > New Query > Pega este código > Run

-- ============================================
-- SOLUCIÓN: Usar función SECURITY DEFINER para evitar recursión
-- ============================================

-- Paso 1: Crear función helper que verifica el rol sin recursión
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

-- Paso 2: Eliminar todas las políticas existentes de profiles
DROP POLICY IF EXISTS "Owners can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Owners can view driver profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Owners can insert profiles" ON public.profiles;
DROP POLICY IF EXISTS "Owners can update profiles" ON public.profiles;
DROP POLICY IF EXISTS "Owners and super_admin can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Owners and super_admin can view driver profiles" ON public.profiles;
DROP POLICY IF EXISTS "Owners and super_admin can insert profiles" ON public.profiles;
DROP POLICY IF EXISTS "Owners and super_admin can update profiles" ON public.profiles;

-- Paso 3: Crear políticas nuevas usando la función helper (sin recursión)
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

-- Paso 4: Otorgar permisos de ejecución a la función
GRANT EXECUTE ON FUNCTION public.is_owner_or_super_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_owner_or_super_admin(UUID) TO anon;

-- ============================================
-- Verificar políticas creadas
-- ============================================
SELECT 
  schemaname,
  tablename,
  policyname,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY policyname;

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

