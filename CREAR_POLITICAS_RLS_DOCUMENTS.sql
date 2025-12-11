-- ============================================
-- Script para crear políticas RLS para la tabla documents
-- Solo los owners pueden interactuar con documentos
-- ============================================
-- Ejecuta este script en el SQL Editor de Supabase
-- Dashboard > SQL Editor > New Query > Pega este codigo > Run

-- Habilitar RLS en la tabla documents
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;

-- Eliminar políticas existentes si las hay
DROP POLICY IF EXISTS "Owners can view all documents" ON public.documents;
DROP POLICY IF EXISTS "Owners can insert documents" ON public.documents;
DROP POLICY IF EXISTS "Owners can update documents" ON public.documents;
DROP POLICY IF EXISTS "Owners can delete documents" ON public.documents;

-- Política para SELECT: Owners pueden ver todos los documentos
CREATE POLICY "Owners can view all documents"
ON public.documents
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'owner'
  )
);

-- Política para INSERT: Owners pueden crear documentos
CREATE POLICY "Owners can insert documents"
ON public.documents
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'owner'
  )
);

-- Política para UPDATE: Owners pueden actualizar documentos
CREATE POLICY "Owners can update documents"
ON public.documents
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

-- Política para DELETE: Owners pueden eliminar documentos
CREATE POLICY "Owners can delete documents"
ON public.documents
FOR DELETE
TO authenticated
USING (
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
WHERE tablename = 'documents';

