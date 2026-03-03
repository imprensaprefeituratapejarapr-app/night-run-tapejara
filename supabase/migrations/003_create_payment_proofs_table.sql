-- =============================================
-- MIGRATION 003: CREATE PAYMENT PROOFS TABLE
-- Version: 20260303204140
-- Description: Payment proofs uploaded by athletes
-- =============================================

-- Create payment_proofs table
CREATE TABLE public.payment_proofs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  registration_id UUID NOT NULL REFERENCES public.registrations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  file_url TEXT NOT NULL,
  file_name TEXT,
  file_type TEXT,
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_payment_proofs_registration ON public.payment_proofs(registration_id);
CREATE INDEX idx_payment_proofs_user ON public.payment_proofs(user_id);

-- Enable RLS
ALTER TABLE public.payment_proofs ENABLE ROW LEVEL SECURITY;
