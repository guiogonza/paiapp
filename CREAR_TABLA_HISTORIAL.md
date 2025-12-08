# Crear Tabla de Historial de Vehículos en Supabase

Para guardar el historial de ubicaciones de los vehículos, necesitas crear la siguiente tabla en Supabase.

## 📋 Pasos para crear la tabla

1. Ve a tu proyecto en Supabase: https://supabase.com/dashboard
2. En el menú lateral, haz clic en **SQL Editor**
3. Haz clic en **New Query**
4. Copia y pega el SQL del archivo `CREAR_TABLA_VEHICLE_HISTORY.sql` (o el código de abajo)
5. Haz clic en **Run** o presiona `Ctrl+Enter` (o `Cmd+Enter` en Mac)
6. Verifica que aparezca el mensaje "Success. No rows returned"

## SQL para crear la tabla

```sql
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
```

## ✅ Verificar que la tabla se creó

Después de ejecutar el SQL, puedes verificar que la tabla existe:

1. Ve a **Table Editor** en el menú lateral de Supabase
2. Deberías ver la tabla `vehicle_history` en la lista
3. O ejecuta este SQL para verificar:

```sql
SELECT 
  table_name, 
  column_name, 
  data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'vehicle_history'
ORDER BY ordinal_position;
```

## Estructura de la tabla

- **id**: UUID único para cada registro
- **vehicle_id**: ID del vehículo (del API de GPS)
- **plate**: Placa del vehículo
- **lat**: Latitud
- **lng**: Longitud
- **timestamp**: Fecha y hora de la ubicación
- **speed**: Velocidad en km/h (opcional)
- **heading**: Dirección en grados (opcional)
- **altitude**: Altitud en metros (opcional)
- **valid**: Si la ubicación es válida (opcional)
- **created_at**: Fecha de creación del registro en la BD

## Notas

- Los índices mejoran significativamente el rendimiento de las consultas por vehículo y por rango de fechas
- La política RLS asegura que solo usuarios autenticados puedan leer y escribir el historial
- El historial se guarda automáticamente cuando se cargan los vehículos en el dashboard

