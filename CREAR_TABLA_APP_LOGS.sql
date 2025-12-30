-- Tabla para logging de acciones de usuarios (Analítica MVP)
-- Script proporcionado por el arquitecto
-- Solo accesible por super_admin para lectura

-- 1. Crear la tabla de logs
CREATE TABLE IF NOT EXISTS public.app_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    action TEXT NOT NULL,
    details TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Habilitar seguridad
ALTER TABLE public.app_logs ENABLE ROW LEVEL SECURITY;

-- 3. Regla: Cualquiera puede ESCRIBIR su log (cuando usa la app)
CREATE POLICY "Users can insert their own logs" 
ON public.app_logs FOR INSERT 
WITH CHECK (auth.uid() = user_id);

-- 4. Regla: Solo TÚ (Super Admin) puedes LEER todos los logs (para las métricas)
CREATE POLICY "Super Admin can view all logs" 
ON public.app_logs FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'super_admin'
  )
);

-- Índices para consultas rápidas (opcional pero recomendado)
CREATE INDEX IF NOT EXISTS idx_app_logs_user_id ON public.app_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_app_logs_action ON public.app_logs(action);
CREATE INDEX IF NOT EXISTS idx_app_logs_created_at ON public.app_logs(created_at DESC);

-- Comentarios
COMMENT ON TABLE public.app_logs IS 'Tabla de logging para analítica y monitoreo del MVP';
COMMENT ON COLUMN public.app_logs.action IS 'Nombre de la acción realizada (ej: login, create_trip, add_expense)';
COMMENT ON COLUMN public.app_logs.details IS 'Detalles opcionales de la acción (JSON string o texto descriptivo)';

