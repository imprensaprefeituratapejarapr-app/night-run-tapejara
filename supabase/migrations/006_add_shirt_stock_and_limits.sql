-- =============================================
-- MIGRATION 006: SHIRT STOCK CONTROL + REGISTRATION LIMITS
-- Version: 20260306135300
-- Description: Add stock control per shirt size (400 total)
-- Sizes: PP=20, P=65, M=110, G=120, GG=65, XGG=20
-- =============================================

-- 1. Update shirt_size constraint: rename EG → XGG
ALTER TABLE public.profiles DROP CONSTRAINT profiles_shirt_size_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_shirt_size_check
  CHECK (shirt_size IN ('PP', 'P', 'M', 'G', 'GG', 'XGG'));

-- Update any existing EG values to XGG
UPDATE public.profiles SET shirt_size = 'XGG' WHERE shirt_size = 'EG';

-- 2. Create shirt_stock table
CREATE TABLE public.shirt_stock (
  size TEXT PRIMARY KEY CHECK (size IN ('PP', 'P', 'M', 'G', 'GG', 'XGG')),
  max_quantity INT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Insert stock limits
INSERT INTO public.shirt_stock (size, max_quantity) VALUES
  ('PP', 20),
  ('P', 65),
  ('M', 110),
  ('G', 120),
  ('GG', 65),
  ('XGG', 20);

-- Enable RLS on shirt_stock (read-only for everyone)
ALTER TABLE public.shirt_stock ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read shirt stock"
  ON public.shirt_stock FOR SELECT
  USING (true);

-- 3. Function: get_shirt_availability()
CREATE OR REPLACE FUNCTION public.get_shirt_availability()
RETURNS TABLE (size TEXT, max_quantity INT, used INT, available INT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    s.size,
    s.max_quantity,
    COALESCE(COUNT(p.id), 0)::INT AS used,
    (s.max_quantity - COALESCE(COUNT(p.id), 0))::INT AS available
  FROM shirt_stock s
  LEFT JOIN profiles p ON p.shirt_size = s.size
    AND EXISTS (
      SELECT 1 FROM registrations r 
      WHERE r.user_id = p.id 
      AND r.status NOT IN ('cancelled', 'rejected')
    )
  GROUP BY s.size, s.max_quantity
  ORDER BY ARRAY_POSITION(ARRAY['PP','P','M','G','GG','XGG'], s.size);
$$;

-- 4. Function: get_registration_count()
CREATE OR REPLACE FUNCTION public.get_registration_count()
RETURNS INT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COUNT(*)::INT 
  FROM registrations 
  WHERE status NOT IN ('cancelled', 'rejected');
$$;

-- 5. Grant execute permissions
GRANT EXECUTE ON FUNCTION public.get_shirt_availability() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_registration_count() TO anon, authenticated;
