-- =============================================
-- MIGRATION 002: CREATE REGISTRATIONS TABLE
-- Version: 20260303204138
-- Description: Registrations table for athlete inscriptions
-- =============================================

-- Create registrations table
CREATE TABLE public.registrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  registration_number SERIAL NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending_payment' CHECK (status IN ('pending_payment', 'awaiting_approval', 'confirmed', 'rejected', 'cancelled')),
  modality TEXT NOT NULL DEFAULT '5km',
  category TEXT,
  amount NUMERIC(10,2) NOT NULL DEFAULT 60.00,
  payment_link TEXT,
  admin_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  confirmed_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id)
);

-- Indexes
CREATE INDEX idx_registrations_user ON public.registrations(user_id);
CREATE INDEX idx_registrations_status ON public.registrations(status);

-- Enable RLS
ALTER TABLE public.registrations ENABLE ROW LEVEL SECURITY;

-- Auto updated_at trigger (reuses function from migration 001)
CREATE TRIGGER on_registrations_updated
  BEFORE UPDATE ON public.registrations
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- Auto-create registration when profile is created (athletes only)
CREATE OR REPLACE FUNCTION public.handle_new_registration()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.role = 'athlete' THEN
    INSERT INTO public.registrations (user_id, status, modality, amount)
    VALUES (NEW.id, 'pending_payment', '5km', 60.00);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;

CREATE TRIGGER on_profile_created
  AFTER INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_registration();
