-- ============================================================================
-- MOC (Değişiklik Yönetimi) — Faz E: Maliyet Takibi (çoklu para birimi)
-- ============================================================================
-- Alanlar: para_birimi (TRY/USD/EUR/GBP), baslangic_maliyeti (talep açılırken
-- girilir), tamamlanma_sonrasi_maliyet (MOC kapanınca girilir). sapma_tutari
-- ve sapma_yuzdesi GENERATED ALWAYS AS STORED kolonlardır — uygulama katmanı
-- bunları asla yazmaz, DB kendisi hesaplar (tutarsızlık imkansız).
--
-- Kur çevrimi bilinçli olarak DB'de değil, istemcide (MOC.html,
-- fetchExchangeRates/convertToTRY) yapılıyor: Frankfurter API (ECB referans
-- kurları, ücretsiz, key yok, CORS açık — test edildi, TRY dahil) güncel
-- kuru anlık çeker, ham girilen değer ile birlikte şeffaf gösterir
-- ("X USD, güncel kurla ~Y TRY"). DB'de sabit/gecikmeli bir kur saklanmaz.
--
-- İdempotent: ADD COLUMN IF NOT EXISTS. DROP yok.
-- ============================================================================

ALTER TABLE public.moc_requests ADD COLUMN IF NOT EXISTS para_birimi TEXT NOT NULL DEFAULT 'TRY'
  CHECK (para_birimi IN ('TRY','USD','EUR','GBP'));
ALTER TABLE public.moc_requests ADD COLUMN IF NOT EXISTS baslangic_maliyeti NUMERIC(14,2);
ALTER TABLE public.moc_requests ADD COLUMN IF NOT EXISTS tamamlanma_sonrasi_maliyet NUMERIC(14,2);

ALTER TABLE public.moc_requests ADD COLUMN IF NOT EXISTS sapma_tutari NUMERIC(14,2)
  GENERATED ALWAYS AS (
    CASE WHEN baslangic_maliyeti IS NULL OR tamamlanma_sonrasi_maliyet IS NULL THEN NULL
         ELSE tamamlanma_sonrasi_maliyet - baslangic_maliyeti END
  ) STORED;

ALTER TABLE public.moc_requests ADD COLUMN IF NOT EXISTS sapma_yuzdesi NUMERIC(8,2)
  GENERATED ALWAYS AS (
    CASE WHEN baslangic_maliyeti IS NULL OR tamamlanma_sonrasi_maliyet IS NULL OR baslangic_maliyeti = 0 THEN NULL
         ELSE ROUND(((tamamlanma_sonrasi_maliyet - baslangic_maliyeti) / baslangic_maliyeti) * 100, 2) END
  ) STORED;

-- ============================================================================
-- GERİ ALMA (yalnız elle, gerekirse — bu script bunu ÇALIŞTIRMAZ)
-- ============================================================================
-- BEGIN;
-- ALTER TABLE public.moc_requests DROP COLUMN IF EXISTS sapma_yuzdesi;
-- ALTER TABLE public.moc_requests DROP COLUMN IF EXISTS sapma_tutari;
-- ALTER TABLE public.moc_requests DROP COLUMN IF EXISTS tamamlanma_sonrasi_maliyet;
-- ALTER TABLE public.moc_requests DROP COLUMN IF EXISTS baslangic_maliyeti;
-- ALTER TABLE public.moc_requests DROP COLUMN IF EXISTS para_birimi;
-- COMMIT;
-- ============================================================================
