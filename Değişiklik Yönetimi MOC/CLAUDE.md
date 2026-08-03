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
  (Taleplerim/Tüm Değişiklikler listelerindeki soft-delete için). Henüz
  Supabase'de UYGULANMADI (bkz. "Faz D" bölümü).
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
  cevap "Evet" verilirse `saveChecklistAnswer()` otomatik bir
  `moc_action_items` kaydı açar (`phase='PRE_APPROVAL'`). Bu aksiyon(lar)
  `DONE`/`CANCELLED` olmadan ve tüm checklist maddeleri yanıtlanmadan
  `TECHNICAL_REVIEW → APPROVAL` geçişi kilitli kalır (bkz.
  `condReadyForApproval()`).
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
- **DURUM:** Kod (`MOC.html`) ve şema (`moc_schema_faz_c.sql`) hazır,
  **Supabase'e henüz uygulanmadı, canlı test edilmedi.** Bir sonraki
  adım: `moc_schema_faz_c.sql`'i Supabase SQL Editor'da çalıştırıp,
  gerçek bir MOC talebinde Genel Risk seti otomatik göründüğünü, Ürün/
  Reçete kategorisi seçildiğinde Gıda seti "Kullan" edilmeden hiç
  görünmediğini, "Kullan" sonrası göründüğünü, "Evet" cevabının aksiyon
  açtığını ve o aksiyon kapanmadan APPROVAL'a geçilemediğini doğrulamak.

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

## Bilinen açık — "Onay Bekleyenler" listesi (henüz düzeltilmedi)
Kullanıcıya onay mekanizması açıklanırken fark edildi: `viewList('pending')`
sorgusu `moc_approvals` üzerinde `decision IS NULL AND approver_id =
cloudUserId` filtresi kullanıyor. Ancak `approver_id`, karar verilene kadar
hep `NULL` kalıyor (üstlenme modeli — bkz. madde 2) — yani decision NULL
olduğu sürece approver_id asla dolu olamaz. Sonuç: bu ekran şu anki
mimaride kimse için hiçbir zaman dolu gelmiyor; kullanıcılar bekleyen
onayları yalnız "Tüm Değişiklikler" listesinden tek tek MOC açarak
görebiliyor. Düzeltme istenirse ayrı bir iş olarak ele alınmalı (muhtemel
çözüm: role_code eşleşmesine göre filtrelemek, approver_id'ye bakmadan).

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
