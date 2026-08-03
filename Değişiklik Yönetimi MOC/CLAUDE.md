# MOC (Değişiklik Yönetimi) — Proje Notları

## Ne bu
Endüstriyel değişiklik yönetimi (Management of Change) modülü. Tek dosya
HTML (`MOC.html`), build yok — Ekipman/Gıda/Q-Tedarikçi/Q-Kalite ile aynı
desen. Bağımsız modül; ekipman modülüne yumuşak referansla (equipment_id
veya asset_ref serbest metin) bağlanır, ekipman modülü olmadan da çalışır.

## Supabase
- Proje: Ekipman Yönetimi projesi (**bbltvuxxtacrpgrqnfoh**) — ayrı proje
  değil, tabloları `moc_` önekiyle aynı projeye eklendi.
- Auth: `profiles(id, tenant_id, full_name, role, is_active)` +
  `modul_yetki(user_id, modul)` — `modul='moc'` satırı olmayan kullanıcı
  girişten sonra reddedilir (bkz. `afterLogin()`).
- RLS: `public.current_tenant_id()` (platformda zaten var, profiles
  tabanlı) doğrudan kullanılıyor. Çok-lokasyon/çatı-alt firma hiyerarşisi
  (`ggd_gorulebilir_tenantlar()` benzeri union deseni) MOC'ta ŞİMDİLİK
  AKTİF DEĞİL — basit `tenant_id = current_tenant_id()`. `moc_requests.
  location_id` kolonu bu amaçla rezerve, nullable, UI'da kullanılmıyor.

