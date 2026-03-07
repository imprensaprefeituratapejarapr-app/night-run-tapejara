-- =============================================
-- MIGRATION 007: PAYMENT ATTEMPTS TABLE
-- Description: Stateful payment tracking for Mercado Pago integration
-- =============================================

CREATE TABLE public.payment_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  registration_id UUID NOT NULL REFERENCES public.registrations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  provider TEXT NOT NULL DEFAULT 'mercado_pago',
  preference_id TEXT,
  payment_id TEXT,
  external_reference TEXT NOT NULL,
  lot_name TEXT NOT NULL,
  lot_price NUMERIC(10,2) NOT NULL,
  amount NUMERIC(10,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','cancelled','expired','in_process','refunded')),
  status_detail TEXT,
  init_point TEXT,
  expires_at TIMESTAMPTZ,
  approved_at TIMESTAMPTZ,
  webhook_received_at TIMESTAMPTZ,
  raw_payment_response JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_payment_attempts_registration ON public.payment_attempts(registration_id);
CREATE INDEX idx_payment_attempts_user ON public.payment_attempts(user_id);
CREATE INDEX idx_payment_attempts_external_ref ON public.payment_attempts(external_reference);
CREATE INDEX idx_payment_attempts_preference ON public.payment_attempts(preference_id);
CREATE UNIQUE INDEX idx_payment_attempts_payment_id ON public.payment_attempts(payment_id) WHERE payment_id IS NOT NULL;

CREATE TRIGGER on_payment_attempts_updated
  BEFORE UPDATE ON public.payment_attempts
  FOR EACH ROW EXECUTE FUNCTION handle_updated_at();

ALTER TABLE public.payment_attempts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own payment attempts"
  ON public.payment_attempts FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can read all payment attempts"
  ON public.payment_attempts FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );
