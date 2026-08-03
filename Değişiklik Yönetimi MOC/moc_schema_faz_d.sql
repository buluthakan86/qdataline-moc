-- ============================================================================
-- MOC (Değişiklik Yönetimi) — Faz D: Taleplerim/Tüm Değişiklikler listelerine
-- Düzenle + Sil (Q-Tedarikçi Faz D.1 güvenli silme deseniyle aynı ruhta).
-- ============================================================================
-- Silme kuralı: DRAFT durumundaki talepte hiçbir onay/işlem henüz başlamadığı
-- için KALICI silme serbest (alt tablolar zaten ON DELETE CASCADE — bkz.
-- moc_schema_faz_a.sql, tek DELETE ile hepsi temizlenir, yetim kayıt kalmaz).
-- DRAFT dışındaki durumlarda geçmişin değeri korunsun diye yalnız
-- `deleted_at` ile gizlenir (soft delete; listeden kaybolur, DB'de durur,
-- gerekirse SQL'den deleted_at=NULL yapılarak geri getirilebilir — ayrı bir
-- "Geri Dönüşüm" ekranı bilinçli olarak kapsam dışı). Açık aksiyon
-- (moc_action_items, status NOT IN ('DONE','CANCELLED')) varsa her iki
-- durumda da uygulama katmanında (MOC.html) silme engellenir.
--
-- GRANT/RLS notu: moc_requests için DELETE izni ve tenant_isolation FOR ALL
-- politikası Faz A'da zaten tanımlı (bkz. moc_schema_faz_a.sql GRANT +
-- tenant_isolation_moc_requests) — burada ek RLS/GRANT gerekmiyor, yalnız
-- soft-delete için yeni kolon ekleniyor.
--
-- İdempotent: ADD COLUMN IF NOT EXISTS. DROP yok.
-- ============================================================================

ALTER TABLE public.moc_requests ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_moc_requests_active ON public.moc_requests (tenant_id) WHERE deleted_at IS NULL;

-- ============================================================================
-- GERİ ALMA (yalnız elle, gerekirse — bu script bunu ÇALIŞTIRMAZ)
-- ============================================================================
-- BEGIN;
-- DROP INDEX IF EXISTS public.idx_moc_requests_active;
-- ALTER TABLE public.moc_requests DROP COLUMN IF EXISTS deleted_at;
-- COMMIT;
-- ============================================================================
