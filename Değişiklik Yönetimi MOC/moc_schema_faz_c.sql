-- ============================================================================
-- MOC (Değişiklik Yönetimi) — Faz C: Etki Değerlendirme Checklist Sistemi
-- ============================================================================
-- Amaç: MOC talebi için kategoriden bağımsız zorunlu bir "Genel Risk
-- Değerlendirme" checklist'i (Set 1) ve yalnız belirli bir kategoride
-- (Ürün/Reçete Değişikliği) devreye giren opsiyonel bir "Gıda Güvenliği
-- Etki Değerlendirmesi" checklist'i (Set 2) ekler. "Evet + aksiyon
-- gerekli" cevabı otomatik bir moc_action_items kaydı oluşturur.
--
-- Sorular harici saha güvenliği/risk değerlendirmesi kaynak dokümanlarının
-- KAPSAMINDAN esinlenerek özgün cümlelerle yazılmıştır; hiçbir kaynak
-- standart/kurum adı burada veya UI'da geçmez, birebir metin kopyalanmamıştır.
--
-- Mimari (bkz. proje CLAUDE.md):
--   * moc_etki_checklist_setleri.kategori_id NULL  → TÜM MOC taleplerinde
--     devreye girer (Set 1). Dolu ise yalnız o kategori seçilince (Set 2).
--   * moc_etki_checklist_setleri.tenant_id NULL    → global şablon.
--     Dolu ise tenant'a özel KOPYA (bkz. MOC.html "Kullan" akışı). Zorunlu
--     (kategori_id NULL) setler global haliyle doğrudan her tenant'a
--     uygulanır; opsiyonel (kategori_id dolu) setler yalnız tenant kendi
--     kopyasını oluşturduğunda ("Kullan") o tenant'ta devreye girer —
--     ilgisiz tenant'lar global şablonu hiç görmez/kullanmaz.
--   * Yeni RPC yok — tüm işlemler doğrudan INSERT/UPDATE + RLS ile yapılır.
--   * DELETE yok — soft-delete (is_active/aktif=false), diğer lookup
--     tablolarıyla aynı disiplin.
--
-- Bu script idempotenttir: CREATE TABLE IF NOT EXISTS, DROP POLICY IF
-- EXISTS + CREATE, seed'ler DO $$ bloklarında var olup olmadığı kontrol
-- edilerek eklenir (ON CONFLICT'e uygun UNIQUE kolon yok, bilinçli tercih
-- — kullanıcı çoğaltma yerine var-olma kontrolü). DROP TABLE YOK.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 0. Yeni kategori: "Ürün/Reçete Değişikliği" (Set 2'nin tetikleyicisi)
--    Mevcut NEW_PRODUCT ("Yeni Ürün Geliştirme") kavramsal olarak farklı
--    (yeni ürün lansmanı vs. mevcut ürün/reçete revizyonu) — ayrı kod.
-- ----------------------------------------------------------------------------
INSERT INTO public.moc_change_categories (tenant_id, code, name_tr, name_en, requires_equipment_link, sort_order)
VALUES (NULL, 'PRODUCT_RECIPE', 'Ürün/Reçete Değişikliği', 'Product/Recipe Change', false, 9)
ON CONFLICT (tenant_id, code) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 1. Checklist setleri
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.moc_etki_checklist_setleri (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id    UUID,                              -- NULL = global şablon, dolu = tenant kopyası
  kategori_id  BIGINT REFERENCES public.moc_change_categories(id) ON DELETE SET NULL,
                                                    -- NULL = tüm kategorilerde zorunlu
  ad           TEXT NOT NULL,
  aciklama     TEXT,
  aktif        BOOLEAN NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_moc_etki_set_kategori ON public.moc_etki_checklist_setleri (kategori_id);
CREATE INDEX IF NOT EXISTS idx_moc_etki_set_tenant   ON public.moc_etki_checklist_setleri (tenant_id);

-- ----------------------------------------------------------------------------
-- 2. Checklist maddeleri
--    is_active: soru artık sorulmasın istenirse kapatılır (fiziksel silme
--    yok — geçmiş yanıtlar madde_id FK'sini kaybetmesin diye).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.moc_etki_checklist_maddeleri (
  id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  set_id               BIGINT NOT NULL REFERENCES public.moc_etki_checklist_setleri(id) ON DELETE CASCADE,
  bolum_baslik         TEXT NOT NULL,             -- ör. "Alan/Lokasyon Değerlendirmesi"
  soru_metni           TEXT NOT NULL,
  sira_no              INT NOT NULL DEFAULT 0,
  evet_aksiyon_gerekli BOOLEAN NOT NULL DEFAULT false,
  is_active            BOOLEAN NOT NULL DEFAULT true
);
CREATE INDEX IF NOT EXISTS idx_moc_etki_madde_set ON public.moc_etki_checklist_maddeleri (set_id, sira_no);

-- ----------------------------------------------------------------------------
-- 3. Checklist yanıtları — MOC talebi başına, madde başına tek yanıt.
--    "Evet + aksiyon gerekli" cevabı verildiğinde uygulama action_id'yi
--    oluşturduğu moc_action_items kaydına set eder (bkz. MOC.html).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.moc_etki_checklist_yanitlari (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id       UUID NOT NULL,
  moc_request_id  BIGINT NOT NULL REFERENCES public.moc_requests(id) ON DELETE CASCADE,
  madde_id        BIGINT NOT NULL REFERENCES public.moc_etki_checklist_maddeleri(id) ON DELETE CASCADE,
  cevap           TEXT CHECK (cevap IN ('EVET','HAYIR','NA')),
  gerekce         TEXT,                            -- EVET ise UI'da zorunlu
  action_id       BIGINT REFERENCES public.moc_action_items(id) ON DELETE SET NULL,
  answered_by     UUID REFERENCES auth.users(id),
  answered_at     TIMESTAMPTZ,
  UNIQUE (moc_request_id, madde_id)
);
CREATE INDEX IF NOT EXISTS idx_moc_etki_yanit_moc ON public.moc_etki_checklist_yanitlari (moc_request_id);

-- ----------------------------------------------------------------------------
-- Row-Level Security
-- ----------------------------------------------------------------------------
ALTER TABLE public.moc_etki_checklist_setleri ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_or_global_etki_setleri ON public.moc_etki_checklist_setleri;
CREATE POLICY tenant_or_global_etki_setleri ON public.moc_etki_checklist_setleri
  FOR SELECT
  USING (tenant_id IS NULL OR tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS tenant_write_etki_setleri ON public.moc_etki_checklist_setleri;
CREATE POLICY tenant_write_etki_setleri ON public.moc_etki_checklist_setleri
  FOR INSERT
  WITH CHECK (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS tenant_update_etki_setleri ON public.moc_etki_checklist_setleri;
CREATE POLICY tenant_update_etki_setleri ON public.moc_etki_checklist_setleri
  FOR UPDATE
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

-- Maddeler: doğrudan tenant_id kolonu yok, üst set üzerinden kontrol edilir.
ALTER TABLE public.moc_etki_checklist_maddeleri ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_or_global_etki_maddeleri ON public.moc_etki_checklist_maddeleri;
CREATE POLICY tenant_or_global_etki_maddeleri ON public.moc_etki_checklist_maddeleri
  FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM public.moc_etki_checklist_setleri s
    WHERE s.id = set_id AND (s.tenant_id IS NULL OR s.tenant_id = public.current_tenant_id())
  ));

DROP POLICY IF EXISTS tenant_write_etki_maddeleri ON public.moc_etki_checklist_maddeleri;
CREATE POLICY tenant_write_etki_maddeleri ON public.moc_etki_checklist_maddeleri
  FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.moc_etki_checklist_setleri s
    WHERE s.id = set_id AND s.tenant_id = public.current_tenant_id()
  ));

