-- ============================================
-- ACTUALIZAR POLÍTICAS RLS PARA INCLUIR super_admin (Versión Segura)
-- ============================================
-- Este script actualiza las políticas RLS SIN eliminar las existentes primero
-- Solo crea las nuevas políticas si no existen
-- Dashboard > SQL Editor > New Query > Pega este código > Run

-- ============================================
-- 1. VEHICLES - Crear/Actualizar políticas
-- ============================================
-- Crear políticas solo si no existen (más seguro)
DO $$ 
BEGIN
  -- Eliminar solo si existen
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'vehicles' AND policyname = 'Owners can read vehicles') THEN
    DROP POLICY "Owners can read vehicles" ON public.vehicles;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'vehicles' AND policyname = 'Owners can insert vehicles') THEN
    DROP POLICY "Owners can insert vehicles" ON public.vehicles;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'vehicles' AND policyname = 'Owners can update vehicles') THEN
    DROP POLICY "Owners can update vehicles" ON public.vehicles;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'vehicles' AND policyname = 'Owners can delete vehicles') THEN
    DROP POLICY "Owners can delete vehicles" ON public.vehicles;
  END IF;
END $$;

-- Crear nuevas políticas (se crearán solo si no existen)
CREATE POLICY IF NOT EXISTS "Owners and super_admin can read vehicles"
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

CREATE POLICY IF NOT EXISTS "Owners and super_admin can insert vehicles"
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

CREATE POLICY IF NOT EXISTS "Owners and super_admin can update vehicles"
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

CREATE POLICY IF NOT EXISTS "Owners and super_admin can delete vehicles"
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
-- Verificar que se crearon correctamente
-- ============================================
SELECT 
  tablename,
  policyname,
  cmd
FROM pg_policies
WHERE tablename = 'vehicles'
ORDER BY policyname;

-- NOTA: Este script solo actualiza VEHICLES como ejemplo
-- Para actualizar TODAS las tablas, usa ACTUALIZAR_TODAS_POLITICAS_SUPER_ADMIN.sql
-- que es más completo pero requiere confirmar la advertencia de Supabase

