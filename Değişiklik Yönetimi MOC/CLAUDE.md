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
- `moc_state_machine_v1.md`, `moc_rbac_matrix_v1.md`, `moc_schema_v1-1.sql`
  — orijinal planlama dosyaları (iş mantığı kaynağı). `MOC_Teknik_Taslak_
  v2-1.md`, `moc_api_endpoints_v1-1.md`, `moc_kodlama_prompt_sprint1-1.md`
  Node/Express/React varsayımıyla yazıldığı için **kullanılmadı** —
  yalnız kapsam/vizyon referansı olarak dursunlar.
- `TASARIM_STANDARDI.md` — renk/tipografi/bileşen standardı, MOC.html
  buna birebir uyar.
- `moc_theme_tokens.css`, `moc_wireframe_v1-2.html` — **kullanılmadı**
  (TASARIM_STANDARDI ile çelişen ayrı bir renk sistemi tanımlıyorlardı).

## Bilinen sınırlamalar / basitleştirmeler (Faz B)
1. **RBAC 3 kademeye indirgendi.** `moc_rbac_matrix_v1.md`'deki 14 ayrı
   izin kodu yerine platformun paylaşılan `profiles.role` kolonu
   (ADMIN/EDITOR/VIEWER) kullanılıyor — `canDo()` fonksiyonu bunu MOC
   aksiyonlarına eşliyor. Kayıt-seviyesi kurallar (kendi talebini
   onaylayamama, DRAFT'ı yalnız sahibi/koordinatör düzenler) tam
   uygulanıyor.
2. **Onaycı ataması yok.** `moc_approvals.approver_id` önceden atanmıyor;
   yetkili herhangi bir kullanıcı (talep sahibi hariç) kararı "üstlenerek"
   verir, karar anında approver_id kendine set edilir. Gerçek atama akışı
   (kullanıcı seçici) B2'de eklenebilir.
3. **Ayarlar ekranı salt-okunur.** Kategori/tür CRUD'u yok, sadece liste.
4. **Acil değişiklik** yalnız UI banner + retro_hours gösterimi; state
   machine'de ayrı bir "sözlü onay" adımı/alanı yok.
5. **Onay zinciri otomasyonu** (`moc_types.extra_approval_risk_threshold/
   role_code`) şema kolonları hazır ama UI'da henüz kullanılmıyor —
   onay adımları elle ekleniyor.
6. **Yeni RPC yok.** Tüm işlemler doğrudan `UPDATE`/`INSERT` + RLS ile
   yapılıyor. İleride bir `transition()` RPC'si gerekirse, 3 katmanlı
   izin kontrolünü unutma: (a) `GRANT EXECUTE ... TO authenticated`,
   (b) schema `USAGE` teyidi, (c) Supabase Dashboard → Data API →
   Settings → **Exposed Functions**'da fonksiyonu işaretle.

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
