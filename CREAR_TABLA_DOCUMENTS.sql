-- ============================================
-- Script para crear la tabla documents
-- ============================================
-- Ejecuta este script en el SQL Editor de Supabase
-- Dashboard > SQL Editor > New Query > Pega este codigo > Run

-- Crear la tabla documents si no existe
CREATE TABLE IF NOT EXISTS public.documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE CASCADE,
  driver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL, -- Tipo de documento (ej: "Licencia", "SOAT", "Seguro", etc.)
  expiration_date DATE NOT NULL,
  document_url TEXT, -- URL de la imagen/documento en Storage
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  -- Asegurar que al menos uno de vehicle_id o driver_id esté presente
  CONSTRAINT check_association CHECK (
    (vehicle_id IS NOT NULL AND driver_id IS NULL) OR
    (vehicle_id IS NULL AND driver_id IS NOT NULL)
  )
);

-- Crear índices para mejorar el rendimiento
CREATE INDEX IF NOT EXISTS idx_documents_vehicle_id ON public.documents(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_documents_driver_id ON public.documents(driver_id);
CREATE INDEX IF NOT EXISTS idx_documents_expiration_date ON public.documents(expiration_date);

-- Crear función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION public.update_documents_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger para updated_at
DROP TRIGGER IF EXISTS trigger_update_documents_updated_at ON public.documents;
CREATE TRIGGER trigger_update_documents_updated_at
  BEFORE UPDATE ON public.documents
  FOR EACH ROW
  EXECUTE FUNCTION public.update_documents_updated_at();

-- Verificar que la tabla se creó correctamente
SELECT 
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'documents'
ORDER BY ordinal_position;

