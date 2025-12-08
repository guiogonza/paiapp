-- ============================================
-- Script para crear la tabla vehicle_history
-- ============================================
-- Ejecuta este script en el SQL Editor de Supabase
-- Dashboard > SQL Editor > New Query > Pega este código > Run

-- Crear tabla para el historial de ubicaciones de vehículos
CREATE TABLE IF NOT EXISTS public.vehicle_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  vehicle_id TEXT NOT NULL,
  plate TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL,
  speed DOUBLE PRECISION,
  heading DOUBLE PRECISION,
  altitude DOUBLE PRECISION,
  valid BOOLEAN,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Crear índices para mejorar el rendimiento de las consultas
CREATE INDEX IF NOT EXISTS idx_vehicle_history_vehicle_id 
  ON public.vehicle_history(vehicle_id);

CREATE INDEX IF NOT EXISTS idx_vehicle_history_timestamp 
  ON public.vehicle_history(timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_vehicle_history_vehicle_timestamp 
  ON public.vehicle_history(vehicle_id, timestamp DESC);

-- Crear índice compuesto para búsquedas por vehículo y rango de fechas
CREATE INDEX IF NOT EXISTS idx_vehicle_history_vehicle_id_timestamp 
  ON public.vehicle_history(vehicle_id, timestamp);

-- Habilitar Row Level Security (RLS)
ALTER TABLE public.vehicle_history ENABLE ROW LEVEL SECURITY;

-- Política para permitir que usuarios autenticados lean el historial
CREATE POLICY "Users can read vehicle history"
  ON public.vehicle_history
  FOR SELECT
  USING (auth.role() = 'authenticated');

-- Política para permitir que usuarios autenticados inserten historial
CREATE POLICY "Users can insert vehicle history"
  ON public.vehicle_history
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- Política para permitir que usuarios autenticados actualicen historial (opcional)
CREATE POLICY "Users can update vehicle history"
  ON public.vehicle_history
  FOR UPDATE
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

-- Política para permitir que usuarios autenticados eliminen historial (opcional)
CREATE POLICY "Users can delete vehicle history"
  ON public.vehicle_history
  FOR DELETE
  USING (auth.role() = 'authenticated');

-- Verificar que la tabla se creó correctamente
SELECT 
  table_name, 
  column_name, 
  data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'vehicle_history'
ORDER BY ordinal_position;

