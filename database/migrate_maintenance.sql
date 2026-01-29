-- Migración para actualizar la tabla maintenance
-- Agrega las columnas necesarias para compatibilidad con el código actual

-- Agregar columnas nuevas
ALTER TABLE maintenance 
ADD COLUMN IF NOT EXISTS service_date DATE,
ADD COLUMN IF NOT EXISTS km_at_service DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS alert_date DATE,
ADD COLUMN IF NOT EXISTS custom_service_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS tire_position VARCHAR(100),
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES profiles(id),
ADD COLUMN IF NOT EXISTS provider_name VARCHAR(255);

-- Crear índices para las nuevas columnas
CREATE INDEX IF NOT EXISTS idx_maintenance_service_date ON maintenance(service_date);
CREATE INDEX IF NOT EXISTS idx_maintenance_alert_date ON maintenance(alert_date);
CREATE INDEX IF NOT EXISTS idx_maintenance_created_by ON maintenance(created_by);

-- Comentarios para documentar las columnas
COMMENT ON COLUMN maintenance.service_date IS 'Fecha en que se realizó el servicio de mantenimiento';
COMMENT ON COLUMN maintenance.km_at_service IS 'Kilometraje del vehículo al momento del servicio';
COMMENT ON COLUMN maintenance.alert_date IS 'Fecha de alerta para el próximo mantenimiento';
COMMENT ON COLUMN maintenance.custom_service_name IS 'Nombre personalizado del servicio (para servicios tipo "Otro")';
COMMENT ON COLUMN maintenance.tire_position IS 'Posición de las llantas (para servicios de llantas)';
COMMENT ON COLUMN maintenance.created_by IS 'ID del usuario que registró el mantenimiento';
COMMENT ON COLUMN maintenance.provider_name IS 'Nombre del proveedor o taller que realizó el servicio';
