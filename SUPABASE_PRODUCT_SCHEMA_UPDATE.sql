-- ========================================
-- Supabase Product Schema Update
-- ========================================
-- Run this script in Supabase SQL Editor
-- Adds image_url and price columns to products table
-- ========================================

-- Step 1: Add new columns to products table
ALTER TABLE products
ADD COLUMN IF NOT EXISTS image_url TEXT,
ADD COLUMN IF NOT EXISTS price DECIMAL(10, 2);

-- Step 2: Add comments to describe the columns
COMMENT ON COLUMN products.image_url IS 'URL to product image stored in Supabase Storage';
COMMENT ON COLUMN products.price IS 'Product price in USD';

-- Step 3: Create storage bucket for product images (if not exists)
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

-- Step 4: Set up storage policies for product images
-- First, drop existing policies if they exist
DROP POLICY IF EXISTS "Authenticated users can upload product images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own product images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own product images" ON storage.objects;
DROP POLICY IF EXISTS "Public read access to product images" ON storage.objects;

-- Allow authenticated users to upload images
CREATE POLICY "Authenticated users can upload product images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'product-images');

-- Allow authenticated users to update their own product images
CREATE POLICY "Users can update their own product images"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'product-images');

-- Allow authenticated users to delete their own product images
CREATE POLICY "Users can delete their own product images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'product-images');

-- Allow public read access to product images (so they can be displayed in the app)
CREATE POLICY "Public read access to product images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'product-images');

-- ========================================
-- VERIFICATION
-- ========================================

-- Check that columns were added successfully
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'products'
AND column_name IN ('image_url', 'price');

-- Check that storage bucket was created
SELECT * FROM storage.buckets WHERE id = 'product-images';

-- Check that storage policies were created
SELECT policyname, cmd, qual
FROM pg_policies
WHERE schemaname = 'storage'
AND tablename = 'objects'
AND policyname LIKE '%product images%';

-- ========================================
-- DONE!
-- ========================================
-- The products table now supports:
-- - image_url: URL to product image in Supabase Storage
-- - price: Product price as decimal (10,2)
--
-- Storage bucket 'product-images' is configured with:
-- - Public read access (anyone can view images)
-- - Authenticated users can upload/update/delete
-- ========================================
