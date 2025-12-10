-- ============================================
-- Script para crear trigger que crea remision automaticamente al crear un viaje
-- ============================================
-- Ejecuta este script en el SQL Editor de Supabase
-- Dashboard > SQL Editor > New Query > Pega este codigo > Run

-- Funcion que crea la remision automaticamente cuando se inserta un route
CREATE OR REPLACE FUNCTION public.create_remittance_on_route_insert()
RETURNS TRIGGER AS $$
BEGIN
  -- Crear una remision con status 'pendiente' cuando se crea un route
  -- NOTA: La columna FK en remittances se llama trip_id (no route_id)
  INSERT INTO public.remittances (
    trip_id,
    receiver_name,
    status,
    created_at,
    updated_at
  )
  VALUES (
    NEW.id,
    COALESCE(NEW.client_name, 'Cliente no especificado'),
    'pendiente',
    NOW(),
    NOW()
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Crear el trigger que se ejecuta despues de insertar un route
DROP TRIGGER IF EXISTS trigger_create_remittance_on_route_insert ON public.routes;

CREATE TRIGGER trigger_create_remittance_on_route_insert
  AFTER INSERT ON public.routes
  FOR EACH ROW
  EXECUTE FUNCTION public.create_remittance_on_route_insert();

-- Verificar que el trigger se creo correctamente
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement,
  action_timing
FROM information_schema.triggers
WHERE trigger_name = 'trigger_create_remittance_on_route_insert';

