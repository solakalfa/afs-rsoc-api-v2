ALTER TABLE public.conversions ADD COLUMN IF NOT EXISTS conversion_id TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS conversions_conversion_id_key ON public.conversions (conversion_id);
