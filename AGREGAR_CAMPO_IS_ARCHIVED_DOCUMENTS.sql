-- Agregar campo is_archived a la tabla documents para historial de renovaciones
-- Este campo permite mantener el historial de documentos sin borrarlos

ALTER TABLE public.documents
ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT FALSE NOT NULL;

-- Comentario para documentar el campo
COMMENT ON COLUMN public.documents.is_archived IS 'Indica si el documento fue archivado (reemplazado por una renovación). Los documentos archivados se mantienen para historial pero no se muestran en la lista principal.';

-- Crear índice para mejorar las consultas de documentos activos
CREATE INDEX IF NOT EXISTS idx_documents_is_archived ON public.documents(is_archived);

-- Actualizar RLS para permitir que los owners vean documentos archivados si es necesario
-- (Las políticas existentes ya deberían funcionar, pero podemos ajustarlas si es necesario)

