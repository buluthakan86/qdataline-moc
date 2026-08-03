-- ============================================================================
-- MOC (Değişiklik Yönetimi) — Faz F: PSSR Checklist Seti (durum tetiklemeli)
-- ============================================================================
-- Amaç: moc_etki_checklist_setleri mimarisini üçüncü bir sete taşımak, ama
-- bu kez KATEGORİ değil DURUM/ADIM bazlı tetikleme ile. Mevcut iki set
-- (Genel Risk, Gıda Güvenliği) MOC talebi oluşturulurken kategoriye göre
-- devreye giriyordu (kategori_id). PSSR seti mimari olarak farklı: yalnız
-- requires_pssr=true olan türlerde, talep PSSR durumuna/adımına geldiğinde
-- devreye girmeli — talep oluşturulurken değil.
--
-- Bunu ayrı bir tablo yerine mevcut moc_etki_checklist_setleri/_maddeleri/
-- _yanitlari altyapısına yeni bir "tetik_tipi" ayrımıyla ekliyoruz — aynı
-- accordion/chip UI'ı, aynı "evet_aksiyon_gerekli" → moc_action_items
-- otomasyonu, aynı yanıt tablosu yeniden kullanılıyor (bkz. MOC.html).
--
-- Sorular harici saha güvenliği/devreye alma pratiklerinin KAPSAMINDAN
-- esinlenerek özgün cümlelerle yazılmıştır; hiçbir kaynak standart/kurum
-- adı burada veya UI'da geçmez, birebir metin kopyalanmamıştır.
--
-- Bu script idempotenttir: ADD COLUMN IF NOT EXISTS, seed DO $$ bloğunda
-- var olup olmadığı kontrol edilerek eklenir. DROP TABLE/COLUMN YOK.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. moc_etki_checklist_setleri — tetikleme tipi ayrımı
--    tetik_tipi='kategori' (varsayılan): mevcut iki set gibi, talep
--      oluşturulurken kategoriye göre devreye girer (kategori_id kolonu).
--    tetik_tipi='durum': yalnız belirli bir DURUM/ADIMA (tetik_durum_kodu,
--      örn. 'PSSR') gelindiğinde devreye girer; kategori_id bu tipte
--      anlamsızdır (NULL bırakılır).
--    DEFAULT 'kategori' sayesinde mevcut iki set otomatik olarak doğru
--    tipte kalır, elle UPDATE gerekmez.
-- ----------------------------------------------------------------------------
ALTER TABLE public.moc_etki_checklist_setleri
  ADD COLUMN IF NOT EXISTS tetik_tipi TEXT NOT NULL DEFAULT 'kategori',
  ADD COLUMN IF NOT EXISTS tetik_durum_kodu TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'moc_etki_checklist_setleri_tetik_tipi_check'
  ) THEN
    ALTER TABLE public.moc_etki_checklist_setleri
      ADD CONSTRAINT moc_etki_checklist_setleri_tetik_tipi_check
      CHECK (tetik_tipi IN ('kategori','durum'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_moc_etki_set_tetik ON public.moc_etki_checklist_setleri (tetik_tipi, tetik_durum_kodu);

-- ----------------------------------------------------------------------------
-- SEED — "Devreye Alma Öncesi Güvenlik İncelemesi" (global, tenant_id NULL,
-- tetik_tipi='durum', tetik_durum_kodu='PSSR', kategori_id NULL). MOC.html
-- tarafında yalnız requires_pssr=true türlerde ve PSSR panelinde gösterilir;
-- PSSR→STARTUP geçişi bu checklist tamamlanıp doğurduğu aksiyonlar
-- (phase='PSSR') kapanmadan kilitli kalır.
-- ----------------------------------------------------------------------------
DO $$
DECLARE v_set_id BIGINT;
BEGIN
  SELECT id INTO v_set_id FROM public.moc_etki_checklist_setleri
    WHERE tenant_id IS NULL AND tetik_tipi = 'durum' AND tetik_durum_kodu = 'PSSR'
      AND ad = 'Devreye Alma Öncesi Güvenlik İncelemesi';

  IF v_set_id IS NULL THEN
    INSERT INTO public.moc_etki_checklist_setleri (tenant_id, kategori_id, ad, aciklama, aktif, tetik_tipi, tetik_durum_kodu)
    VALUES (NULL, NULL, 'Devreye Alma Öncesi Güvenlik İncelemesi',
      'requires_pssr=true olan akış türlerinde, talep PSSR adımına geldiğinde doldurulması zorunlu devreye alma öncesi güvenlik doğrulama checklist''i.',
      true, 'durum', 'PSSR')
    RETURNING id INTO v_set_id;

    INSERT INTO public.moc_etki_checklist_maddeleri (set_id, bolum_baslik, soru_metni, sira_no, evet_aksiyon_gerekli) VALUES
    -- Ekipman ve Kurulum Doğrulaması
    (v_set_id,'Ekipman ve Kurulum Doğrulaması','Kurulum, onaylanan tasarım/çizimlere uygun mu?',1,true),
    (v_set_id,'Ekipman ve Kurulum Doğrulaması','Basınç tahliye/emniyet cihazları doğru boyutlandırılmış ve belgelendirilmiş mi?',2,false),
    (v_set_id,'Ekipman ve Kurulum Doğrulaması','Enstrümantasyon kalibre edilip test edildi mi?',3,true),
    (v_set_id,'Ekipman ve Kurulum Doğrulaması','Elektrik tesisatı tamamlanıp kontrol edildi mi?',4,true),
    -- Güvenlik Sistemleri Doğrulaması
    (v_set_id,'Güvenlik Sistemleri Doğrulaması','Kilitleme (interlock) sistemleri test edildi mi?',5,true),
    (v_set_id,'Güvenlik Sistemleri Doğrulaması','Alarmlar test edildi mi?',6,true),
    (v_set_id,'Güvenlik Sistemleri Doğrulaması','Acil durdurma sistemleri çalışır durumda mı?',7,true),
    (v_set_id,'Güvenlik Sistemleri Doğrulaması','Yangın/gaz algılama ve söndürme sistemleri operasyonel mi?',8,true),
    -- Dokümantasyon Doğrulaması
    (v_set_id,'Dokümantasyon Doğrulaması','İlgili şema/teknik çizimler (P&ID vb.) güncellendi mi?',9,true),
    (v_set_id,'Dokümantasyon Doğrulaması','Çalışma/işletme prosedürleri revize edildi mi?',10,true),
    (v_set_id,'Dokümantasyon Doğrulaması','Acil durum prosedürleri güncellendi mi?',11,true),
    -- Eğitim ve Kapanış Doğrulaması
    (v_set_id,'Eğitim ve Kapanış Doğrulaması','Etkilenen tüm personel değişiklik konusunda eğitildi mi, eğitim belgelendirildi mi?',12,true),
    (v_set_id,'Eğitim ve Kapanış Doğrulaması','Önceki risk değerlendirmesinden (Genel Risk / Gıda seti) açık kalan tüm aksiyon maddeleri kapatıldı mı?',13,true);
  END IF;
END $$;

COMMIT;

-- ============================================================================
-- GERİ ALMA (yalnız elle, gerekirse — bu script bunu ÇALIŞTIRMAZ)
-- ============================================================================
-- BEGIN;
-- DELETE FROM public.moc_etki_checklist_yanitlari WHERE madde_id IN (
--   SELECT m.id FROM public.moc_etki_checklist_maddeleri m
--   JOIN public.moc_etki_checklist_setleri s ON s.id = m.set_id
--   WHERE s.tetik_tipi = 'durum' AND s.tetik_durum_kodu = 'PSSR'
-- );
-- DELETE FROM public.moc_etki_checklist_maddeleri WHERE set_id IN (
--   SELECT id FROM public.moc_etki_checklist_setleri WHERE tetik_tipi = 'durum' AND tetik_durum_kodu = 'PSSR'
-- );
-- DELETE FROM public.moc_etki_checklist_setleri WHERE tetik_tipi = 'durum' AND tetik_durum_kodu = 'PSSR';
-- ALTER TABLE public.moc_etki_checklist_setleri DROP CONSTRAINT IF EXISTS moc_etki_checklist_setleri_tetik_tipi_check;
-- ALTER TABLE public.moc_etki_checklist_setleri DROP COLUMN IF EXISTS tetik_durum_kodu;
-- ALTER TABLE public.moc_etki_checklist_setleri DROP COLUMN IF EXISTS tetik_tipi;
-- COMMIT;
-- ============================================================================
