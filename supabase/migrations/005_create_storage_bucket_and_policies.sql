-- =============================================
-- MIGRATION 005: CREATE STORAGE BUCKET AND POLICIES
-- Version: 20260303204207
-- Description: Storage bucket for payment proofs + access policies
-- =============================================

-- Create storage bucket for payment proofs
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'payment-proofs',
  'payment-proofs',
  false,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
);

-- Storage RLS: Athletes can upload to their own folder
CREATE POLICY "Athletes can upload payment proofs"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'payment-proofs' 
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Storage RLS: Athletes can read their own files
CREATE POLICY "Athletes can read own payment proofs"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'payment-proofs' 
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Storage RLS: Admins can read all files
CREATE POLICY "Admins can read all payment proofs"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'payment-proofs'
    AND EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
