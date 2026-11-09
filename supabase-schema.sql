-- RUOTH LUXURY - COMPLETE DATABASE SETUP

-- PASTE YOUR SUPABASE ADMIN USER UID HERE
DO $$
DECLARE
  admin_uid UUID := 'bb44165d-8ac8-4fd0-9e63-69f1e1b0c030';
BEGIN

CREATE TABLE IF NOT EXISTS public.admin_users (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL CHECK (char_length(name) BETWEEN 2 AND 100),
  description TEXT NOT NULL DEFAULT '',
  price NUMERIC(12,2) NOT NULL CHECK (price > 0),
  category TEXT NOT NULL CHECK (category IN ('wallets','handbags','accessories')),
  image_url TEXT NOT NULL,
  is_featured BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS products_active_created_idx
ON public.products (is_active, created_at DESC);

CREATE OR REPLACE FUNCTION public.is_ruoth_admin()
RETURNS BOOLEAN
LANGUAGE SQL STABLE SECURITY DEFINER
SET search_path = public
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE user_id = (SELECT auth.uid())
  );
$function$;

REVOKE ALL ON FUNCTION public.is_ruoth_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_ruoth_admin() TO anon, authenticated;

ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can read their own admin record" ON public.admin_users;
CREATE POLICY "Admins can read their own admin record"
ON public.admin_users FOR SELECT TO authenticated
USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Public can read active products" ON public.products;
CREATE POLICY "Public can read active products"
ON public.products FOR SELECT TO anon, authenticated
USING (is_active = TRUE OR public.is_ruoth_admin());

DROP POLICY IF EXISTS "Admins can insert products" ON public.products;
CREATE POLICY "Admins can insert products"
ON public.products FOR INSERT TO authenticated
WITH CHECK (public.is_ruoth_admin());

DROP POLICY IF EXISTS "Admins can update products" ON public.products;
CREATE POLICY "Admins can update products"
ON public.products FOR UPDATE TO authenticated
USING (public.is_ruoth_admin())
WITH CHECK (public.is_ruoth_admin());

DROP POLICY IF EXISTS "Admins can delete products" ON public.products;
CREATE POLICY "Admins can delete products"
ON public.products FOR DELETE TO authenticated
USING (public.is_ruoth_admin());

-- PRODUCT IMAGE STORAGE BUCKET
INSERT INTO storage.buckets
(id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'product-images',
  'product-images',
  TRUE,
  5242880,
  ARRAY['image/jpeg','image/png','image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = TRUE,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg','image/png','image/webp'];

DROP POLICY IF EXISTS "Public can view product images" ON storage.objects;
CREATE POLICY "Public can view product images"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'product-images');

DROP POLICY IF EXISTS "Admins can upload product images" ON storage.objects;
CREATE POLICY "Admins can upload product images"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'product-images'
  AND public.is_ruoth_admin()
);

DROP POLICY IF EXISTS "Admins can update product images" ON storage.objects;
CREATE POLICY "Admins can update product images"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'product-images'
  AND public.is_ruoth_admin()
)
WITH CHECK (
  bucket_id = 'product-images'
  AND public.is_ruoth_admin()
);

DROP POLICY IF EXISTS "Admins can delete product images" ON storage.objects;
CREATE POLICY "Admins can delete product images"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'product-images'
  AND public.is_ruoth_admin()
);

-- REGISTER YOUR ADMIN ACCOUNT
IF admin_uid IS NULL THEN
  RAISE EXCEPTION 'Please enter your actual Supabase User UID at the top.';
END IF;

INSERT INTO public.admin_users (user_id)
VALUES (admin_uid)
ON CONFLICT (user_id) DO NOTHING;

RAISE NOTICE 'RUOTH LUXURY DATABASE SETUP COMPLETED!';

END $$;