DROP POLICY IF EXISTS tenant_update_etki_maddeleri ON public.moc_etki_checklist_maddeleri;
CREATE POLICY tenant_update_etki_maddeleri ON public.moc_etki_checklist_maddeleri
  FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM public.moc_etki_checklist_setleri s
    WHERE s.id = set_id AND s.tenant_id = public.current_tenant_id()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.moc_etki_checklist_setleri s
    WHERE s.id = set_id AND s.tenant_id = public.current_tenant_id()
  ));

-- Yanıtlar: normal tenant izolasyonu (moc_risk_assessments ile aynı desen).
ALTER TABLE public.moc_etki_checklist_yanitlari ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation_etki_yanitlari ON public.moc_etki_checklist_yanitlari;
CREATE POLICY tenant_isolation_etki_yanitlari ON public.moc_etki_checklist_yanitlari
  FOR ALL
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

-- ----------------------------------------------------------------------------
-- GRANT — DELETE kasıtlı olarak verilmiyor (soft-delete / is_active-aktif).
-- ----------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON
  public.moc_etki_checklist_setleri, public.moc_etki_checklist_maddeleri,
  public.moc_etki_checklist_yanitlari
  TO authenticated;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ----------------------------------------------------------------------------
-- SEED — Set 1: Genel Risk Değerlendirme Checklist'i (global, zorunlu,
-- kategori_id NULL). Var olup olmadığı ad ile kontrol edilir (idempotent).
-- ----------------------------------------------------------------------------
DO $$
DECLARE v_set_id BIGINT;
BEGIN
  SELECT id INTO v_set_id FROM public.moc_etki_checklist_setleri
    WHERE tenant_id IS NULL AND kategori_id IS NULL AND ad = 'Genel Risk Değerlendirme Checklist''i';

  IF v_set_id IS NULL THEN
    INSERT INTO public.moc_etki_checklist_setleri (tenant_id, kategori_id, ad, aciklama, aktif)
    VALUES (NULL, NULL, 'Genel Risk Değerlendirme Checklist''i',
      'Her değişiklik talebinde, kategoriden bağımsız olarak doldurulması zorunlu genel saha güvenliği ve risk değerlendirme checklist''i.',
      true)
    RETURNING id INTO v_set_id;

    INSERT INTO public.moc_etki_checklist_maddeleri (set_id, bolum_baslik, soru_metni, sira_no, evet_aksiyon_gerekli) VALUES
    -- Alan/Lokasyon Değerlendirmesi (10)
    (v_set_id,'Alan/Lokasyon Değerlendirmesi','Değişikliğin uygulanacağı alanın zemin taşıma kapasitesi ve yüzey durumu yeni ekipman/yerleşim için yeterli mi?',1,true),
    (v_set_id,'Alan/Lokasyon Değerlendirmesi','Alana araç/personel erişim yolları değişiklikten sonra da güvenli ve engelsiz kalıyor mu?',2,true),
    (v_set_id,'Alan/Lokasyon Değerlendirmesi','Acil durum tahliye yolları ve toplanma noktaları değişiklikten olumsuz etkileniyor mu?',3,true),
    (v_set_id,'Alan/Lokasyon Değerlendirmesi','Mevcut aydınlatma seviyesi yeni düzenlemede yeterli görüş sağlıyor mu?',4,true),
    (v_set_id,'Alan/Lokasyon Değerlendirmesi','Havalandırma/nem/sıcaklık koşulları yeni ekipman veya işleve uygun mu?',5,true),
    (v_set_id,'Alan/Lokasyon Değerlendirmesi','Komşu alan/hatlarla güvenlik mesafesi (yangın, patlama, çarpışma riski) korunuyor mu?',6,true),
    (v_set_id,'Alan/Lokasyon Değerlendirmesi','Zemin altı/üstü tesisat (elektrik, su, buhar, hava hattı) çakışması kontrol edildi mi?',7,true),
    (v_set_id,'Alan/Lokasyon Değerlendirmesi','Değişiklik sonrası yük taşıma/forklift/vinç erişim güzergâhları etkileniyor mu?',8,true),
    (v_set_id,'Alan/Lokasyon Değerlendirmesi','Görsel işaretleme (yer işaretleri, tehlike levhaları, yön okları) güncellenmesi gerekiyor mu?',9,true),
    (v_set_id,'Alan/Lokasyon Değerlendirmesi','Dış ortam etkileri (hava koşulları, titreşim, gürültü kaynakları) yeni yerleşimi etkiler mi?',10,true),
    -- Proses Tasarımı ve Güvenilirlik (13)
    (v_set_id,'Proses Tasarımı ve Güvenilirlik','Kullanılacak malzeme/ekipman, prosesteki basınç-sıcaklık-akış koşullarına uygun sertifikaya/spesifikasyona sahip mi?',11,true),
    (v_set_id,'Proses Tasarımı ve Güvenilirlik','Basınç ve sıcaklık kontrol noktaları (emniyet valfi, patlama diski vb.) yeni koşullara göre yeniden değerlendirildi mi?',12,true),
    (v_set_id,'Proses Tasarımı ve Güvenilirlik','Alarm ve kilitleme (interlock) sistemleri yeni proses akışına uygun şekilde güncellendi mi?',13,true),
    (v_set_id,'Proses Tasarımı ve Güvenilirlik','Enstrümantasyon (sensör, aktüatör) doğruluğu ve kalibrasyon planı gözden geçirildi mi?',14,true),
    (v_set_id,'Proses Tasarımı ve Güvenilirlik','Elektrik yükü/kapasitesi (pano, kablo kesiti, koruma) değişiklikle uyumlu mu?',15,true),
    (v_set_id,'Proses Tasarımı ve Güvenilirlik','Yazılım/kontrol sistemi (PLC/SCADA) değişikliği varsa, mantık değişikliği bağımsız olarak test edildi mi?',16,true),
    (v_set_id,'Proses Tasarımı ve Güvenilirlik','Yedeklilik gerektiren kritik noktalarda tek nokta arıza riski değerlendirildi mi?',17,true),
    (v_set_id,'Proses Tasarımı ve Güvenilirlik','Malzeme uyumluluğu (korozyon, aşınma, kimyasal reaksiyon) kontrol edildi mi?',18,true),
    (v_set_id,'Proses Tasarımı ve Güvenilirlik','Proses değişikliğinin yukarı/aşağı akış ekipmanlarına etkisi incelendi mi?',19,true),
    (v_set_id,'Proses Tasarımı ve Güvenilirlik','Kapasite/debi değişikliği, mevcut boru/hat çapı ve pompa seçimiyle uyumlu mu?',20,true),
    (v_set_id,'Proses Tasarımı ve Güvenilirlik','Kritik ekipmanlar için bakım erişilebilirliği (valf, filtre, numune noktası) korunuyor mu?',21,true),
    (v_set_id,'Proses Tasarımı ve Güvenilirlik','Statik elektrik, topraklama ve patlayıcı ortam gereksinimleri gözden geçirildi mi?',22,true),
    (v_set_id,'Proses Tasarımı ve Güvenilirlik','Proses değişikliği sonrası ölçüm/izleme noktaları (basınç, sıcaklık, seviye) yeterli mi?',23,true),
    -- Çalışma Alanı Güvenliği (10)
    (v_set_id,'Çalışma Alanı Güvenliği','Hareketli parçalar için makine koruyucuları/bariyerler yeterli ve erişilebilir mi?',24,true),
    (v_set_id,'Çalışma Alanı Güvenliği','Gürültü seviyesi değişiklik sonrası çalışma alanı limitlerini aşıyor mu?',25,true),
    (v_set_id,'Çalışma Alanı Güvenliği','Elektrik izolasyonu ve kilitleme-etiketleme noktaları tanımlandı mı?',26,true),
    (v_set_id,'Çalışma Alanı Güvenliği','Gerekli kişisel koruyucu donanım ihtiyacı yeniden belirlendi mi?',27,true),
    (v_set_id,'Çalışma Alanı Güvenliği','Kaldırma ekipmanı (vinç, forklift, kaldıraç) kapasitesi yeni yüklerle uyumlu mu?',28,true),
    (v_set_id,'Çalışma Alanı Güvenliği','Yüksekte çalışma, dar alan gibi özel riskler değişiklikle ortaya çıkıyor mu?',29,true),
    (v_set_id,'Çalışma Alanı Güvenliği','Ergonomi (erişim yüksekliği, tekrarlayan hareket) değerlendirmesi yapıldı mı?',30,true),
    (v_set_id,'Çalışma Alanı Güvenliği','Manuel taşıma/kaldırma gereksinimleri değişiklik sonrası arttı mı?',31,true),
    (v_set_id,'Çalışma Alanı Güvenliği','Acil durdurma düğmeleri erişilebilir ve görünür konumda mı?',32,true),
    (v_set_id,'Çalışma Alanı Güvenliği','Yeni ekipman/alan için güvenlik eğitimi ihtiyacı belirlendi mi?',33,true),
    -- Yangın Kontrolü ve Acil Durum (9)
    (v_set_id,'Yangın Kontrolü ve Acil Durum','Yangın algılama (duman/ısı dedektörü) kapsama alanı yeni yerleşimi kapsıyor mu?',34,true),
    (v_set_id,'Yangın Kontrolü ve Acil Durum','Sabit/taşınabilir yangın söndürme sistemleri yeni riske uygun mu?',35,true),
    (v_set_id,'Yangın Kontrolü ve Acil Durum','Yanıcı/parlayıcı madde depolama mesafeleri ve miktar limitleri korunuyor mu?',36,true),
    (v_set_id,'Yangın Kontrolü ve Acil Durum','Acil durum aydınlatması ve yönlendirme işaretleri yeterli mi?',37,true),
    (v_set_id,'Yangın Kontrolü ve Acil Durum','Acil durum senaryoları (yangın, gaz kaçağı, dökülme) güncellendi mi?',38,true),
    (v_set_id,'Yangın Kontrolü ve Acil Durum','İtfaiye/acil müdahale ekiplerinin alana erişimi engellenmiyor mu?',39,true),
    (v_set_id,'Yangın Kontrolü ve Acil Durum','Yangın duvarları/bölmeleri değişiklikle delinmedi veya zayıflatılmadı mı?',40,true),
    (v_set_id,'Yangın Kontrolü ve Acil Durum','Gaz/kimyasal algılama sistemi kapsamı yeni ekipman için yeterli mi?',41,true),
    (v_set_id,'Yangın Kontrolü ve Acil Durum','Acil durum iletişim sistemi (anons, alarm) yeni alanda duyulabilir mi?',42,true),
    -- Çevresel Etkiler (8)
    (v_set_id,'Çevresel Etkiler','Değişiklik yeni bir emisyon kaynağı (hava, gürültü, koku) oluşturuyor mu?',43,true),
    (v_set_id,'Çevresel Etkiler','Atık türü/miktarında artış veya yeni atık kategorisi ortaya çıkıyor mu?',44,true),
    (v_set_id,'Çevresel Etkiler','Sızıntı/dökülme riski olan noktalarda ikincil koruma (bund, drenaj) yeterli mi?',45,true),
    (v_set_id,'Çevresel Etkiler','Atıksu deşarj kalitesi/miktarı değişiklikten etkileniyor mu?',46,true),
    (v_set_id,'Çevresel Etkiler','Gürültü seviyesi çevresel/yasal limitleri aşıyor mu?',47,true),
    (v_set_id,'Çevresel Etkiler','Tehlikeli madde depolama/taşıma koşulları çevresel mevzuata uygun mu?',48,true),
    (v_set_id,'Çevresel Etkiler','Enerji/su tüketiminde önemli bir artış bekleniyor mu?',49,true),
    (v_set_id,'Çevresel Etkiler','Çevre izinlerinde (emisyon, atık, deşarj) güncelleme gerekiyor mu?',50,true),
    -- Değişikliğin Gerçekleştirilmesi (9)
    (v_set_id,'Değişikliğin Gerçekleştirilmesi','Değişiklik için gerekli tüm onaylar tamamlanmadan işe başlanmıyor mu?',51,true),
    (v_set_id,'Değişikliğin Gerçekleştirilmesi','İş için görevlendirilen yüklenici/taşeronun yeterlilik/belge kontrolü yapıldı mı?',52,true),
    (v_set_id,'Değişikliğin Gerçekleştirilmesi','Uygulama sırasında geçici risk azaltıcı önlemler (bariyer, gözetim) planlandı mı?',53,true),
    (v_set_id,'Değişikliğin Gerçekleştirilmesi','Kurulum/imalat sırasında kalite kontrol noktaları (muayene, test) tanımlandı mı?',54,true),
    (v_set_id,'Değişikliğin Gerçekleştirilmesi','Devreye alma öncesi test ve muayene kayıtları (basınç testi, kalibrasyon vb.) tutulacak mı?',55,true),
    (v_set_id,'Değişikliğin Gerçekleştirilmesi','Değişiklik sırasında etkilenen ekipmanların geçici olarak devre dışı bırakılması planlandı mı?',56,true),
    (v_set_id,'Değişikliğin Gerçekleştirilmesi','İş izni (sıcak çalışma, yüksekte çalışma, kapalı alan) gereksinimleri belirlendi mi?',57,true),
    (v_set_id,'Değişikliğin Gerçekleştirilmesi','Değişiklikle ilgili teknik çizim/doküman güncellemesi kim tarafından yapılacak, netleşti mi?',58,true),
    (v_set_id,'Değişikliğin Gerçekleştirilmesi','Uygulama sonrası eski ekipman/malzemenin güvenli şekilde ortadan kaldırılması planlandı mı?',59,true),
    -- Operasyonel Hazırlık (9)
    (v_set_id,'Operasyonel Hazırlık','Kurulum sonrası fonksiyon/performans testi planı hazırlandı mı?',60,true),
    (v_set_id,'Operasyonel Hazırlık','Etkilenen çalışma talimatları/prosedürler güncellenip onaylandı mı?',61,true),
    (v_set_id,'Operasyonel Hazırlık','İlgili personel için değişiklik hakkında bilgilendirme/eğitim planlandı mı?',62,true),
    (v_set_id,'Operasyonel Hazırlık','Kritik yedek parça stoku yeni ekipman için oluşturuldu mu?',63,true),
    (v_set_id,'Operasyonel Hazırlık','Bakım planı (periyodik bakım, kalibrasyon takvimi) yeni ekipmanı kapsayacak şekilde güncellendi mi?',64,true),
    (v_set_id,'Operasyonel Hazırlık','Devreye alma sırasında izlenecek kritik parametreler ve kabul kriterleri tanımlandı mı?',65,true),
    (v_set_id,'Operasyonel Hazırlık','Vardiya/operasyon ekiplerine devreye alma zamanlaması önceden bildirildi mi?',66,true),
    (v_set_id,'Operasyonel Hazırlık','Değişiklik sonrası ilk dönem (deneme süresi) için ek gözetim planlandı mı?',67,true),
    (v_set_id,'Operasyonel Hazırlık','Devreye alma sonrası açık kalan aksiyonların takip sorumlusu belirlendi mi?',68,true);
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- SEED — Set 2: Gıda Güvenliği Etki Değerlendirmesi (global, opsiyonel,
-- kategori_id = "Ürün/Reçete Değişikliği"). Tenant'lar bu şablonu Ayarlar'dan
-- "Kullan" ile kendi tenant kopyalarına aktarana kadar devreye girmez.
-- ----------------------------------------------------------------------------
DO $$
DECLARE v_set_id BIGINT; v_kat_id BIGINT;
BEGIN
  SELECT id INTO v_kat_id FROM public.moc_change_categories WHERE tenant_id IS NULL AND code = 'PRODUCT_RECIPE';

  SELECT id INTO v_set_id FROM public.moc_etki_checklist_setleri
    WHERE tenant_id IS NULL AND kategori_id = v_kat_id AND ad = 'Gıda Güvenliği Etki Değerlendirmesi';

  IF v_set_id IS NULL AND v_kat_id IS NOT NULL THEN
    INSERT INTO public.moc_etki_checklist_setleri (tenant_id, kategori_id, ad, aciklama, aktif)
    VALUES (NULL, v_kat_id, 'Gıda Güvenliği Etki Değerlendirmesi',
      'Ürün/reçete değişikliklerinde gıda güvenliği yönetim sistemine etkiyi değerlendiren checklist. Yalnız bu kategoriyi kullanan tesisler, Ayarlar''dan aktifleştirdiğinde (Kullan) devreye girer.',
      true)
    RETURNING id INTO v_set_id;

    INSERT INTO public.moc_etki_checklist_maddeleri (set_id, bolum_baslik, soru_metni, sira_no, evet_aksiyon_gerekli) VALUES
    (v_set_id,'Gıda Güvenliği Etki Değerlendirmesi','Bu değişiklik mevcut HACCP planındaki kritik kontrol noktalarını etkiliyor mu?',1,true),
    (v_set_id,'Gıda Güvenliği Etki Değerlendirmesi','Bu değişiklik ön gereksinim programlarından (PRP) herhangi birini etkiliyor mu?',2,true),
    (v_set_id,'Gıda Güvenliği Etki Değerlendirmesi','Değişiklik yeni bir hammadde/girdi kullanımını gerektiriyor mu?',3,true),
    (v_set_id,'Gıda Güvenliği Etki Değerlendirmesi','Değişiklik yeni bir ekipman veya proses adımı ekliyor mu?',4,true),
    (v_set_id,'Gıda Güvenliği Etki Değerlendirmesi','Ürün spesifikasyonunda (bileşim, fiziksel/kimyasal özellikler) değişiklik oluyor mu?',5,true),
    (v_set_id,'Gıda Güvenliği Etki Değerlendirmesi','Ürünün raf ömrü/dayanıklılığı bu değişiklikten etkileniyor mu?',6,true),
    (v_set_id,'Gıda Güvenliği Etki Değerlendirmesi','Etiket veya ambalaj bilgisinde güncelleme gerekiyor mu?',7,true),
    (v_set_id,'Gıda Güvenliği Etki Değerlendirmesi','Alerjen profili (mevcut alerjenler, çapraz bulaşma riski) değişiyor mu?',8,true),
    (v_set_id,'Gıda Güvenliği Etki Değerlendirmesi','Bu değişiklik için müşteri bilgilendirmesi/onayı gerekiyor mu?',9,true),
    (v_set_id,'Gıda Güvenliği Etki Değerlendirmesi','Bu değişiklik yasal/mevzuat uyumluluğu açısından yeniden değerlendirme gerektiriyor mu?',10,true);
  END IF;
END $$;

COMMIT;

-- ============================================================================
-- GERİ ALMA (yalnız elle, gerekirse — bu script bunu ÇALIŞTIRMAZ)
-- ============================================================================
-- BEGIN;
-- DROP TABLE IF EXISTS public.moc_etki_checklist_yanitlari;
-- DROP TABLE IF EXISTS public.moc_etki_checklist_maddeleri;
-- DROP TABLE IF EXISTS public.moc_etki_checklist_setleri;
-- DELETE FROM public.moc_change_categories WHERE tenant_id IS NULL AND code = 'PRODUCT_RECIPE';
-- COMMIT;
-- ============================================================================
