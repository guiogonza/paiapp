-- ============================================
-- Script para crear políticas RLS para la tabla profiles
-- Permite que los owners puedan leer perfiles de drivers
-- ============================================
-- Ejecuta este script en el SQL Editor de Supabase
-- Dashboard > SQL Editor > New Query > Pega este codigo > Run

-- Habilitar RLS en la tabla profiles si no está habilitado
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Eliminar políticas existentes si las hay
DROP POLICY IF EXISTS "Owners can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Owners can view driver profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Owners can insert profiles" ON public.profiles;
DROP POLICY IF EXISTS "Owners can update profiles" ON public.profiles;

-- Política para SELECT: Owners pueden ver todos los perfiles (necesario para lista de conductores)
CREATE POLICY "Owners can view all profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'owner'
  )
);

-- Política alternativa más específica: Owners pueden ver perfiles de drivers
CREATE POLICY "Owners can view driver profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  -- Permitir si el usuario es owner
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'owner'
  )
  OR
  -- O si el perfil es del usuario actual
  profiles.id = auth.uid()
);

-- Política para que usuarios vean su propio perfil
CREATE POLICY "Users can view their own profile"
ON public.profiles
FOR SELECT
TO authenticated
USING (profiles.id = auth.uid());

-- Política para INSERT: Owners pueden crear perfiles
CREATE POLICY "Owners can insert profiles"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'owner'
  )
);

-- Política para UPDATE: Owners pueden actualizar perfiles
CREATE POLICY "Owners can update profiles"
ON public.profiles
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'owner'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'owner'
  )
);

-- Verificar que las políticas se crearon correctamente
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
WHERE tablename = 'profiles'
ORDER BY policyname;

