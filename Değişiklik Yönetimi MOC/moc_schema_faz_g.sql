-- ============================================================================
-- MOC (Değişiklik Yönetimi) — Faz G: Checklist Tetikleyici Cevap Düzeltmesi
-- ============================================================================
-- BULGU: moc_etki_checklist_maddeleri'nde iki farklı soru tarzı var ama
-- sistem hepsinde "Evet ise aksiyon gerekli" sabit kabulünü kullanıyordu:
--   * "Risk tespit" tarzı ("X etkileniyor mu/gerekiyor mu/değişti mi?")
--     → EVET kötü haberdir, aksiyon doğurmalı. (Sabit varsayımla zaten
--       doğru çalışıyordu.)
--   * "Doğrulama/teyit" tarzı ("X tamamlandı mı/test edildi mi/çalışıyor
--     mu?") → HAYIR kötü haberdir, aksiyon doğurması gereken cevap odur.
--     (Sabit "Evet" varsayımıyla bu sorularda mantık TERS çalışıyordu —
--     özellikle PSSR setinin 13 maddesinin TAMAMI ve Genel Risk setinin
--     52 maddesi bu tarzda.)
--
-- Bu script her maddeye kendi "tetikleyen_cevap" değerini (Evet/Hayır)
-- atayan idempotent bir düzeltmedir. Yeni kolonun DEFAULT'u 'Evet' —
-- yani hiçbir UPDATE eşleşmezse (ör. bu script hiç çalıştırılmasa da)
-- sistem eski davranışını (her zaman Evet tetikler) korur, geriye dönük
-- uyumlu. Yalnız gerçekten "Hayır tetikler" olan maddeler aşağıda açıkça
-- güncelleniyor; "Evet tetikler" olan maddeler (Gıda setinin 10 maddesi +
-- Genel Risk'in 13 maddesi + PSSR'da hiçbiri) zaten varsayılanla eşleştiği
-- için ayrıca UPDATE edilmedi (bkz. proje CLAUDE.md "Faz G" bölümündeki
-- tam kırılım raporu).
--
-- KARARSIZ KALINAN 3 MADDE (bilinçli olarak GÜNCELLENMEDİ, varsayılan
-- 'Evet'te bırakıldı — çift olumsuz cümle yapısı nedeniyle yanlış
-- yorumlama riski var, kullanıcı onayı bekleniyor):
--   * Genel Risk #39: "İtfaiye/acil müdahale ekiplerinin alana erişimi
--     engellenmiyor mu?"
--   * Genel Risk #40: "Yangın duvarları/bölmeleri değişiklikle delinmedi
--     veya zayıflatılmadı mı?"
--   * Genel Risk #51: "Değişiklik için gerekli tüm onaylar tamamlanmadan
--     işe başlanmıyor mu?"
--
-- UPDATE'ler soru_metni (tam cümle) eşleşmesiyle yapılır — id'ler seed
-- sırasında (IDENTITY) otomatik üretildiği için script içinde sabit
-- değildir; soru cümleleri özgün ve tekil olduğundan bu eşleşme madde
-- bazlıdır (toplu/kategorik bir güncelleme değildir). Global şablon
-- YANI SIRA tenant'ların "Kullan"/"Kopyala" ile oluşturduğu kopyalar da
-- (aynı soru_metni'ni taşıdıkları için) otomatik düzelir — bu bir mantık
-- hatası düzeltmesi olduğu için tenant özelleştirmesi olarak görülmüyor.
--
-- Bu script idempotenttir: ADD COLUMN IF NOT EXISTS, UPDATE'ler zaten
-- doğru değere sahip satırlarda no-op'tur. DROP yok.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. moc_etki_checklist_maddeleri — tetikleyen_cevap kolonu
-- ----------------------------------------------------------------------------
ALTER TABLE public.moc_etki_checklist_maddeleri
  ADD COLUMN IF NOT EXISTS tetikleyen_cevap TEXT NOT NULL DEFAULT 'Evet';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'moc_etki_checklist_maddeleri_tetikleyen_cevap_check'
  ) THEN
    ALTER TABLE public.moc_etki_checklist_maddeleri
      ADD CONSTRAINT moc_etki_checklist_maddeleri_tetikleyen_cevap_check
      CHECK (tetikleyen_cevap IN ('Evet','Hayır'));
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 2. Genel Risk Değerlendirme Checklist'i — "Hayır tetikler" maddeleri (52)
--    (Doğrulama/teyit tarzı: "...tamamlandı/test edildi/yeterli mi?" vb.)
-- ----------------------------------------------------------------------------
UPDATE public.moc_etki_checklist_maddeleri SET tetikleyen_cevap = 'Hayır'
WHERE soru_metni = ANY(ARRAY[
  'Değişikliğin uygulanacağı alanın zemin taşıma kapasitesi ve yüzey durumu yeni ekipman/yerleşim için yeterli mi?',
  'Alana araç/personel erişim yolları değişiklikten sonra da güvenli ve engelsiz kalıyor mu?',
  'Mevcut aydınlatma seviyesi yeni düzenlemede yeterli görüş sağlıyor mu?',
  'Havalandırma/nem/sıcaklık koşulları yeni ekipman veya işleve uygun mu?',
  'Komşu alan/hatlarla güvenlik mesafesi (yangın, patlama, çarpışma riski) korunuyor mu?',
  'Zemin altı/üstü tesisat (elektrik, su, buhar, hava hattı) çakışması kontrol edildi mi?',
  'Kullanılacak malzeme/ekipman, prosesteki basınç-sıcaklık-akış koşullarına uygun sertifikaya/spesifikasyona sahip mi?',
  'Basınç ve sıcaklık kontrol noktaları (emniyet valfi, patlama diski vb.) yeni koşullara göre yeniden değerlendirildi mi?',
  'Alarm ve kilitleme (interlock) sistemleri yeni proses akışına uygun şekilde güncellendi mi?',
  'Enstrümantasyon (sensör, aktüatör) doğruluğu ve kalibrasyon planı gözden geçirildi mi?',
  'Elektrik yükü/kapasitesi (pano, kablo kesiti, koruma) değişiklikle uyumlu mu?',
  'Yazılım/kontrol sistemi (PLC/SCADA) değişikliği varsa, mantık değişikliği bağımsız olarak test edildi mi?',
  'Yedeklilik gerektiren kritik noktalarda tek nokta arıza riski değerlendirildi mi?',
  'Malzeme uyumluluğu (korozyon, aşınma, kimyasal reaksiyon) kontrol edildi mi?',
  'Proses değişikliğinin yukarı/aşağı akış ekipmanlarına etkisi incelendi mi?',
  'Kapasite/debi değişikliği, mevcut boru/hat çapı ve pompa seçimiyle uyumlu mu?',
  'Kritik ekipmanlar için bakım erişilebilirliği (valf, filtre, numune noktası) korunuyor mu?',
  'Statik elektrik, topraklama ve patlayıcı ortam gereksinimleri gözden geçirildi mi?',
  'Proses değişikliği sonrası ölçüm/izleme noktaları (basınç, sıcaklık, seviye) yeterli mi?',
  'Hareketli parçalar için makine koruyucuları/bariyerler yeterli ve erişilebilir mi?',
  'Elektrik izolasyonu ve kilitleme-etiketleme noktaları tanımlandı mı?',
  'Gerekli kişisel koruyucu donanım ihtiyacı yeniden belirlendi mi?',
  'Kaldırma ekipmanı (vinç, forklift, kaldıraç) kapasitesi yeni yüklerle uyumlu mu?',
  'Ergonomi (erişim yüksekliği, tekrarlayan hareket) değerlendirmesi yapıldı mı?',
  'Acil durdurma düğmeleri erişilebilir ve görünür konumda mı?',
  'Yeni ekipman/alan için güvenlik eğitimi ihtiyacı belirlendi mi?',
  'Yangın algılama (duman/ısı dedektörü) kapsama alanı yeni yerleşimi kapsıyor mu?',
  'Sabit/taşınabilir yangın söndürme sistemleri yeni riske uygun mu?',
  'Yanıcı/parlayıcı madde depolama mesafeleri ve miktar limitleri korunuyor mu?',
  'Acil durum aydınlatması ve yönlendirme işaretleri yeterli mi?',
  'Acil durum senaryoları (yangın, gaz kaçağı, dökülme) güncellendi mi?',
  'Gaz/kimyasal algılama sistemi kapsamı yeni ekipman için yeterli mi?',
  'Acil durum iletişim sistemi (anons, alarm) yeni alanda duyulabilir mi?',
  'Sızıntı/dökülme riski olan noktalarda ikincil koruma (bund, drenaj) yeterli mi?',
  'Tehlikeli madde depolama/taşıma koşulları çevresel mevzuata uygun mu?',
  'İş için görevlendirilen yüklenici/taşeronun yeterlilik/belge kontrolü yapıldı mı?',
  'Uygulama sırasında geçici risk azaltıcı önlemler (bariyer, gözetim) planlandı mı?',
  'Kurulum/imalat sırasında kalite kontrol noktaları (muayene, test) tanımlandı mı?',
  'Devreye alma öncesi test ve muayene kayıtları (basınç testi, kalibrasyon vb.) tutulacak mı?',
  'Değişiklik sırasında etkilenen ekipmanların geçici olarak devre dışı bırakılması planlandı mı?',
  'İş izni (sıcak çalışma, yüksekte çalışma, kapalı alan) gereksinimleri belirlendi mi?',
  'Değişiklikle ilgili teknik çizim/doküman güncellemesi kim tarafından yapılacak, netleşti mi?',
  'Uygulama sonrası eski ekipman/malzemenin güvenli şekilde ortadan kaldırılması planlandı mı?',
  'Kurulum sonrası fonksiyon/performans testi planı hazırlandı mı?',
  'Etkilenen çalışma talimatları/prosedürler güncellenip onaylandı mı?',
  'İlgili personel için değişiklik hakkında bilgilendirme/eğitim planlandı mı?',
  'Kritik yedek parça stoku yeni ekipman için oluşturuldu mu?',
  'Bakım planı (periyodik bakım, kalibrasyon takvimi) yeni ekipmanı kapsayacak şekilde güncellendi mi?',
  'Devreye alma sırasında izlenecek kritik parametreler ve kabul kriterleri tanımlandı mı?',
  'Vardiya/operasyon ekiplerine devreye alma zamanlaması önceden bildirildi mi?',
  'Değişiklik sonrası ilk dönem (deneme süresi) için ek gözetim planlandı mı?',
  'Devreye alma sonrası açık kalan aksiyonların takip sorumlusu belirlendi mi?'
]) AND tetikleyen_cevap <> 'Hayır';

-- ----------------------------------------------------------------------------
-- 3. PSSR Checklist'i — "Hayır tetikler" maddeleri (13/13, hepsi doğrulama
--    tarzı). Not: madde #2 zaten evet_aksiyon_gerekli=false (N/A olabilir,
--    hiçbir cevapta aksiyon açmıyor) — tetikleyen_cevap yine de anlam
--    tutarlılığı için 'Hayır' işaretlendi, işlevsel etkisi yoktur.
-- ----------------------------------------------------------------------------
UPDATE public.moc_etki_checklist_maddeleri SET tetikleyen_cevap = 'Hayır'
WHERE soru_metni = ANY(ARRAY[
  'Kurulum, onaylanan tasarım/çizimlere uygun mu?',
  'Basınç tahliye/emniyet cihazları doğru boyutlandırılmış ve belgelendirilmiş mi?',
  'Enstrümantasyon kalibre edilip test edildi mi?',
  'Elektrik tesisatı tamamlanıp kontrol edildi mi?',
  'Kilitleme (interlock) sistemleri test edildi mi?',
  'Alarmlar test edildi mi?',
  'Acil durdurma sistemleri çalışır durumda mı?',
  'Yangın/gaz algılama ve söndürme sistemleri operasyonel mi?',
  'İlgili şema/teknik çizimler (P&ID vb.) güncellendi mi?',
  'Çalışma/işletme prosedürleri revize edildi mi?',
  'Acil durum prosedürleri güncellendi mi?',
  'Etkilenen tüm personel değişiklik konusunda eğitildi mi, eğitim belgelendirildi mi?',
  'Önceki risk değerlendirmesinden (Genel Risk / Gıda seti) açık kalan tüm aksiyon maddeleri kapatıldı mı?'
]) AND tetikleyen_cevap <> 'Hayır';

-- Gıda Güvenliği Etki Değerlendirmesi'nin 10 maddesi de dahil, "Evet
-- tetikler" olan tüm maddeler kolonun DEFAULT'u ('Evet') ile zaten
-- doğru durumda — ayrıca UPDATE gerekmiyor (bkz. CLAUDE.md kırılımı).

COMMIT;

-- ============================================================================
-- GERİ ALMA (yalnız elle, gerekirse — bu script bunu ÇALIŞTIRMAZ)
-- ============================================================================
-- BEGIN;
-- UPDATE public.moc_etki_checklist_maddeleri SET tetikleyen_cevap = 'Evet';
-- ALTER TABLE public.moc_etki_checklist_maddeleri DROP CONSTRAINT IF EXISTS moc_etki_checklist_maddeleri_tetikleyen_cevap_check;
-- ALTER TABLE public.moc_etki_checklist_maddeleri DROP COLUMN IF EXISTS tetikleyen_cevap;
-- COMMIT;
-- ============================================================================
