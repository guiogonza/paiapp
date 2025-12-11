-- ============================================
-- Función SQL para obtener conductores con email desde auth.users
-- ============================================
-- Ejecuta este script en el SQL Editor de Supabase
-- Dashboard > SQL Editor > New Query > Pega este codigo > Run

-- Crear función que hace JOIN entre profiles y auth.users
CREATE OR REPLACE FUNCTION public.get_drivers_with_email()
RETURNS TABLE (
  id UUID,
  email TEXT,
  full_name TEXT,
  role TEXT,
  created_at TIMESTAMPTZ
) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    au.email::TEXT,
    p.full_name,
    p.role,
    p.created_at
  FROM public.profiles p
  INNER JOIN auth.users au ON p.id = au.id
  WHERE p.role = 'driver'
  ORDER BY au.email ASC;
END;
$$;

-- Otorgar permisos de ejecución a usuarios autenticados
GRANT EXECUTE ON FUNCTION public.get_drivers_with_email() TO authenticated;

-- Comentario de la función
COMMENT ON FUNCTION public.get_drivers_with_email() IS 
'Retorna la lista de conductores (drivers) con su email desde auth.users. Requiere autenticación.';

