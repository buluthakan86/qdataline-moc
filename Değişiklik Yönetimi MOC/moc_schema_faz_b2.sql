-- ============================================================================
-- MOC (Değişiklik Yönetimi) — Faz B2: Ayarlar CRUD için yazma izinleri
-- ============================================================================
-- Faz A'da moc_change_categories / moc_types yalnız SELECT ile açılmıştı
-- (bkz. moc_schema_faz_a.sql §"Lookup tabloları"). Faz B2'de Ayarlar
-- ekranına kategori/tür CRUD eklendiği için INSERT/UPDATE izni gerekiyor.
-- DELETE kasıtlı olarak açılmıyor — silme yerine soft-delete (is_active=false)
-- kullanılıyor, böylece kullanılmış türler/kategoriler asla fiziksel
-- silinemiyor. Bu script idempotenttir (DROP POLICY IF EXISTS + CREATE).
-- Uygulama sırası: Supabase SQL Editor'da bu dosyayı bir kez çalıştırın.
-- ============================================================================

-- Kendi tenant'ına ait satır oluşturabilir (global/NULL tenant_id satırı
-- oluşturamaz — bu yalnız platform seviyesinde elle yönetilir).
DROP POLICY IF EXISTS tenant_write_categories ON public.moc_change_categories;
CREATE POLICY tenant_write_categories ON public.moc_change_categories
  FOR INSERT
  WITH CHECK (tenant_id = public.current_tenant_id());

-- Kendi tenant'ına ait satırı güncelleyebilir; global (NULL) satırlar
-- veya başka tenant'ın satırları güncellenemez.
DROP POLICY IF EXISTS tenant_update_categories ON public.moc_change_categories;
CREATE POLICY tenant_update_categories ON public.moc_change_categories
  FOR UPDATE
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS tenant_write_types ON public.moc_types;
CREATE POLICY tenant_write_types ON public.moc_types
  FOR INSERT
  WITH CHECK (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS tenant_update_types ON public.moc_types;
CREATE POLICY tenant_update_types ON public.moc_types
  FOR UPDATE
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

-- GRANT — DELETE kasıtlı olarak verilmiyor (yalnız soft-delete / is_active).
GRANT INSERT, UPDATE ON public.moc_change_categories, public.moc_types TO authenticated;
