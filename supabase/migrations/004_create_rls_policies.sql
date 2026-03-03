-- =============================================
-- MIGRATION 004: CREATE RLS POLICIES
-- Version: 20260303204156
-- Description: Row Level Security policies for all tables
-- =============================================

-- =============================================
-- RLS POLICIES FOR profiles
-- =============================================

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

-- Athletes can read their own profile
CREATE POLICY "Users can read own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

-- Athletes can update their own profile (but not role)
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id AND role = 'athlete');

-- Admins can read all profiles
CREATE POLICY "Admins can read all profiles"
  ON public.profiles FOR SELECT
  USING (public.is_admin());

-- Admins can update all profiles
CREATE POLICY "Admins can update all profiles"
  ON public.profiles FOR UPDATE
  USING (public.is_admin());

-- =============================================
-- RLS POLICIES FOR registrations
-- =============================================

-- Athletes can read their own registration
CREATE POLICY "Users can read own registration"
  ON public.registrations FOR SELECT
  USING (auth.uid() = user_id);

-- Admins can read all registrations
CREATE POLICY "Admins can read all registrations"
  ON public.registrations FOR SELECT
  USING (public.is_admin());

-- Admins can update all registrations
CREATE POLICY "Admins can update registrations"
  ON public.registrations FOR UPDATE
  USING (public.is_admin());

-- =============================================
-- RLS POLICIES FOR payment_proofs
-- =============================================

-- Athletes can read their own proofs
CREATE POLICY "Users can read own payment proofs"
  ON public.payment_proofs FOR SELECT
  USING (auth.uid() = user_id);

-- Athletes can insert their own proofs
CREATE POLICY "Users can insert own payment proofs"
  ON public.payment_proofs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Admins can read all proofs
CREATE POLICY "Admins can read all payment proofs"
  ON public.payment_proofs FOR SELECT
  USING (public.is_admin());
