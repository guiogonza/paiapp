-- =====================================================
-- PAI APP - Script de Inicialización PostgreSQL
-- Base de datos local sin Supabase
-- =====================================================

-- Extensiones útiles
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- TABLA: profiles (usuarios del sistema)
-- =====================================================
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    role VARCHAR(50) NOT NULL DEFAULT 'driver',
    assigned_vehicle_id VARCHAR(100),
    phone VARCHAR(50),
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Restricción para roles válidos
    CONSTRAINT valid_role CHECK (role IN ('super_admin', 'owner', 'admin', 'driver'))
);

-- Índices para profiles
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);

-- =====================================================
-- TABLA: vehicles (vehículos)
-- =====================================================
CREATE TABLE IF NOT EXISTS vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    placa VARCHAR(20) NOT NULL,
    marca VARCHAR(100),
    modelo VARCHAR(100),
    ano INTEGER,
    color VARCHAR(50),
    tipo VARCHAR(50),
    capacidad_carga DECIMAL(10,2),
    gps_device_id VARCHAR(100),
    owner_id UUID REFERENCES profiles(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_placa UNIQUE (placa)
);

-- Índices para vehicles
CREATE INDEX IF NOT EXISTS idx_vehicles_placa ON vehicles(placa);
CREATE INDEX IF NOT EXISTS idx_vehicles_owner ON vehicles(owner_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_gps_device ON vehicles(gps_device_id);

-- =====================================================
-- TABLA: vehicle_history (historial de ubicaciones)
-- =====================================================
CREATE TABLE IF NOT EXISTS vehicle_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES profiles(id),
    latitude DECIMAL(10,8) NOT NULL,
    longitude DECIMAL(11,8) NOT NULL,
    speed DECIMAL(6,2),
    altitude DECIMAL(10,2),
    heading DECIMAL(5,2),
    accuracy DECIMAL(8,2),
    address TEXT,
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Índices para vehicle_history (particionado por fecha para mejor rendimiento)
CREATE INDEX IF NOT EXISTS idx_vh_vehicle_id ON vehicle_history(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_vh_driver_id ON vehicle_history(driver_id);
CREATE INDEX IF NOT EXISTS idx_vh_recorded_at ON vehicle_history(recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_vh_vehicle_date ON vehicle_history(vehicle_id, recorded_at DESC);

-- =====================================================
-- TABLA: documents (documentos de vehículos)
-- =====================================================
CREATE TABLE IF NOT EXISTS documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
    document_type VARCHAR(100) NOT NULL,
    document_number VARCHAR(100),
    issue_date DATE,
    expiry_date DATE,
    alert_date DATE,
    document_url TEXT,
    notes TEXT,
    is_archived BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Índices para documents
CREATE INDEX IF NOT EXISTS idx_documents_vehicle ON documents(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_documents_expiry ON documents(expiry_date);
CREATE INDEX IF NOT EXISTS idx_documents_type ON documents(document_type);

-- =====================================================
-- TABLA: trips (viajes/recorridos)
-- =====================================================
CREATE TABLE IF NOT EXISTS trips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    driver_id UUID REFERENCES profiles(id),
    start_time TIMESTAMP WITH TIME ZONE,
    end_time TIMESTAMP WITH TIME ZONE,
    start_latitude DECIMAL(10,8),
    start_longitude DECIMAL(11,8),
    end_latitude DECIMAL(10,8),
    end_longitude DECIMAL(11,8),
    start_address TEXT,
    end_address TEXT,
    distance_km DECIMAL(10,2),
    duration_minutes INTEGER,
    fuel_consumed DECIMAL(8,2),
    status VARCHAR(50) DEFAULT 'in_progress',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT valid_trip_status CHECK (status IN ('in_progress', 'completed', 'cancelled'))
);

-- Índices para trips
CREATE INDEX IF NOT EXISTS idx_trips_vehicle ON trips(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_trips_driver ON trips(driver_id);
CREATE INDEX IF NOT EXISTS idx_trips_dates ON trips(start_time, end_time);

-- =====================================================
-- TABLA: expenses (gastos)
-- =====================================================
CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_id UUID REFERENCES vehicles(id),
    trip_id UUID REFERENCES trips(id),
    driver_id UUID REFERENCES profiles(id),
    expense_type VARCHAR(100) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    currency VARCHAR(10) DEFAULT 'COP',
    description TEXT,
    receipt_url TEXT,
    expense_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Índices para expenses
CREATE INDEX IF NOT EXISTS idx_expenses_vehicle ON expenses(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_expenses_trip ON expenses(trip_id);
CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(expense_date);

-- =====================================================
-- TABLA: maintenance (mantenimientos)
-- =====================================================
CREATE TABLE IF NOT EXISTS maintenance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    maintenance_type VARCHAR(100) NOT NULL,
    description TEXT,
    cost DECIMAL(12,2),
    odometer_reading INTEGER,
    scheduled_date DATE,
    completed_date DATE,
    next_maintenance_date DATE,
    next_maintenance_km INTEGER,
    workshop_name VARCHAR(255),
    invoice_number VARCHAR(100),
    notes TEXT,
    status VARCHAR(50) DEFAULT 'scheduled',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT valid_maintenance_status CHECK (status IN ('scheduled', 'in_progress', 'completed', 'cancelled'))
);

-- Índices para maintenance
CREATE INDEX IF NOT EXISTS idx_maintenance_vehicle ON maintenance(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_dates ON maintenance(scheduled_date, completed_date);

-- =====================================================
-- TABLA: remisiones (documentos de envío)
-- =====================================================
CREATE TABLE IF NOT EXISTS remisiones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_id UUID REFERENCES vehicles(id),
    driver_id UUID REFERENCES profiles(id),
    trip_id UUID REFERENCES trips(id),
    remision_number VARCHAR(100) UNIQUE,
    origin_address TEXT,
    destination_address TEXT,
    cargo_description TEXT,
    weight_kg DECIMAL(10,2),
    client_name VARCHAR(255),
    client_phone VARCHAR(50),
    delivery_status VARCHAR(50) DEFAULT 'pending',
    signature_url TEXT,
    photo_urls JSONB,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    delivered_at TIMESTAMP WITH TIME ZONE,
    
    CONSTRAINT valid_delivery_status CHECK (delivery_status IN ('pending', 'in_transit', 'delivered', 'failed', 'cancelled'))
);

-- Índices para remisiones
CREATE INDEX IF NOT EXISTS idx_remisiones_vehicle ON remisiones(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_remisiones_driver ON remisiones(driver_id);
CREATE INDEX IF NOT EXISTS idx_remisiones_status ON remisiones(delivery_status);
CREATE INDEX IF NOT EXISTS idx_remisiones_number ON remisiones(remision_number);

-- =====================================================
-- TABLA: gps_credentials (credenciales del sistema GPS)
-- =====================================================
CREATE TABLE IF NOT EXISTS gps_credentials (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id),
    gps_email VARCHAR(255) NOT NULL,
    gps_password_encrypted TEXT NOT NULL,
    gps_api_key TEXT,
    gps_platform VARCHAR(100) DEFAULT 'sistemagps',
    is_active BOOLEAN DEFAULT true,
    last_sync_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- FUNCIONES ÚTILES
-- =====================================================

-- Función para hashear contraseñas
CREATE OR REPLACE FUNCTION hash_password(password TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN crypt(password, gen_salt('bf', 10));
END;
$$ LANGUAGE plpgsql;

-- Función para verificar contraseñas
CREATE OR REPLACE FUNCTION verify_password(password TEXT, hash TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN hash = crypt(password, hash);
END;
$$ LANGUAGE plpgsql;

-- Función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers para updated_at
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vehicles_updated_at BEFORE UPDATE ON vehicles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_documents_updated_at BEFORE UPDATE ON documents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_trips_updated_at BEFORE UPDATE ON trips
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_expenses_updated_at BEFORE UPDATE ON expenses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_maintenance_updated_at BEFORE UPDATE ON maintenance
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_remisiones_updated_at BEFORE UPDATE ON remisiones
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- DATOS INICIALES
-- =====================================================

-- Crear usuario super admin por defecto
INSERT INTO profiles (email, password_hash, full_name, role)
VALUES (
    'admin@conductor.app',
    crypt('admin123', gen_salt('bf', 10)),
    'Administrador Principal',
    'super_admin'
) ON CONFLICT (email) DO NOTHING;

-- Crear usuario owner de ejemplo
INSERT INTO profiles (email, password_hash, full_name, role)
VALUES (
    'jpcuartasv@gmail.com',
    crypt('owner123', gen_salt('bf', 10)),
    'JP Cuartas',
    'owner'
) ON CONFLICT (email) DO NOTHING;

COMMIT;
