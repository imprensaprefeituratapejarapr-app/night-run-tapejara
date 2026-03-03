-- =============================================
-- NIGHT RUN TAPEJARA — FULL DATABASE MIGRATION
-- =============================================
-- Este arquivo contém TODAS as migrações combinadas em ordem.
-- Execute este arquivo em um banco Supabase limpo para recriar
-- toda a estrutura do banco de dados.
--
-- Projeto: 2ª Night Run Tapejara
-- Supabase Project ID: agkvkcpaaaimwhhopfpl
-- Região: sa-east-1 (São Paulo)
-- Data de criação: 2026-03-03
-- =============================================


-- =================================================================
-- 1. FUNÇÕES UTILITÁRIAS
-- =================================================================

-- Função para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
SET search_path = public;

-- Função para criar perfil automaticamente ao criar conta (auth.users)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, phone, cpf, birth_date, city, state, shirt_size)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'phone', NULL),
    COALESCE(NEW.raw_user_meta_data->>'cpf', NULL),
    CASE 
      WHEN NEW.raw_user_meta_data->>'birth_date' IS NOT NULL 
      THEN (NEW.raw_user_meta_data->>'birth_date')::DATE 
      ELSE NULL 
    END,
    COALESCE(NEW.raw_user_meta_data->>'city', NULL),
    COALESCE(NEW.raw_user_meta_data->>'state', 'PR'),
    COALESCE(NEW.raw_user_meta_data->>'shirt_size', NULL)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;

-- Função para criar inscrição automaticamente ao criar perfil
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


-- =================================================================
-- 2. TABELAS
-- =================================================================

-- ---- PROFILES ----
-- Estende auth.users com dados do atleta
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  cpf TEXT UNIQUE,
  birth_date DATE,
  city TEXT,
  state TEXT DEFAULT 'PR',
  shirt_size TEXT CHECK (shirt_size IN ('PP', 'P', 'M', 'G', 'GG', 'EG')),
  role TEXT NOT NULL DEFAULT 'athlete' CHECK (role IN ('athlete', 'admin')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_profiles_role ON public.profiles(role);
CREATE INDEX idx_profiles_city ON public.profiles(city);
CREATE INDEX idx_profiles_cpf ON public.profiles(cpf);

-- ---- REGISTRATIONS ----
-- Inscrições dos atletas no evento
CREATE TABLE public.registrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  registration_number SERIAL NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending_payment' 
    CHECK (status IN ('pending_payment', 'awaiting_approval', 'confirmed', 'rejected', 'cancelled')),
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

CREATE INDEX idx_registrations_user ON public.registrations(user_id);
CREATE INDEX idx_registrations_status ON public.registrations(status);

-- ---- PAYMENT PROOFS ----
-- Comprovantes de pagamento enviados pelos atletas
CREATE TABLE public.payment_proofs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  registration_id UUID NOT NULL REFERENCES public.registrations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  file_url TEXT NOT NULL,
  file_name TEXT,
  file_type TEXT,
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_payment_proofs_registration ON public.payment_proofs(registration_id);
CREATE INDEX idx_payment_proofs_user ON public.payment_proofs(user_id);


-- =================================================================
-- 3. RLS (ROW LEVEL SECURITY)
-- =================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_proofs ENABLE ROW LEVEL SECURITY;

-- ---- PROFILES POLICIES ----

-- Create a security definer function to avoid infinite recursion on role checks
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
  );
$$;

CREATE POLICY "Users can read own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id AND role = 'athlete');

CREATE POLICY "Admins can read all profiles"
  ON public.profiles FOR SELECT
  USING (public.is_admin());

CREATE POLICY "Admins can update all profiles"
  ON public.profiles FOR UPDATE
  USING (public.is_admin());

-- ---- REGISTRATIONS POLICIES ----
CREATE POLICY "Users can read own registration"
  ON public.registrations FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can read all registrations"
  ON public.registrations FOR SELECT
  USING (public.is_admin());

CREATE POLICY "Admins can update registrations"
  ON public.registrations FOR UPDATE
  USING (public.is_admin());

-- ---- PAYMENT PROOFS POLICIES ----
CREATE POLICY "Users can read own payment proofs"
  ON public.payment_proofs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own payment proofs"
  ON public.payment_proofs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can read all payment proofs"
  ON public.payment_proofs FOR SELECT
  USING (public.is_admin());


-- =================================================================
-- 4. TRIGGERS
-- =================================================================

-- Auto-update updated_at em profiles
CREATE TRIGGER on_profiles_updated
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- Auto-update updated_at em registrations
CREATE TRIGGER on_registrations_updated
  BEFORE UPDATE ON public.registrations
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- Auto-criar perfil quando conta é criada (auth.users → profiles)
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Auto-criar inscrição quando perfil é criado (profiles → registrations)
CREATE TRIGGER on_profile_created
  AFTER INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_registration();


-- =================================================================
-- 5. STORAGE (BUCKETS)
-- =================================================================

-- Bucket privado para comprovantes de pagamento
-- Limite: 5MB por arquivo
-- Formatos: JPG, PNG, WebP, PDF
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'payment-proofs',
  'payment-proofs',
  false,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
);

-- Storage: atleta faz upload na pasta {user_id}/
CREATE POLICY "Athletes can upload payment proofs"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'payment-proofs' 
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Storage: atleta lê seus próprios arquivos
CREATE POLICY "Athletes can read own payment proofs"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'payment-proofs' 
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Storage: admin lê todos os arquivos
CREATE POLICY "Admins can read all payment proofs"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'payment-proofs'
    AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );


-- =================================================================
-- 6. QUERIES ÚTEIS (NÃO RODAR COMO MIGRATION)
-- =================================================================

-- Promover um usuário a admin:
-- UPDATE public.profiles SET role = 'admin' WHERE email = 'admin@email.com';

-- Ver todos os inscritos com dados:
-- SELECT r.registration_number, p.full_name, p.cpf, p.city, r.status, r.amount
-- FROM registrations r
-- JOIN profiles p ON r.user_id = p.id
-- ORDER BY r.registration_number;

-- Contar por status:
-- SELECT status, COUNT(*) FROM registrations GROUP BY status;

-- Total arrecadado (confirmados):
-- SELECT SUM(amount) FROM registrations WHERE status = 'confirmed';
