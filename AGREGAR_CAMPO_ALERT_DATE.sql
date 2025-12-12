-- Agregar campo alert_date a la tabla maintenance para almacenar fecha de alerta
-- Este campo se usa para alertas de mantenimiento preventivo

ALTER TABLE public.maintenance
ADD COLUMN IF NOT EXISTS alert_date DATE;

-- Comentario para documentar el campo
COMMENT ON COLUMN public.maintenance.alert_date IS 'Fecha estimada para alerta de próximo mantenimiento. Se calcula automáticamente según reglas o se define manualmente para servicios personalizados.';

-- Agregar campo custom_service_name para servicios personalizados (tipo "Otro")
ALTER TABLE public.maintenance
ADD COLUMN IF NOT EXISTS custom_service_name TEXT;

-- Comentario para documentar el campo
COMMENT ON COLUMN public.maintenance.custom_service_name IS 'Nombre del servicio personalizado cuando service_type es "Otro".';

