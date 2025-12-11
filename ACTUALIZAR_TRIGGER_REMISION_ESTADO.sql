-- ============================================
-- Script para actualizar el trigger de remisión automática
-- Cambia el estado inicial de 'pendiente' a 'pendiente_completar'
-- ============================================
-- Ejecuta este script en el SQL Editor de Supabase
-- Dashboard > SQL Editor > New Query > Pega este codigo > Run

-- Actualizar la funcion que crea la remision automaticamente
CREATE OR REPLACE FUNCTION public.create_remittance_on_route_insert()
RETURNS TRIGGER AS $$
BEGIN
  -- Crear una remision con status 'pendiente_completar' cuando se crea un route
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
    'pendiente_completar', -- CRÍTICO: Estado inicial correcto
    NOW(),
    NOW()
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- El trigger ya existe, solo se actualiza la función
-- Verificar que el trigger sigue activo
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement,
  action_timing
FROM information_schema.triggers
WHERE trigger_name = 'trigger_create_remittance_on_route_insert';

