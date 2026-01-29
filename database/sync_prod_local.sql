-- =====================================================
-- Script de sincronización BD Local <-> Producción
-- Fecha: 29 de enero de 2026
-- =====================================================

-- Este script asegura que ambas bases de datos tengan
-- la misma estructura de tablas y columnas

-- 1. Agregar columna driver_id a documents si no existe
ALTER TABLE documents 
ADD COLUMN IF NOT EXISTS driver_id UUID REFERENCES profiles(id) ON DELETE CASCADE;

-- 2. Crear tabla user_settings si no existe
CREATE TABLE IF NOT EXISTS user_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    setting_key VARCHAR(100) NOT NULL,
    setting_value TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT user_settings_user_id_setting_key_key UNIQUE (user_id, setting_key)
);

-- 3. Asegurar que maintenance tenga todas las columnas necesarias
ALTER TABLE maintenance 
ADD COLUMN IF NOT EXISTS service_date DATE,
ADD COLUMN IF NOT EXISTS km_at_service DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS alert_date DATE,
ADD COLUMN IF NOT EXISTS custom_service_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS tire_position VARCHAR(100),
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES profiles(id),
ADD COLUMN IF NOT EXISTS provider_name VARCHAR(255);

-- 4. Crear índices faltantes
CREATE INDEX IF NOT EXISTS idx_maintenance_service_date ON maintenance(service_date);
CREATE INDEX IF NOT EXISTS idx_maintenance_alert_date ON maintenance(alert_date);
CREATE INDEX IF NOT EXISTS idx_maintenance_created_by ON maintenance(created_by);

-- Verificación final
SELECT 'Sincronización completada exitosamente' as status;
