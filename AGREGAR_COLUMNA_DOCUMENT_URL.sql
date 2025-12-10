-- ============================================
-- Script para agregar columna document_url a la tabla remittances
-- ============================================
-- Ejecuta este script en el SQL Editor de Supabase
-- Dashboard > SQL Editor > New Query > Pega este codigo > Run

-- Agregar columna document_url si no existe
ALTER TABLE public.remittances
ADD COLUMN IF NOT EXISTS document_url TEXT;

-- Verificar que la columna se creo correctamente
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'remittances'
  AND column_name = 'document_url';

