-- OA Manager v1
-- 6.1 Storage 버킷 생성 + 6.3 Storage RLS 정책

-- 6.1 버킷 생성
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('inspection-photos', 'inspection-photos', false),
  ('inspection-signatures', 'inspection-signatures', false),
  ('drawing-images', 'drawing-images', false);

-- 6.3 Storage RLS 정책

-- inspection-photos
CREATE POLICY "inspection_photos_select" ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'inspection-photos');

CREATE POLICY "inspection_photos_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'inspection-photos');

CREATE POLICY "inspection_photos_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'inspection-photos');

CREATE POLICY "inspection_photos_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'inspection-photos');

-- inspection-signatures
CREATE POLICY "inspection_signatures_select" ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'inspection-signatures');

CREATE POLICY "inspection_signatures_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'inspection-signatures');

CREATE POLICY "inspection_signatures_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'inspection-signatures');

CREATE POLICY "inspection_signatures_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'inspection-signatures');

-- drawing-images
CREATE POLICY "drawing_images_select" ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'drawing-images');

CREATE POLICY "drawing_images_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'drawing-images');

CREATE POLICY "drawing_images_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'drawing-images');

CREATE POLICY "drawing_images_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'drawing-images');