## Dosyalar
- `MOC.html` — uygulamanın kendisi (tek dosya).
- `moc_schema_faz_a.sql` — Faz A'da çalıştırılan tablo/RLS/seed script'i
  (idempotent, zaten Supabase'de uygulandı).
- `moc_schema_faz_b_moc_no.sql` — Faz B canlı test sırasında bulunan
  moc_no eksikliğinin düzeltmesi (bkz. "Faz B doğrulama" altında),
  zaten Supabase'de uygulandı.
- `moc_schema_faz_b2.sql` — Faz B2: `moc_change_categories`/`moc_types`
  için INSERT/UPDATE RLS politikaları + GRANT (Ayarlar CRUD'u için).
  Supabase'de uygulandı, canlı test edildi (bkz. "Faz B2 doğrulama").
- `moc_state_machine_v1.md`, `moc_rbac_matrix_v1.md`, `moc_schema_v1-1.sql`
  — orijinal planlama dosyaları (iş mantığı kaynağı), B/B2 basitleştirmelerini
  yansıtacak şekilde güncellendi (03.08.2026): state machine'e PSSR atlama
  kuralı, rbac_matrix'e gerçek 3-kademeli `canDo()` modeli + onaycı
  üstlenme notu (§6), schema dosyasına faz_b2 kolon/RLS farkları eklendi.
  `MOC_Teknik_Taslak_v2-1.md`, `moc_api_endpoints_v1-1.md`,
  `moc_kodlama_prompt_sprint1-1.md` Node/Express/React varsayımıyla
  yazıldığı için **kullanılmadı/ARŞİV** — yalnız kapsam/vizyon referansı
  olarak dursunlar.
- `moc_schema_faz_c.sql` — Faz C: Etki Değerlendirme Checklist Sistemi
  (`moc_etki_checklist_setleri`/`_maddeleri`/`_yanitlari` + RLS/GRANT +
  2 hazır global set seed'i). Henüz Supabase'de UYGULANMADI — bu script
  canlıya alınmayı bekliyor (bkz. "Faz C" bölümü).
- `moc_schema_faz_d.sql` — Faz D: `moc_requests.deleted_at` kolonu
  (Taleplerim/Tüm Değişiklikler listelerindeki soft-delete için). Faz C ile
  birlikte Supabase'e uygulandı, canlı test edilmedi (bir sonraki oturumda
  senaryo doğrulanmalı, bkz. "Faz D" bölümü).
- `moc_schema_faz_e.sql` — Faz E: Maliyet Takibi. `moc_requests`'e
  `para_birimi`/`baslangic_maliyeti`/`tamamlanma_sonrasi_maliyet` +
  GENERATED STORED `sapma_tutari`/`sapma_yuzdesi` kolonları. Henüz
  Supabase'e UYGULANMADI (bkz. "Faz E" bölümü).
- `TASARIM_STANDARDI.md` — renk/tipografi/bileşen standardı, MOC.html
  buna birebir uyar.
- `moc_theme_tokens.css`, `moc_wireframe_v1-2.html` — **kullanılmadı**
  (TASARIM_STANDARDI ile çelişen ayrı bir renk sistemi tanımlıyorlardı).

## Bilinen sınırlamalar / basitleştirmeler (Faz B / B2)
1. **RBAC 3 kademeye indirgendi.** `moc_rbac_matrix_v1.md`'deki 14 ayrı
   izin kodu yerine platformun paylaşılan `profiles.role` kolonu
   (ADMIN/EDITOR/VIEWER) kullanılıyor — `canDo()` fonksiyonu bunu MOC
   aksiyonlarına eşliyor. Kayıt-seviyesi kurallar (kendi talebini
   onaylayamama, DRAFT'ı yalnız sahibi/koordinatör düzenler) tam
   uygulanıyor.
2. **Onaycı ataması yok (bilinçli tercih, B2'de tekrar sorgulandı).**
   `moc_approvals.approver_id` önceden atanmıyor; yetkili herhangi bir
   kullanıcı (talep sahibi hariç) kararı "üstlenerek" verir, karar anında
   approver_id kendine set edilir. B2 planlamasında kullanıcıya bu model
   mi yoksa belirli-kişi-atama modeli mi istendiği soruldu — **üstlenme
   modelinin korunması** seçildi, değişiklik yapılmadı.
3. **Ayarlar ekranı artık CRUD destekliyor (B2, canlı test edildi).**
   Kategori/tür ekleme-düzenleme `viewSettings()`/`openCategoryModal()`/
   `openTypeModal()` ile yapılıyor. Kurallar: yalnız kendi tenant'ınıza
   ait satırlar düzenlenebilir (global/tenant_id NULL satırlar salt-okunur
   gösterilir, RLS zaten bunu zorluyor — bkz. `moc_schema_faz_b2.sql`);
   silme yok, yalnız soft-delete (`is_active` toggle) — kullanılmış
   türler/kategoriler asla fiziksel silinemez.
4. **Acil değişiklik** yalnız UI banner + retro_hours gösterimi; state
   machine'de ayrı bir "sözlü onay" adımı/alanı yok.
5. **Onay zinciri otomasyonu (B2'de eklendi, canlı test edildi).**
   `moc_types.extra_approval_risk_threshold`/`extra_approval_role_code`
   Ayarlar'dan düzenlenebilir ve `ensureRiskThresholdApproval()` ile
   kullanılıyor: `TECHNICAL_REVIEW → APPROVAL` geçişinde, herhangi bir
   risk kaydının `risk_after`'ı eşiği geçerse ve o role_code için henüz
   adım yoksa, otomatik bir onay adımı sona ekleniyor (Q-Tedarikçi Faz F
   basit eşik deseniyle aynı ruhta — RPC yok, client-side kontrol).
6. **Yeni RPC yok.** Tüm işlemler doğrudan `UPDATE`/`INSERT` + RLS ile
   yapılıyor. İleride bir `transition()` RPC'si gerekirse, 3 katmanlı
   izin kontrolünü unutma: (a) `GRANT EXECUTE ... TO authenticated`,
   (b) schema `USAGE` teyidi, (c) Supabase Dashboard → Data API →
   Settings → **Exposed Functions**'da fonksiyonu işaretle.

## UI Yeniden Düzenleme — Üst Kart Menü + Dashboard + Faz E Maliyet Takibi (03.08.2026)
- **Menü etiketi:** "Taleplerim" → "Değişiklik Talepleri" (yalnız etiket,
  `go('mine')`/`viewList('mine')` işlevi aynı). "Onay Bekleyenler"
  bilinçli olarak değiştirilmedi.
- **Sol dikey menü kaldırıldı, üst yatay kayan kart menüye geçildi:**
  `aside.side` tamamen silindi (eski collapse/localStorage mantığı da
  kaldırıldı — `moc_nav_collapsed` artık kullanılmıyor). `renderNav()`
  artık `.navcard` sınıfıyla `#snav`'i (`div.cardnav`, `overflow-x:auto`)
  dolduruyor; `TASARIM_STANDARDI` renk/tipografi tokenlarına (`--leaf`,
  `--mint`, `--card` vb.) birebir uyuyor, yeni renk eklenmedi. Mobilde de
  yatay scroll ile kartlara erişim korunuyor (`.cardnav` dar ekranda
  otomatik kaydırılabilir kalıyor, medya sorgusu gerekmedi).
- **Kart görünümü iki turda ince ayar edildi (kullanıcı ekran görüntüsü
  referans alınarak, 03.08.2026):** İlk turda kartlar büyütülüp emoji
  ikon + başlık aynı satırda alt-bantta gösterildi; kullanıcı geri
  bildirimiyle ("yazılar/simgeler üst üste gelmesin, ekrandaki gibi
  ayrı olsun") ikinci turda nihai düzene geçildi — **başlık solda dikey
  ortalı, ikon sağda ayrı 46×46 kutuda** (`navcard`/`lbl`/`card-ico`),
  metin ve ikon hiçbir genişlikte çakışmıyor. Emoji yerine `NAV_ICONS`
  objesindeki gradyanlı **inline SVG "3B" ikonlar** kullanıldı (bar
  grafik, pano, onay kalkanı, klasör, dişli) — gerçek fotoğraf/dış
  görsel dosyası KULLANILMADI (tek dosya + build yok kısıtı, dış görsel
  bağımlılığı istenmiyor); glossy/3B izlenimi SVG gradyan dolgularla
  taklit edildi. Tüm kartlar aynı koyu gradyan arka plana sahip, seçili
  kart yeşil glow/kenarlıkla (`--leaf`) vurgulanıyor.
- **Dashboard ("Genel Bakış") yeni bir nav kartı/görünüm olarak eklendi**
  (`viewDashboard()`/`renderDashboardHtml()`) ve giriş sonrası varsayılan
  ekran oldu (`afterLogin` artık `go('dashboard')` çağırıyor, eskiden
  `go('mine')`). Kartların ALTINDA sürekli değil, kendi başına bir
  görünüm olarak tasarlandı — diğer ekranlarda (liste/detay/ayarlar) yer
  kaplamıyor. İçerik: açık MOC / bende onay bekleyen / toplam başlangıç
  bütçesi / toplam sapma KPI'ları (mevcut `.kpi`/`.kpis` CSS sınıfları
  kullanıldı, yeni bileşen eklenmedi), kategoriye göre açık MOC dağılımı
  (basit CSS çubuk grafik, `.barrow`/`.barfill` — recharts/React
  eklenmedi, tek-dosya/build-yok kısıtı gereği), ve T-7/süresi geçmiş
  geçici değişiklikler listesi (`tempWarnPill` yeniden kullanıldı).
- **Faz E — Maliyet Takibi** (`moc_schema_faz_e.sql`, Supabase'e henüz
  UYGULANMADI): `moc_requests.para_birimi` (TRY/USD/EUR/GBP, CHECK
  constraint) + `baslangic_maliyeti`/`tamamlanma_sonrasi_maliyet` +
  `sapma_tutari`/`sapma_yuzdesi` (ikisi de `GENERATED ALWAYS AS ... STORED`
  — istemci asla yazmaz, DB hesaplar, tutarsızlık imkansız). Başlangıç
  maliyeti yeni talep formunda girilir; tamamlanma sonrası maliyet detay
  sayfasındaki "Maliyet Takibi" panelinden (`renderCostPanel`/
  `openEditCost`, yalnız `canDo('coordinate')`) veya kısıtlı-düzenleme
  modalından girilir.
- **Kur çevrimi — Frankfurter API** (`https://api.frankfurter.app`, ECB
  referans kurları, ücretsiz, API key yok): `fetchExchangeRates()` girişten
  sonra bir kez `base=TRY&symbols=USD,EUR,GBP` ile çekiliyor,
  `EXCHANGE_RATES` içinde önbelleğe alınıyor. **CORS testi yapıldı, sorun
  yok** — servis genel kullanım için tasarlanmış, tarayıcıdan doğrudan
  `fetch()` ile erişilebiliyor. TRY, ECB kapsamında zaten mevcut (ayrı bir
  alternatif servise gerek kalmadı). Çevrim şeffaf gösteriliyor
  (`fmtCostTRY`: "X USD, güncel kurla ~Y TRY"); servis erişilemezse ham
  değer gösterilir, TRY karşılığı "kur alınamadı" olarak işaretlenir —
  sessizce yanlış rakam üretilmiyor. Dashboard'daki toplam bütçe/sapma
  KPI'ları da aynı önbelleğe alınmış kurla hesaplanıyor; kur çekilemediyse
  KPI başlığına "*" ekleniyor ve altına uyarı notu düşülüyor.
- **DURUM:** Kod (`MOC.html`) hazır, JS söz dizimi doğrulandı (`node
  --check`). `moc_schema_faz_e.sql` **Supabase'e henüz uygulanmadı**,
  yeni maliyet formu/panel canlı test edilmedi. Bir sonraki adım:
  script'i çalıştırıp yeni talepte başlangıç maliyeti girmeyi, detaydan
  tamamlanma sonrası maliyeti girip sapmanın otomatik hesaplandığını,
  TRY dışı bir para biriminde kur çevriminin dashboard'a ve panele doğru
  yansıdığını doğrulamak.

## Faz C — Etki Değerlendirme Checklist Sistemi (kod hazır, SQL uygulanmayı bekliyor)
- **Mimari:** `moc_etki_checklist_setleri` (set — `kategori_id` NULL=her
  MOC'ta zorunlu, dolu=yalnız o kategoride; `tenant_id` NULL=global şablon,
  dolu=tesis kopyası) → `moc_etki_checklist_maddeleri` (bölüm/soru/sıra/
  "evet_aksiyon_gerekli") → `moc_etki_checklist_yanitlari` (MOC başına,
  madde başına tek yanıt EVET/HAYIR/NA + gerekçe + varsa oluşan `action_id`).
- **Tetikleme mantığı** (`applicableChecklistSets()`, `MOC.html`): zorunlu
  setler (kategori_id NULL) global halleriyle doğrudan her tenant'ta
  devreye girer; kategoriye bağlı setler yalnız tenant kendi kopyasını
  (`tenant_id` = kendisi) Ayarlar'dan "Kullan" ile oluşturduysa devreye
  girer — global şablonu hiç kopyalamayan tesisler o checklist'i asla
  görmez, kategoriyi seçseler bile.
- **Otomatik aksiyon:** bir maddede `evet_aksiyon_gerekli=true` iken
  cevap "Evet" verilirse `commitChecklistAnswer()` otomatik bir
  `moc_action_items` kaydı açar (`phase='PRE_APPROVAL'`). Bu aksiyon(lar)
  `DONE`/`CANCELLED` olmadan ve tüm checklist maddeleri yanıtlanmadan
  `TECHNICAL_REVIEW → APPROVAL` geçişi kilitli kalır (bkz.
  `condReadyForApproval()`).
- **Hızlı yanıt UI'ı (03.08.2026 ince ayar):** modal yerine satır-içi tek-
  tık Evet/Hayır/N-A chip'leri (`renderChecklistRow()`). Gerekçe kutusu
  varsayılan GİZLİ, yalnız "Evet" chip'ine basılınca açılır ve otomatik
  odaklanır (gerekçe zorunluluğu aynen korunuyor — boş gerekçeyle
  kaydedilemiyor). "Hayır"/"N-A" tek tıkla anında kaydediliyor, gerekçe
  kutusu açılmıyor (istenirse "+ Not ekle" linkiyle sonradan eklenebilir).
  Kaydetme sonrası artık `viewDetail()` ile TÜM sayfa yeniden çekilmiyor —
  yalnız checklist ve durum geçişi panelleri yerinde güncelleniyor
  (`refreshChecklistAndTransitions()`), bu da 68 maddelik setlerde ciddi
  hız kazandırıyor. Bir madde kaydedildikten sonra `focusNextChecklistItem()`
  otomatik bir sonraki yanıtsız maddeye kaydırıyor.
- **Ayarlar CRUD:** yeni "Etki Değerlendirme Checklist Setleri" paneli —
  tenant'a özel setlerde "Maddeleri Yönet" (madde ekle/düzenle/pasifleştir),
  global zorunlu sette "Kopyala ve Özelleştir", global opsiyonel sette
  "Kullan" butonu. Silme yok, yalnız soft-delete (`aktif`/`is_active`).
- **Seed (2 hazır global set):** "Genel Risk Değerlendirme Checklist'i"
  (68 madde, 7 bölüm, zorunlu, kategori bağımsız) ve "Gıda Güvenliği Etki
  Değerlendirmesi" (10 madde, yeni eklenen "Ürün/Reçete Değişikliği"
  kategorisine bağlı, opsiyonel). Sorular harici saha güvenliği/risk
  değerlendirmesi kaynak dokümanlarının KAPSAMINDAN esinlenerek özgün
  cümlelerle yazıldı; hiçbir kaynak standart/kurum adı kodda, seed
  data'da veya yorum satırlarında geçmiyor (bkz. `moc_schema_faz_c.sql`
  başlık notu, grep ile teyit edildi).
- **DURUM:** Kod (`MOC.html`) ve şema (`moc_schema_faz_c.sql`)
  Supabase'e UYGULANDI (03.08.2026), **henüz canlı senaryo adım adım
  doğrulanmadı.** Bir sonraki adım: gerçek bir MOC talebinde Genel Risk
  seti otomatik göründüğünü, Ürün/Reçete kategorisi seçildiğinde Gıda
  seti "Kullan" edilmeden hiç görünmediğini, "Kullan" sonrası
  göründüğünü, "Evet" cevabının aksiyon açtığını ve o aksiyon
  kapanmadan APPROVAL'a geçilemediğini doğrulamak.

## Faz D — Taleplerim/Tüm Değişiklikler: Düzenle + Sil (kod hazır, SQL uygulanmayı bekliyor)
- **Yetki (`canManageRequest()`):** koordinasyon izni olan (EDITOR/ADMIN)
  herhangi bir talebi yönetebilir; VIEWER kendi talebi olsa dahi
  yönetemez (talep OLUŞTURMA taban izindir, düzenleme/silme değil).
- **Düzenle:** `DRAFT` durumunda tüm alanlar açık (mevcut talep formu).
  `DRAFT` dışındaki (terminal olmayan) durumlarda yalnız başlık/açıklama/
  gerekçe düzenlenebilir — kategori/tür/öncelik/planned_end gibi
  checklist ve onay zincirini belirleyen alanlar kilitli, snapshot
  bozulmasın diye. Terminal durumda (`CLOSED`/`REJECTED`/`CANCELLED`)
  düzenleme tamamen engelli.
- **Sil (Q-Tedarikçi Faz D.1 ile aynı desen):** açık aksiyon
  (`moc_action_items`, `status NOT IN ('DONE','CANCELLED')`) varsa
  engellenir. `DRAFT` durumunda (henüz hiçbir onay/işlem başlamamış)
  KALICI silme serbest — alt tablolar `ON DELETE CASCADE`. Diğer tüm
  durumlarda yalnız `deleted_at` ile gizlenir (soft-delete), geçmiş
  korunur; geri getirmek gerekirse SQL'den `deleted_at=NULL` — ayrı bir
  "Geri Dönüşüm" ekranı yok, kapsam dışı bırakıldı.
- **DURUM:** Kod (`MOC.html`) hazır, `moc_schema_faz_d.sql`
  **Supabase'e henüz uygulanmadı.** Bir sonraki adım: script'i çalıştırıp
  DRAFT'ta kalıcı silmeyi, ilerlemiş durumda soft-delete'i, açık aksiyon
  varken silme engelini ve kısıtlı/tam düzenleme modlarını canlı test
  etmek.

## Onay Zinciri — SIRALI (sequential) model + "Onay Bekleyenler" düzeltmesi (03.08.2026)
Önceki tur "Onay Bekleyenler" listesinin hep boş geldiğini ve `step_order`'ın
sadece etiket olup gating yapmadığını bulmuştu (paralel onay). Kullanıcıyla
netleştirildi: onay zinciri **sıralı** olmalı — bu kritik bir düzeltme
olarak uygulandı, yeni özellik değil.

1. **Kök sebep (Onay Bekleyenler boş geliyordu):** `viewList('pending')`
   sorgusu `decision IS NULL AND approver_id = cloudUserId` filtreliyordu.
   `approver_id`, karar verilene kadar hep `NULL` kalıyor (üstlenme modeli)
   — yani decision NULL olduğu sürece approver_id asla dolu olamıyordu,
   ekran kimse için hiç dolmuyordu. **Düzeltme:** sorgu artık tüm
   `moc_approvals` satırlarını `moc_requests` ile birlikte çekip, her MOC
   için `activeApprovalStep()` ile sıradaki aktif adımı buluyor, o adımı
   kararlaştırma yetkisi olan (talep sahibi değil, VIEWER değil, başka
   birine kilitli değil) kullanıcılara gösteriyor.
2. **Sıralı gating (`activeApprovalStep()`, MOC.html):** `step_order`'a göre
   sıralanmış listede ilk kararı verilmemiş satır "aktif adım"dır — ondan
   önceki TÜM adımlar `APPROVED` olmadan bir sonraki adım ne görünür ne de
   kararlaştırılabilir. `canDecideApproval()` artık bunu zorunlu kılıyor;
   Onay Zinciri panelinde aktif olmayan bekleyen adımlar "Kilitli — önceki
   adım(lar) tamamlanmadı" pili ile ayrı gösteriliyor (aktif adım "Bekliyor
   (sıradaki adım)"). Zincirde bir REJECTED/RETURNED varsa (mevcut
   `checkApprovalAuto` zaten MOC'u APPROVAL dışına çıkarır) aktif adım
   yoktur.
3. **Şema değişikliği YOK** — `step_order`/`approver_id`/`decision` zaten
   mevcuttu, düzeltme tamamen `MOC.html` içinde (yeni SQL dosyası yok).
4. **Manuel test senaryosu (canlı doğrulama için):**
   a. Bir MOC'u `TECHNICAL_REVIEW`'a kadar ilerletin, checklist'i
      tamamlayın, `APPROVAL`'a geçirin.
   b. Onay Zinciri panelinden "+ Onay Adımı Ekle" ile sırayla 3 adım
      ekleyin (ör. step 1=HSE, step 2=ENGINEERING, step 3=PLANT_MANAGER).
   c. Sayfayı yenileyip tekrar açın: yalnız **step 1 (HSE)** "Bekliyor
      (sıradaki adım)" etiketiyle ve Onayla/İade/Reddet butonlarıyla
      görünmeli; step 2 ve 3 "Kilitli" etiketiyle, butonsuz görünmeli.
   d. "Onay Bekleyenler" ekranını açın: talep sahibi olmayan, EDITOR/ADMIN
      rolündeki bir kullanıcı için yalnız step 1 satırı listelenmeli.
   e. Step 1'i Onayla — sayfa yenilenince step 2 artık aktif ("Bekliyor",
      butonlu) olmalı, step 3 hâlâ kilitli kalmalı; "Onay Bekleyenler"
      artık step 2'yi göstermeli.
   f. Step 2'yi Onayla, ardından step 3'ü Onayla — üçü de APPROVED olunca
      MOC otomatik `IMPLEMENTATION`'a geçmeli.
   g. Ayrı bir senaryoda step 2'yi step 1'den ÖNCE onaylamayı deneyin
      (`canDecideApproval` false döner, buton zaten görünmüyor — DB'ye
      doğrudan istekle zorlanırsa RLS tenant izolasyonunu geçer ama
      client mantığı engeller; RLS seviyesinde ayrı bir CHECK constraint
      **eklenmedi**, bilinçli — client-side kontrol yeterli görüldü, aynı
      MOC'un diğer client-side kurallarıyla (canDo, condActionsDone vb.)
      tutarlı).
   **DURUM:** Kod hazır, henüz canlı ortamda adım adım doğrulanmadı —
   yukarıdaki senaryo bir sonraki oturumda çalıştırılmalı.

## Durum makinesi
`MOC.html` içindeki `TRANSITIONS` objesi `moc_state_machine_v1.md` §3
geçiş matrisinin JS karşılığıdır — tek doğruluk kaynağı o dosya, kod
onunla çelişirse dosya esas alınır ve kod düzeltilir.

## Faz B doğrulama (canlı test — tamamlandı)
- **moc_no eksikliği bulundu ve düzeltildi:** `moc_requests.moc_no`
  NOT NULL idi ama üretim mantığı hiç yazılmamıştı — Faz A şemasının
  sonundaki "SONRAKİ ADIMLAR" yorumunda madde olarak listelenip
  unutulmuştu. Düzeltme: `moc_schema_faz_b_moc_no.sql` — BEFORE INSERT
  trigger (`moc_generate_no`, SECURITY DEFINER) + tenant/yıl bazlı
  atomik sayaç tablosu (`moc_no_counters`, authenticated'a GRANT yok),
  format `MOC-YYYY-NNNN`. Uygulama kodunda değişiklik gerekmedi.
  **Kalıcı ders:** şema dosyalarındaki "sonraki adımlar / TODO" notları
  bir sonraki fazda mutlaka tek tek kontrol edilmeli — kolayca
  unutulup NOT NULL/constraint hatası olarak canlıda ortaya çıkabiliyor.
- **Test edilip geçen akışlar:** talep oluşturma, durum makinesi
  geçişleri, kendi talebini onaylayamama kuralı, acil/geçici rozetler,
  PSSR gerekmeyen türlerde direkt STARTUP geçişi, rollback
  (previous_moc_id ile yeni MOC oluşturma).
- **Kullanıcı erişimi manuel adım:** Yeni bir kullanıcının MOC'a
  girebilmesi için `modul_yetki` tablosuna `(user_id, modul='moc')`
  satırı elle eklenmesi gerekiyor (bkz. §Auth) — bu adım otomatik
  değil, yeni kullanıcı/tenant eklerken unutulmamalı.

## Faz B2 doğrulama (canlı test — tamamlandı)
- **Ayarlar CRUD:** kategori ve akış türü (`moc_types`) ekleme/düzenleme
  test edildi — kod, ad (TR/EN), ekipman bağlantısı, PSSR gerekliliği,
  bitiş tarihi gerekliliği, geriye dönük süre, risk eşiği/rol kodu
  alanları sorunsuz kaydediliyor. Global (tenant_id NULL) satırlar
  beklendiği gibi salt-okunur kaldı, yalnız tenant'a özel satırlar
  düzenlenebildi.
- **Soft-delete koruması:** pasifleştirme (`is_active=false`) test
  edildi, fiziksel silme yolu yok (UI'da hiç sunulmuyor) — kullanılmış
  tür/kategoriler güvende.
- **Risk eşiğine göre otomatik ek onay:** `extra_approval_risk_threshold`/
  `extra_approval_role_code` tanımlı bir türde, eşiği aşan bir risk
  kaydıyla `TECHNICAL_REVIEW → APPROVAL` geçişi tetiklendiğinde
  `ensureRiskThresholdApproval()` otomatik onay adımını doğru şekilde
  ekledi; eşik aşılmadığında veya adım zaten varsa tekrar eklemedi.
- **Onaycı akışı ("üstlenme" modeli):** mevcut model (atama yok,
  yetkili herhangi bir kullanıcı kararı üstlenerek veriyor) korunduğu
  haliyle test edildi, sorunsuz.
