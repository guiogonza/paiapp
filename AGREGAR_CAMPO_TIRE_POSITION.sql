-- Agregar campo tire_position a la tabla maintenance para especialización de llantas
-- Este campo permite especificar la posición de la llanta (1-22) cuando el service_type es 'Llantas'

ALTER TABLE public.maintenance
ADD COLUMN IF NOT EXISTS tire_position INTEGER;

-- Comentario para documentar el campo
COMMENT ON COLUMN public.maintenance.tire_position IS 'Posición de la llanta (1-22). Solo aplica cuando service_type es ''Llantas''. NULL para otros tipos de mantenimiento.';

-- Crear índice para mejorar las consultas de alertas de llantas por posición
CREATE INDEX IF NOT EXISTS idx_maintenance_tire_position ON public.maintenance(tire_position) WHERE tire_position IS NOT NULL;

