# MOC (Değişiklik Yönetimi) — Proje Notları

---

## ⚡ BURADAN BAŞLA — 07.09.2026 itibarıyla durum

**DOC_UPDATE ve TRAINING adımları artık GERÇEK, canlıda (commit `0ceaa72`).** Daha önce
bu iki adım içi boş / koşulsuz geçiliyordu. Model: **"MOC doğrular, Doküman Yönetimi
uygular"** — MOC içine ikinci bir doküman/eğitim sistemi yazılmadı.
- **DOC_UPDATE:** etkilenen doküman(lar) Doküman Yönetimi'nden (`ggd_sablonlar`, ortak
  Supabase projesi) seçilip `moc_documents` (`doc_kind='AFFECTED_DOC'`, `doc_ref`=şablon
  id, `old_version`=o anki versiyon no) ile fotoğraflanıyor. `computeAffectedDocStatus()`
  canlı `ggd_sablonlar.versiyon_no/durum`'u fotoğrafla kıyaslayıp Güncellenmedi/Taslakta
  Bekliyor/Yürürlükte gösteriyor. Hepsi Yürürlükte olmadan `TRAINING`'e geçilemiyor.
- **TRAINING:** şemada duran ama hiç kullanılmayan `moc_trainings` (user_id/training_type/
  acknowledged) tablosu hayata geçirildi — kişi ataması yapılır, `acknowledged=true`
  olmadan bir sonraki aşamaya (`PSSR`/`STARTUP`) geçilemez.
- **Cross-module RLS:** `ggd_sablonlar`'a `has_modul('moc')` için ek (OR'lanan, mevcut
  politikaları bozmayan) bir SELECT politikası eklendi (`Doküman Yönetimi/sql/
  13_moc_cross_module_erisim.sql`).
- **DB-seviyesi kilit (Faz K, `moc_schema_faz_k_doc_training_trigger.sql`):** yukarıdaki
  iki kural yalnız istemcide kalmasın diye `moc_durum_kontrol()` trigger'ına da eklendi —
  konsoldan/API'den doğrudan `UPDATE ... SET status=...` ile de bu adımlar atlanamaz.
- **Eğitim Platformu'na henüz bağlanmadı** (bilinçli, kullanıcı kararı): o modül henüz
  Eksenpro projesinde canlı tabloya sahip değil. Eğitim Platformu canlıya alınınca ayrı
  bir iş olarak gerçek eğitim kayıtlarına bağlanması değerlendirilebilir.

---

## ⚡ ÖNCEKİ DURUM — 05.09.2026 itibarıyla durum

**Modül canlı:** `moc.qdataline.com` · repo `qdataline-moc` · dal **`master`** · tek dosya
`MOC.html`, build yok · Cloudflare Pages. Sayfa kök `_redirects` ile
`/Değişiklik Yönetimi MOC/MOC.html`'e yönleniyor (klasör adı Türkçe karakterli; `curl` ile test
ederken yolu yüzde-kodlamak ve tarayıcı user-agent'ı vermek gerekir, yoksa 403/404 alırsın —
site sağlam olduğu hâlde bozuk sanılabilir, bu tuzağa bir kez düşüldü).

**BEKLEYEN SQL YOK.** Faz A–H hepsi canlıda. **Faz D/E/F/G için aşağıda "uygulanmadı" yazan
eski notlar YANLIŞTIR** — canlı şema sorgulandı, dördü de uygulanmış durumda (`deleted_at`,
`para_birimi`, `sapma_*` GENERATED, `tetik_tipi`, `tetikleyen_cevap` mevcut). O notlar tarihsel
kayıt olarak bırakıldı; güncel durum burasıdır.

### ✅ RAKİP ANALİZİNİN 5 EKSİĞİNİN TAMAMI KAPATILDI (Faz I/J, commit `0df410c`)
Aşağıdaki "SIRADAKİ İŞ" listesinin beşi de yapıldı — ayrıntı en altta Faz I/J bölümünde.
**BEKLEYEN TEK ŞEY: TARAYICI TESTİ.** Kullanıcı hiçbirini ekranda denemedi.

**Kullanıcının ekranda denemesi gerekenler:**
1. **Ek Dosyalar paneli** — bir talebe dosya ekle, indir; yönetici olarak sil.
2. **İşlem Geçmişi paneli** — bir alanı değiştirip kaydet, geçmişte `eski → yeni` satırı çıkmalı.
3. **Geçici Değişiklik Takibi** — `requires_end_date` olan bir türde: "Süreyi Uzat" (gerekçe
   zorunlu, uzatma geçmişine yazılmalı) ve "Eski Duruma Dönüldü".
4. **Denetim Dosyası** — sağ kolondaki 🖨 düğmesi; yazdırma penceresi açılmalı.
5. **Onay adımsız APPROVAL** artık engellenmeli; PSSR "serbest bırakma" sonrası tekrar PSSR'a
   gelince karar düğmeleri YENİDEN görünmeli (eski hâlinde kilitleniyordu).
6. **Arama kutusu** — üstteki kutuya MOC no/başlık yaz, liste süzülmeli (eskiden ölüydü).
7. **Günlük mail** — sabah ~09:20'de gelmeli. ⚠️ Yalnız MOC yetkisi olan ADMIN/EDITOR
   kullanıcılara ve **yalnız o kişinin yapacağı iş varsa** gider.

### 🔴 ESKİ SIRADAKİ İŞ LİSTESİ (tamamlandı, tarihsel kayıt)
05.09.2026'da rakip analizi + uçtan uca denetim yapıldı (26 bulgu), **en kritik 3 iş tamamlandı**
(aşağıda Faz H). Kalan işler önem sırasıyla:

1. **Ek dosya / fotoğraf ekleme** — `moc_documents` tablosu hazır, arayüz hiç yazılmamış. Bir
   talebe teknik resim, teklif ya da fotoğraf eklenemiyor; denetimde dosya delilsiz görünüyor.
2. **Otomatik bildirim ve hatırlatma** — sistem kimseye haber vermiyor; onay bekleyen kişi
   ekrana girmedikçe sırasının geldiğini bilmiyor. Ortak Resend altyapısı ve `moc_notifications`
   tablosu hazır (bkz. Tedarikçi ve Q-Kalite modülleri).
3. **Talep geçmişi ekranı** — `moc_audit_log` trigger'la zaten doluyor, okuma yetkisi var,
   gösteren panel yok. En yüksek fayda/efor oranlı iş.
4. **Denetim dosyası çıktısı** — tek talebin tam dökümü, yazdırılabilir tek sayfa.
5. **Geçici değişikliğin kapanışı** — `moc_temporary_tracking` yaz-ama-hiç-okuma durumunda;
   `restored_at`/`extension_*` kolonları kullanılmıyor, geri dönüş ve uzatma akışı yok.

**Kapatılmamış, bilinen açıklar:** `moc_documents`/`moc_trainings`/`moc_equipment` kullanılmadığı
için `DOC_UPDATE` ve `TRAINING` adımları **içi boş** (koşulsuz geçiliyor); risk önlem alanı
kontrolü yok — durum makinesi dosyası bu üç koşulu tanımlıyor, kod uygulamıyor. `evidence_hash`
kanıt değeri taşımıyor (anahtarsız, doğrulanmıyor). Tablolarda `overflow-x` yok, 7 kolonlu liste
dar ekranda taşıyor. Soft-delete edilmiş kaydın detayı doğrudan id ile hâlâ açılabiliyor.

**Düzeltilmiş bir yanlış belge:** Bu dosya "ekipman modülüne `equipment_id`/`asset_ref` ile
bağlanır" diyordu — **böyle bir arayüz YOK.** `moc_equipment` tablosu canlıda duruyor ama kodda
hiç geçmiyor; tek bağ, hedefi serbest metin olan manuel `qdl_cross_refs` etiketi. "Bu ekipmanda
hangi değişiklikler yapıldı?" sorusu bugün cevaplanamıyor.

### Bu modülde iş yaparken uyulacak kurallar
1. **İş kuralını yalnız tarayıcıda bırakma.** Faz H ile durum geçişi, onay sırası ve rol
   kuralları veritabanına indi; yeni kural eklerken aynı yeri de güncelle.
2. **Ham DB hatası ekrana basılmaz** — `hataMesaji(err)` kullan; `error.message` doğrudan
   `toast()`'a ASLA gitmez (32 noktada bu hata vardı, hepsi kapatıldı).
3. **Yeni liste sorgusunda `tumSatirlar()` kullan** — düz `select()` PostgREST'in 1000 satır
   varsayılanına takılıp sessizce veri kırpar. Checklist maddelerinde bu, onay kilidinin
   sessizce açılması demekti.
4. **`t` adını yerel değişken olarak KULLANMA** — global çeviri fonksiyonunu gölgeliyor; bu hata
   bu dosyada dört kez tekrarlandı.
5. Değişiklik sonrası: iki `<script>` bloğunu `node --check` ile doğrula → commit → push →
   `curl` ile canlı sayfada yeni kodun izini ara (yol kodlaması + user-agent, yukarı bkz.).

---

## ★ FAZ H (2026-09-05) — DENETİM + EN KRİTİK 3 İŞ (commit `7def47e`)

İki paralel ajanla rakip analizi (Sphera, Intelex, Enablon, VelocityEHS, Cority, Benchmark
Gensuite, SafetyIQ, VisiumKMS + yerel çözümler) ve **canlı veritabanı doğrulamalı** uçtan uca
denetim yapıldı. 26 bulgu çıktı; rapor Artifact olarak yayımlandı:
`https://claude.ai/code/artifact/62641955-7582-4574-838f-69d72b2f10f4`

**1) İş kuralları veritabanına indi (`moc_schema_faz_h_kurallar.sql`).**
En ağır bulgu buydu: 17 MOC tablosunun tamamında tek bir politika vardı ve yalnız firma ayrımı
yapıyordu. VIEWER rolündeki bir kullanıcı arayüzde hiçbir düğme görmese de konsoldan bir MOC'u
doğrudan `CLOSED` yapabiliyor; talep sahibi kendi talebinin bütün onay adımlarını tek istekte
onaylayabiliyordu. Yapılanlar: yazma yetkisi role bağlandı (INSERT/UPDATE `is_editor()`, DELETE
`is_admin()`); `moc_requests`'e durum geçişi trigger'ı (yalnız tanımlı geçişler, yeni kayıt yalnız
`DRAFT`, onay adımsız `APPROVAL` yok, eksik onayla devreye alma yok); `moc_approvals`'a onay
trigger'ı (**kendi talebini onaylayamama** + **aynı kişi zincirde ikinci karar veremez** — görev
ayrılığı, denetimde bulunan açık).
**Önemli tasarım notu:** rol kontrolü yalnız `auth.uid()` doluyken uygulanır. İlk denemede
koşulsuz yazılmıştı ve Management API/bakım betikleri de kilitlendi (testte yakalandı);
tarayıcıdan gelen her istekte `auth.uid()` dolu olduğu için kural, korumak istediği yolda aynen
yürürlükte.

**2) Üç kalıcı kilitlenme kapatıldı.** Üçü de "kurtarma yalnız SQL ile" sınıfındaydı:
(a) **Onay adımsız `APPROVAL`** — `TRANSITIONS.APPROVAL` boş, çıkış yalnız `checkApprovalAuto()`,
o da ancak bir karar verilince çalışıyor; adım ekleme düğmesi yalnız önceki durumda görünüyordu.
Artık en az bir onay adımı olmadan onaya geçilemiyor (hem geçiş koşulu hem trigger) **ve**
`APPROVAL` durumunda da adım eklenebiliyor ki daha önce kilitlenmiş kayıtlar arayüzden
kurtarılabilsin.
(b) **PSSR `NOT_RELEASED`** — sonuç alanı sıfırlanmadığı için karar düğmeleri bir daha
görünmüyordu; geçişe `after:resetPssrResult` kancası eklendi. Durum makinesi dosyası bu döngüyü
zaten öngörüyordu, kod tek seferlik varsaymıştı.
(c) **Mükerrer PSSR checklist'i** — `UNIQUE(moc_id)` kısıtı + çift tıklama koruması; ayrıca
`viewDetail`'deki yedi sorgunun `error` alanı artık kontrol ediliyor (hata yutulduğu için panel
kalıcı boş görünüyordu) ve PSSR sorgusu `.maybeSingle()` yerine çoğul okumaya çevrildi.

**3) Sessiz veri kırpma + hata metinleri.** Dosyada tek bir `.range()`/`.limit()` yoktu. Yeni
`tumSatirlar()` yardımcısı sayfa sayfa çekiyor; `loadLookups`, `reloadLookupsAll`, talep listesi
ve onay kuyruğu bağlandı. **En kritik yer checklist maddeleriydi:** 1000 aşılırsa
`condChecklistAnswered()` eksik maddeleri "yanıtlanmamış" saymaz, HİÇ GÖRMEZ — yani
`TECHNICAL_REVIEW → APPROVAL` kilidi sessizce açılır ve cevaplanmamış güvenlik soruları atlanır.
Ayrıca merkezî `hataMesaji()` yazıldı; **32 noktadaki ham DB hatası sıfıra indi** (kullanıcı
tablo/kolon/kısıt adı görüyordu), giriş ekranı da sağlayıcı mesajını sızdırmıyor.

**Aynı turda kapatılan küçük bulgular:** üstteki arama kutusu hiçbir olaya bağlı değildi, artık
MOC no/başlık/açıklamada yerel filtre yapıyor; soft-delete edilmiş talep "Onay Bekleyenler"den
düştü; geri dönüşsüz üç geçiş (İptal/Ret/Kapat) artık onay istiyor (silme için onay VARDI, daha
yıkıcı olan iptalde yoktu); modal Kaydet düğmesi çift tıklamaya kapatıldı (yavaş bağlantıda iki
ayrı MOC numarası üretiyordu).

**Faz H canlıya uygulandı ve 10 senaryoyla test edildi**, test verisi silindi (0 kalıntı):
doğrudan CLOSED kayıt açma engellendi, tanımsız geçiş engellendi, onay adımsız APPROVAL
engellendi, adım eklenince geçiş çalıştı, kendi onayı engellendi, başkası onayladı, mükerrer onay
engellendi, eksik onayla devreye alma engellendi, mükerrer PSSR engellendi.

**Denetimde İYİ bulunanlar (bozmayın):** atomik `moc_no` üretimi (tek ifade, satır kilidi altında
— diğer modüllerde mükerrer numara bug'ı tam bu yüzden çıkmıştı), GENERATED risk/sapma kolonları,
kurcalanamaz `moc_audit_log` (yazma yalnız trigger'dan), global şablonların RLS korumalı
salt-okunurluğu, kur çevrimi hatasının şeffaf gösterimi, checklist accordion deneyimi, tutarlı
`esc()` kullanımı.

---

## Ek bug fix (30.08.2026, ikinci tur) — İade edilen onay adımı zinciri kalıcı kilitliyordu
`checkApprovalAuto()` bir onay adımı **İade (RETURNED)** edildiğinde MOC'u `TECHNICAL_REVIEW`'a
geri gönderiyordu ama o `moc_approvals` satırının `decision` alanını sıfırlamıyordu. Talep tekrar
`APPROVAL`'a ilerletildiğinde `activeApprovalStep()` sıralı listede bu eski RETURNED satırına
ulaşınca (`decision!=='APPROVED'` olduğu için) döngüyü kırıp `null` döndürüyordu — hiçbir adım
bir daha "aktif" olamıyordu, Onayla/İade/Reddet butonları kimseye görünmüyordu, "Onay
Bekleyenler" ekranı bu MOC'u asla listelemiyordu, talep **sonsuza kadar `APPROVAL` durumunda
kilitli** kalıyordu. Bu, CLAUDE.md'de daha önce "sıralı onay zinciri henüz canlı test edilmedi"
diye not düşülen tam senaryoydu. **Düzeltme (commit `c04a146`):** `checkApprovalAuto()` artık
`TECHNICAL_REVIEW`'a dönerken İade edilen satır(lar)ın `decision`/`decided_at`/`approver_id`
alanlarını `null`'a çekiyor — adım tekrar "Bekliyor" durumuna dönüyor, MOC yeniden `APPROVAL`'a
geldiğinde normal şekilde ilerleyebiliyor. **⚠️ Bu düzeltmeden ÖNCE zaten kilitlenmiş MOC
kayıtları varsa** (canlıda İade akışı hiç kullanılmadıysa risk yok), onların RETURNED satırının
`decision`'ı SQL ile elle `null`'a çekilmeli — kod düzeltmesi yalnız YENİ kilitlenmeleri önler,
geçmiş veriyi otomatik düzeltmez.

## Ek bug fix (30.08.2026) — openNewRequest() içindeki gölgeleme kaçmıştı
İngilizce dil desteği eklenirken `renderRequestTable`/`renderDetail`/`openTypeModal`'daki
`t` (tür objesi) ↔ global `t()` çeviri fonksiyonu gölgelemesi düzeltilmişti, ama
**`openNewRequest()` içindeki dördüncü bir yer gözden kaçmıştı** (commit `f2fb623`,
paralel modül denetimi sırasında bulundu). `var t=typeById(req.type_id);` global `t()`'yi
gölgeliyordu; seçili akış türü varsa (`typ.requires_end_date` kontrolü sonrası)
`toast(t('Talep oluşturuldu'))` çağrısı `TypeError: t is not a function` fırlatıp
`.then()` içinde sessizce yutuluyordu — kullanıcı başarı bildirimini görmüyor, yeni
oluşturduğu talebin detay ekranına yönlendirilmiyordu (`go('detail', req.id)` hiç
çalışmıyordu). Düzeltme: değişken `typ` olarak yeniden adlandırıldı. **Ders:** bu
dosyada "tür/type" nesnesi için yerel değişken adı olarak asla düz `t` kullanılmamalı —
bu artık DÖRT yerde tekrarlanmış bir hata sınıfı, yeni kod eklerken özellikle dikkat.

## İngilizce Dil Desteği (29.08.2026'da eklendi)
Bu modülde daha önce hiç İngilizce yoktu (yalnız Türkçe). Yöntem, Doküman Yönetimi
modülüne bir gün önce eklenen yöntemden birebir kopyalanıp uyarlandı (bkz. Doküman
Yönetimi `CLAUDE.md` → "İngilizce Dil Desteği") — yeni bir yöntem icat edilmedi.

**Nasıl çalışıyor:** `MOC.html`'in başına `var I18N={...}` sözlüğü eklendi (yaklaşık
150 anahtar). Sözlükteki her anahtar TÜRKÇE metnin kendisi (örn. `'Kaydet':'Save'`).
`t('Kaydet')` İngilizce modda "Save" döner; Türkçe modda ya da sözlükte olmayan bir
metin için her zaman metni OLDUĞU GİBİ geri döner — yani hiçbir zaman boş/hatalı
görünmez, güvenli bir yöntem. Dil tercihi `localStorage.moc_lang`'de saklanır
(varsayılan Türkçe, `moc_` öneki bu modülün kendi anahtarı). Topbar'da ("EN"/"TR"
düğmesi) ve giriş ekranında ayrı ayrı birer dil düğmesi var.

**ÇOK ÖNEMLİ KURAL — asla bozulmadı:** MOC talebi başlığı/açıklaması/gerekçesi, risk
kaydı notları, checklist gerekçe/bulgu metni, serbest metin — yani veritabanından gelen
HİÇBİR KULLANICI VERİSİ çevrilmedi. Yalnızca sabit ekran metinleri (menü, başlık, buton,
tablo başlığı, durum etiketi, modal başlığı, form etiketi) çevrildi.

**Kapsanan ekranlar:** Giriş ekranı + dil düğmesi; üst kart menü (Özet/Değişiklik
Talepleri/Onay Bekleyenler/Tüm Değişiklikler/Ayarlar) + topbar (buton/başlık/dil
düğmesi); Dashboard/Genel Bakış (KPI kutuları, kategori dağılım grafiği, T-7 listesi,
"Özelleştir" paneli); liste ekranları (Değişiklik Talepleri, Onay Bekleyenler, Tüm
Değişiklikler) tablo başlıkları ve satır aksiyonları; MOC detay ekranının tamamı —
durum geçişi paneli, maliyet takibi paneli, risk değerlendirmesi paneli, onay zinciri
paneli (Onayla/İade/Reddet dahil), aksiyonlar paneli, PSSR paneli, etki değerlendirme
checklist paneli (bölüm accordion'u + Evet/Hayır/N-A chip'leri + gerekçe kutusu dahil),
ilişkili kayıtlar paneli; yeni MOC talebi formu ve kısıtlı/tam düzenleme modları; Ayarlar
ekranının tamamı (Kategori CRUD, Akış Türü CRUD, Etki Değerlendirme Checklist Setleri
paneli + madde yönetimi modalı, Kullanıcılar/persona paneli); ortak `modalTitle()`/
`modalFoot()`/`confirmBox()` yardımcı fonksiyonları (bu üçüne çeviri eklendiği için
platformdaki hemen her modalın başlığı ve Kaydet/Vazgeç/Kapat/Ekle/Onayla gibi butonları
otomatik İngilizce'ye döndü); tüm `toast()` bildirim mesajlarının büyük çoğunluğu.

**Durum makinesi (`STATUS_LABEL`) özel durumu:** `TRANSITIONS` objesindeki durum KODLARI
(`DRAFT`/`SCREENING`/`TECHNICAL_REVIEW`/`APPROVAL`/... ) zaten İngilizce ve hiç
değişmedi — bunlar durum makinesinin tek doğruluk kaynağı, koda hiç dokunulmadı. Yalnız
kullanıcıya gösterilen `STATUS_LABEL` rozet metni (Taslak/Ön Tarama/Teknik İnceleme vb.)
`t()` ile sarmalanarak çevrildi; DB'ye/karşılaştırmalara hâlâ kod (`req.status`) gider,
rozet metni tamamen kozmetik.

**Select/option tuzağı (kritik, kontrol edildi, TEMİZ bulundu):** Bir `<select>`'in
İngilizce'ye çevrilen görünen metni `value=` özniteliği olmadan bırakılırsa İngilizce
modda o İngilizce metin veritabanına yazılır ve durum makinesi/checklist tetikleme
mantığı sessizce bozulur — bu hata daha önce başka modüllerde (Q-Tedarikçi, Bakım-Onarım)
yaşanmıştı. Bu modülde MOC'un durum makinesi/onay zinciri/checklist tetikleme mantığı
tamamen string eşleşmelerine dayandığı için özellikle dikkatle kontrol edildi:
**tüm `<select>`/`<option>` grupları (para birimi, kategori, akış türü, öncelik
NORMAL/LOW/HIGH/EMERGENCY, aksiyon fazı PRE_APPROVAL/IMPLEMENTATION/..., checklist
tetikleyen cevap Evet/Hayır, persona, hedef modül) MOC.html'de zaten kod/etiket ayrımıyla
yazılmıştı** — DB'ye/karşılaştırmaya hep sabit `value=` kodu gider, görünen etiket
bağımsız olarak `t()` ile çevrilebilir. **Hiçbir yerde ek düzeltme GEREKMEDİ** — yalnız
görünen etiket metinlerine `t()` eklendi, `value=` hiçbirinde değiştirilmedi. Ayrıca
Onay Zinciri kararı (Onayla/İade/Reddet) ve checklist Evet/Hayır/N-A chip'leri de
`<select>` değil buton olup `data-dec="APPROVED/RETURNED/REJECTED"` / `data-cevap=
"EVET/HAYIR/NA"` özniteliğinden okunuyor — bunlarda da yalnız görünen buton metni
çevrildi, `data-*` değerleri hiç değişmedi.

**Kritik bir kod-adı çakışması bulunup düzeltildi:** `t` hem global çeviri fonksiyonunun
adı hem de kodun bazı yerlerinde "tür" (type) nesnesini tutan yerel değişken/parametre
adıydı (`renderRequestTable`, `renderDetail`, `openTypeModal` gibi). Bu fonksiyonların
içinde `t('...')` çağrısı eklenseydi, yerel `t` değişkeni global fonksiyonu gölgeler ve
"t is not a function" hatası ya da (daha tehlikelisi) `openTypeModal`'da olduğu gibi
`t ? update : insert` kontrolünün her zaman "her t objesi trulu" mantığıyla yanlış dallanması
riski doğardı. Çözüm: bu fonksiyonlardaki yerel değişken/parametre `t` → `typ`/`tp` olarak
yeniden adlandırıldı, global `t()` çağrıları güvenli hale getirildi. Bu tür bir isim
çakışması ileride yeni kod eklenirken tekrar unutulmamalı — bu dosyada "tür/type" nesnesi
için yerel değişken adı olarak asla düz `t` kullanılmamalı.

**Henüz çevrilmeyenler (bilinçli, düşük öncelik):** bazı `toast()` doğrulama/hata mesajları
(örn. "Başlık zorunlu.", "Rol kodu zorunlu.", "Kod ve ad alanları zorunlu." gibi form
doğrulama uyarıları) ve `readRequestForm()`/`toggleEndDate()` içindeki birkaç mesaj —
bunlar en az kullanılan hata yollarıdır, kullanıcı isterse aynı yöntemle (I18N sözlüğüne
satır ekleyip `toast(t(...))` şeklinde sarmalayarak) genişletilebilir.

**Sözdizimi doğrulaması:** dosyadaki 2 `<script>` bloğu da Node (`new Function(...)`)
ile hatasız doğrulandı.

## Ne bu
Endüstriyel değişiklik yönetimi (Management of Change) modülü. Tek dosya
HTML (`MOC.html`), build yok — Ekipman/Gıda/Q-Tedarikçi/Q-Kalite ile aynı
desen. Bağımsız modül; ekipman modülüne yumuşak referansla (equipment_id
veya asset_ref serbest metin) bağlanır, ekipman modülü olmadan da çalışır.

## Faz 3.4 — Kullanıcılar paneli (persona atama, 2026-08-28)
Ana sentez raporu §3.4. Ayarlar ekranı (`renderSettings`, zaten `canDo('admin')` ile korunuyor)
en üste yeni bir **"Kullanıcılar"** paneli aldı (`renderUsersSettingsSection`, `innerHTML`
atamasından SONRA çağrılır — sırası önemli, önce çağrılırsa panel `renderSettings`'in tam
`innerHTML` overwrite'ıyla silinir). Ortak `profiles` tablosundan `tenant_id=cloudTenantId`
kullanıcıları çekilip yalnızca **persona** (saha_operatoru/sorumlu/ust_yonetim/denetci) atanır,
değişiklik anında kaydedilir. **Rol değişimi BİLİNÇLİ eklenmedi** — Ekipman modülündeki ortak
"Kullanıcılar" ekranı zaten bu işi yapıyor. Node ile sözdizimi doğrulandı. **✅ Deploy doğrulandı (2026-08-28):** `curl` ile `moc.qdataline.com` canlı bundle'ında `usersPanel` doğrulandı. **Kullanıcı henüz gerçek hesapla test etmedi.**

## Faz 3.7 — bildirim üretimi (2026-08-26 gece)
`crossRefsBind`'daki kaydetme akışına `notifyOwnerOfCrossRef()` eklendi — yeni "İlişkili Kayıt"
bağlantısı eklenince tenant sahibine (`is_owner=true`) `qdl_notifications` satırı yazılıyor
(Ekipman `index.html`'deki desenin birebir kopyası). Görüntüleme arayüzü (zil) bu modülde yok —
merkezi bildirim hub'ı Ekipman'da (SSO sayesinde ayrı giriş gerekmiyor). Detay/gerekçe: Ekipman
CLAUDE.md.

## Faz 3.3 — SSO: .qdataline.com paylaşımlı cookie oturumu (2026-08-26)
`MOC.html`'deki `createClient()` çağrısına `qdlCookieAuthStorage()` eklendi — oturum `localStorage`
yanında `Domain=.qdataline.com` cookie'sinde de tutuluyor (fail-safe: cookie çalışmazsa localStorage'a
düşer, login bozulmaz). Kod Ekipman `index.html`'deki ile birebir aynı (detay: Ekipman CLAUDE.md
§Faz 3.3). Not: MOC'un barındırma platformu (Cloudflare Pages varsayıldı) bu değişiklik sırasında
bağımsız doğrulanamadı — `document.cookie` yazımı barındırma/CDN ayrımından bağımsız çalışır, engel değil.

## Çapraz-modül referans (2026-08-24)
MOC talebi detay görünümünde "🔗 İlişkili Kayıtlar" paneli — ortak `qdl_cross_refs`
tablosuna (aynı proje) manuel etiketle diğer modüllerdeki (Ekipman, Q-Tedarikçi, Gıda)
kayıtlara bağlantı ekle/listele/sil. Aynı desen 3 modülde daha var, ayrı SQL gerekmedi.
Not: MOC'un `moc_schema_v1-1.sql` içindeki `tenant_modules` taslağı MOC'ta hiç uygulanmadı,
ama **aynı adlı gerçek bir tablo başka bir yerde (Q-Kalite migrasyonu, 2026-08-25) zaten
oluşturulmuş ve şimdi Ekipman hub'ının (`index.html`) paket/görünürlük kontrolü için resmi
hâle getirildi** (bkz. Ekipman `sql/tenant_modules_v1.sql`, module_code='moc' MOC için de var).
MOC'un kendi kullanıcı-yetkilendirmesi hâlâ `modul_yetki`/`has_modul('moc')` üzerinden.

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
- `moc_schema_faz_f.sql` — Faz F: PSSR Checklist Seti. Faz C'deki
  `moc_etki_checklist_setleri`'ne `tetik_tipi`/`tetik_durum_kodu`
  kolonları (idempotent ALTER) + üçüncü, DURUM-tetiklemeli bir set
  seed'i ekler. Henüz Supabase'e UYGULANMADI (bkz. "Faz F" bölümü).
- `moc_schema_faz_g.sql` — Faz G: Checklist Tetikleyici Cevap Düzeltmesi.
  `moc_etki_checklist_maddeleri`'ne `tetikleyen_cevap` kolonu (idempotent
  ALTER) + 91 maddenin (Genel Risk 68 + Gıda 10 + PSSR 13) tek tek
  belirlenmiş doğru tetikleyici cevabını atayan idempotent UPDATE'ler.
  Henüz Supabase'e UYGULANMADI (bkz. "Faz G" bölümü).
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

## Faz G — Checklist Tetikleyici Cevap Düzeltmesi (kod hazır, SQL uygulanmayı bekliyor)
- **Bulunan mantık hatası:** Checklist soruları iki farklı tarzda yazılmış
  ama sistem hepsini "Evet ise aksiyon gerekli" sabit varsayımıyla
  işliyordu. "Risk tespit" tarzı sorularda ("X etkileniyor mu/gerekiyor
  mu?") bu doğruydu — Evet kötü haberdir. Ama "doğrulama/teyit" tarzı
  sorularda ("X tamamlandı mı/test edildi mi/çalışıyor mu?") mantık
  TERSTİ — Hayır kötü haberdir, aksiyonu Hayır tetiklemeliydi. Bu özellikle
  Faz F'nin PSSR setinin **13 maddesinin tamamını** (hepsi doğrulama
  tarzı) ve Genel Risk setinin **52 maddesini** yanlış yönde çalıştırıyordu
  — ör. "Acil durdurma sistemleri çalışır durumda mı?" sorusunda "Evet"
  (sistem çalışıyor, sorun yok) yanlışlıkla aksiyon açıyor, "Hayır"
  (sistem çalışmıyor, gerçek risk) sessizce geçiyordu.
- **Çözüm:** `moc_etki_checklist_maddeleri`'ne `tetikleyen_cevap`
  (`'Evet'`/`'Hayır'`, DEFAULT `'Evet'` — geriye dönük uyumlu) kolonu
  eklendi. `MOC.html`'de `checklistTriggerCevap(m)` yardımcı fonksiyonu
  eklendi; `commitChecklistAnswer()`'daki `needsAction` hesaplaması,
  `renderChecklistRow()`'daki gerekçe kutusu açılma tetiği (`showGerekce`)
  ve `bindChecklistEvents()`'teki chip tıklama akışı artık sabit `'EVET'`
  yerine `cevap===checklistTriggerCevap(m)` karşılaştırması kullanıyor —
  hangi cevap o maddenin tetikleyicisiyse yalnız o seçilince gerekçe kutusu
  açılıyor ve aksiyon doğuyor.
- **Ayarlar CRUD güncellendi:** `openChecklistItemForm()`'a "Tetikleyen
  Cevap" seçici (Evet/Hayır, açıklayıcı örnekli) eklendi; madde tablosu
  yeni bir "Tetikleyen" kolonu gösteriyor; `cloneChecklistSet()`
  (tenant'ların "Kullan"/"Kopyala" akışı) artık `tetikleyen_cevap`'ı da
  kopyalıyor — tenant kopyaları global şablonun düzeltilmiş mantığını
  devralıyor.
- **91 maddenin tam kırılımı** (`moc_schema_faz_g.sql`, madde bazlı —
  her soru cümlesi tek tek okunup karar verildi):
  - **Genel Risk Değerlendirme Checklist'i (68 madde):** 13 madde "Evet
    tetikler" (risk tespit tarzı — sira 3,8,9,10,25,29,31,43,44,46,47,
    49,50), 52 madde "Hayır tetikler" (doğrulama tarzı), **3 madde
    kararsız bırakıldı** (aşağıya bkz.).
  - **Gıda Güvenliği Etki Değerlendirmesi (10 madde):** 10/10 "Evet
    tetikler" (hepsi risk tespit tarzı, örn. "HACCP planını etkiliyor
    mu?") — davranış DEĞİŞMEDİ.
  - **PSSR Checklist'i (13 madde):** 13/13 "Hayır tetikler" (hepsi
    doğrulama tarzı — "...test edildi mi/çalışıyor mu/güncellendi mi?").
    Madde #2 (basınç tahliye cihazları) zaten `evet_aksiyon_gerekli=false`
    (N/A olabilir) olduğu için tetikleyen_cevap'ın işlevsel etkisi yok,
    yalnız tutarlılık için 'Hayır' işaretlendi.
  - **Çift olumsuz 3 madde (Genel Risk #39/#40/#51) — kullanıcı onayıyla
    çözüldü (03.08.2026):** Üçü de "Hayır tetikler" olarak işaretlendi
    VE kafa karıştırıcı çift-olumsuz cümle yapıları, anlamı değiştirmeden
    doğrudan/olumlu cümleye çevrildi:
    1. "İtfaiye/acil müdahale ekiplerinin alana erişimi engellenmiyor
       mu?" → **"İtfaiye/acil müdahale ekiplerinin alana erişimi açık
       mı?"** (Hayır tetikler — erişim açık değilse risk var)
    2. "Yangın duvarları/bölmeleri değişiklikle delinmedi veya
       zayıflatılmadı mı?" → **"Yangın duvarları/bölmeleri
       değişiklikten etkilenmeden sağlam kaldı mı?"** (Hayır tetikler)
    3. "Değişiklik için gerekli tüm onaylar tamamlanmadan işe
       başlanmıyor mu?" → **"İşe başlamadan önce gerekli tüm onaylar
       tamamlandı mı?"** (Hayır tetikler)
    `moc_schema_faz_g.sql`'in 4. bölümünde eski metinle eşleştirilip hem
    `tetikleyen_cevap` hem `soru_metni` tek UPDATE'te güncelleniyor
    (idempotent — script tekrar çalıştırıldığında satır artık yeni
    metni taşıdığı için eski metinle eşleşmez, no-op).
- **DURUM:** Kod (`MOC.html`) hazır, JS söz dizimi doğrulandı, mantık
  PSSR/Genel Risk örnek senaryolarıyla masaüstünde (kod okuması +
  fonksiyon simülasyonu) doğrulandı. Şema (`moc_schema_faz_g.sql`,
  91 maddenin tamamı için karar netleşmiş halde) **Supabase'e henüz
  uygulanmadı** — SQL uygulanmadan `tetikleyen_cevap` kolonu mevcut
  değilken `m.tetikleyen_cevap` `undefined` döner ve
  `checklistTriggerCevap()` varsayılan `'EVET'`e düşer, yani eski
  (hatalı) davranış SQL uygulanana kadar sürer; **kod ve SQL birlikte
  devreye alınmalı**. Bir sonraki adım: script'i çalıştırıp PSSR'da
  "Acil durdurma sistemleri çalışır durumda mı?" sorusuna canlıda
  Hayır cevabı verip aksiyon+gerekçe zorunluluğunun açıldığını, Evet
  cevabında sorunsuz geçildiğini; Genel Risk/Gıda'daki risk-tespit
  tarzı maddelerde davranışın (Evet tetikler) değişmediğini; #39/#40/
  #51'in güncellenmiş metinle ve Hayır tetikleyerek doğru göründüğünü
  doğrulamak.

## Faz F — PSSR Checklist Seti: durum-tetiklemeli üçüncü set (kod hazır, SQL uygulanmayı bekliyor)
- **Mimari farkı (Faz C'den):** Genel Risk ve Gıda setleri KATEGORİ bazlı
  tetikleniyor (`kategori_id`, talep oluşturulurken belli olur). PSSR seti
  DURUM/ADIM bazlı — yalnız `requires_pssr=true` olan türlerde, talep
  `PSSR` durumuna/adımına geldiğinde devreye girer. Bunun için
  `moc_etki_checklist_setleri`'ne iki yeni kolon eklendi:
  `tetik_tipi` (`'kategori'` | `'durum'`, DEFAULT `'kategori'` — mevcut iki
  set otomatik olarak eski davranışını korur, elle UPDATE gerekmedi) ve
  `tetik_durum_kodu` (nullable, PSSR seti için `'PSSR'`).
- **Aynı altyapı yeniden kullanıldı:** ayrı bir tablo AÇILMADI — aynı
  `moc_etki_checklist_maddeleri`/`_yanitlari`, aynı "evet_aksiyon_gerekli"
  → `moc_action_items` otomasyonu, aynı hızlı chip UI ve bölüm accordion'u
  (`renderChecklistPanelGeneric()`, `MOC.html`) PSSR seti için de
  kullanılıyor — yalnız panel ID'si (`pssrChecklistPanel`) ve başlığı
  farklı, `renderPssrPanel()` içine gömülü render ediliyor.
- **Tetikleme fonksiyonları:** `applicableChecklistSets()`/
  `applicableChecklistItems()` artık yalnız `tetik_tipi==='kategori'`
  setleri döndürüyor; yeni `applicablePssrChecklistSets()`/
  `applicablePssrChecklistItems()` yalnız `tetik_tipi==='durum' &&
  tetik_durum_kodu==='PSSR'` setleri döndürüyor (kategoriden bağımsız,
  global + tenant kopyası deseni Set 1 ile aynı).
- **Aksiyon fazı otomatik seçiliyor:** `checklistPhaseForMadde()`, maddenin
  ait olduğu setin `tetik_tipi==='durum'` olup olmadığına bakarak
  `moc_action_items.phase`'i belirliyor (durum tipinde `tetik_durum_kodu`,
  yani `'PSSR'`; kategori tipinde eskisi gibi `'PRE_APPROVAL'`) —
  `commitChecklistAnswer()` artık sabit `'PRE_APPROVAL'` yazmıyor.
- **PSSR→STARTUP gating:** `condPssrChecklistAnswered()` + mevcut
  `condActionsDone('PSSR')` artık `TRANSITIONS.PSSR` içindeki
  `RELEASED` geçişinin koşuluna eklendi — PSSR checklist'i tamamen
  yanıtlanmadan ve doğurduğu `phase='PSSR'` aksiyonları kapanmadan
  `STARTUP`'a geçiş kilitli kalıyor (Genel Risk/Gıda setinin
  `TECHNICAL_REVIEW → APPROVAL`'ı kilitlemesiyle aynı desen).
- **Seed (1 hazır global set):** "Devreye Alma Öncesi Güvenlik
  İncelemesi" (13 madde, 4 bölüm: Ekipman ve Kurulum Doğrulaması /
  Güvenlik Sistemleri Doğrulaması / Dokümantasyon Doğrulaması / Eğitim
  ve Kapanış Doğrulaması), global, `tenant_id` NULL, `tetik_tipi='durum'`,
  `tetik_durum_kodu='PSSR'`. Sorular harici saha güvenliği/devreye alma
  pratiklerinin KAPSAMINDAN esinlenerek özgün cümlelerle yazıldı; hiçbir
  kaynak standart/kurum adı kodda, seed data'da veya yorum satırlarında
  geçmiyor (grep ile teyit edildi).
- **DURUM:** Kod (`MOC.html`) hazır, JS söz dizimi doğrulandı. Şema
  (`moc_schema_faz_f.sql`) **Supabase'e henüz uygulanmadı** — SQL
  uygulanmadan `tetik_tipi` kolonu mevcut olmadığı için
  `applicableChecklistSets()`'in yeni filtresi Genel Risk/Gıda setlerini
  de gizler; **kod ve SQL birlikte devreye alınmalı**, ayrı ayrı değil.
  Bir sonraki adım: script'i çalıştırıp `requires_pssr=true` bir türde
  MOC'u PSSR adımına kadar ilerletmek, PSSR panelinde yeni checklist'in
  4 bölümlü accordion'la göründüğünü, "Evet" cevabının `phase='PSSR'`
  aksiyon açtığını, o aksiyon kapanmadan ve checklist tamamlanmadan
  RELEASED sonrası STARTUP'a geçilemediğini, `requires_pssr=false`
  türlerde bu panelin hiç görünmediğini doğrulamak.

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
- **Bölüm accordion'u (03.08.2026 ikinci ince ayar):** 68 maddelik Genel
  Risk seti + varsa Gıda seti tüm bölümleriyle aynı anda açık gelince
  sayfa aşırı uzuyordu — kullanıcı geri bildirimiyle bölüm bazlı
  katlanır yapıya geçildi (`renderChecklistPanel()` artık `bolum_baslik`'e
  göre gruplayıp her bölümü `.chk-section` bloğu olarak render ediyor;
  Gıda seti tek maddeli/tek bölümlü olduğu için otomatik kendi tek
  accordion'unu oluşturuyor, ayrı kod gerekmedi). Her bölüm başlığında
  ilerleme rozeti var: tamamlanan bölümde "✓ Tamamlandı" (yeşil),
  eksikte "X/Y yanıtlandı" (amber/gri). Varsayılan açık/kapalı durumu
  `CHECKLIST_MANUAL_OVERRIDE` (bölüm adı → kullanıcı tercihi) ile
  yönetiliyor: override YOKSA bölüm, yalnızca "ilk yanıtsız bölüm"
  ise açık gösteriliyor (`firstIncompleteIdx`) — bu da bir bölüm
  tamamlanınca bir sonraki eksik bölümün otomatik açılmasını sağlıyor
  (kullanıcı elle hiçbir şey yapmadan "kaldığı yerden devam" hissi).
  Kullanıcı başlığa tıklayıp herhangi bir bölümü (tamamlanmış olsa
  bile) istediği an açıp kapatabilir; bu manuel tercih override'a
  yazılır ve MOC değişene kadar (`CHECKLIST_OVERRIDE_REQ` reset)
  otomatik hesaplamayı ezer. Satırlar kapalı bölümde de DOM'da kalıyor
  (yalnız `display:none`), böylece `focusNextChecklistItem()`'ın
  `scrollIntoView` çağrısı bozulmadı — hızlı chip UI/otomatik sıradaki
  maddeye kayma davranışı DEĞİŞMEDİ, yalnızca bölümler artık katlanır.
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

---

## ★ FAZ I / J (2026-09-05) — RAKİP ANALİZİNİN 5 EKSİĞİ (commit `0df410c`)

Denetim raporundaki beş eksiğin tamamı kapatıldı. Dördü zaten şemada duran ama uygulamanın
hiç dokunmadığı tabloları hayata geçirdi — sıfırdan iş değil, yarım kalan işin tamamlanması.

**1. Ek dosya / fotoğraf (`moc_schema_faz_i_ekler.sql` + `renderDocsPanel`).**
`moc-belgeler` kovası açıldı (public DEĞİL). Depolama yolu **her zaman**
`<tenant_id>/<moc_id>/<dosya>`; politikalar yolun ilk klasörünü firma kimliğiyle
karşılaştırıyor, yani uygulama kodu hata yapsa bile bir firmanın dosyası başkasına görünmez.
Ayrıca `has_modul('moc')` şartı kondu: MOC yetkisi olmayan bir kullanıcı, aynı firmada olsa
dahi kovaya erişemez (denetimde `modul_yetki`nin yalnız arayüzde kontrol edildiği bulunmuştu —
bu, o boşluğun depolama tarafı). İndirme imzalı geçici bağlantıyla (60 sn), silme yalnız
yöneticide. Dosya adı depolama anahtarında temizleniyor (Türkçe karakter/boşluk sorun çıkarır).

**2. Otomatik bildirim (`moc_schema_faz_j_bildirim.sql`).** `moc_daily_notify()` + pg_cron
`20 6 * * *` (Tedarikçi 06:00, Q-Kalite 06:10 — üç mail aynı dakikaya düşmesin diye).
**Mail kişiye özeldir**, herkese aynı liste gitmez: o kişinin *gerçekten karar verebileceği*
onay adımları hesaplanır — sıralı zincir (öncekiler onaylanmış olmalı), talep sahibi hariç ve
"aynı kişi zincirde ikinci kez karar veremez" kuralı, yani arayüzdeki `activeApprovalStep` +
`canDecideApproval` mantığının SQL karşılığı. Ayrıca termini geçmiş aksiyonlar ve süresi
dolan geçici değişiklikler. **Yapacak iş yoksa mail atılmaz.** Ortak `qdl_send_email`
altyapısı kullanıldı, yeniden kurulmadı. **Canlıda gerçek veriyle test edildi:** Resend `200`
+ mail kimliği döndü, test bildirimi silindi.

**3. İşlem geçmişi (`renderGecmisPanel`).** `moc_audit_log` trigger'la zaten doluyordu
(talep, onay, risk kayıtları), gösteren ekran yoktu. Yalnız **gerçekten değişen** alanlar
`eski → yeni` olarak, okunur etiketlerle listeleniyor; `version`/`updated_at` gibi damgalar
ve kimlik alanları hariç tutuldu (yoksa her kayıtta anlamsız satır çıkardı). Durum, kategori
ve akış türü kodları ekranda ada çevriliyor.

**4. Denetim dosyası çıktısı (`denetimDosyasi`).** Talep bilgisi + risk değerlendirmesi +
onay zinciri + aksiyonlar + işlem geçmişi tek yazdırılabilir sayfada. Veri detay ekranında
zaten toplandığı için **yeni sorgu atmaz**. Yazdırma penceresi engellenirse kullanıcıya
anlaşılır uyarı verilir.

**5. Geçici değişikliğin kapanışı (`renderTempPanel`).** `moc_temporary_tracking`
yaz-ama-hiç-okuma durumundaydı. Artık: **Süreyi Uzat** (yeni tarih + gerekçe zorunlu, yeni
tarih mevcut bitişten sonra olmalı; uzatma `extension_history`'ye yazılıyor, uyarı bayrakları
sıfırlanıyor, `moc_requests.planned_end` de güncelleniyor) ve **Eski Duruma Dönüldü**
(not zorunlu, geri alınamaz). `restored_by`/`restore_note` kolonları eklendi — geri dönüşün
denetim değeri "ne zaman"dan çok "kim ve neye dönüldü"dedir. İzleme kaydı yoksa ilk işlemde
oluşturuluyor; bu, denetimdeki "yeni talep + izleme kaydı atomik değil, hata yutuluyor"
bulgusunun telafisi.

**Ayrıca:** `moc_documents` ve `moc_notifications` tablolarındaki tek "ALL" politikası da
Faz H desenine çekildi (okuma firma içinde, yazma EDITOR, silme ADMIN); bildirimin okundu
işaretini kişinin kendisi yapabilsin diye ayrı bir politika kondu.

**Hâlâ kapatılmayanlar:** `DOC_UPDATE` ve `TRAINING` adımları **içi boş** kalmaya devam
ediyor — `moc_trainings` ve `AFFECTED_DOC` akışı, doğru çözüm olarak Doküman Yönetimi ve
Eğitim Platformu modüllerine bağlanmayı gerektiriyor (MOC içine ikinci bir eğitim/doküman
sistemi yazmak yanlış olur). `evidence_hash` hâlâ kanıt değeri taşımıyor. Tablolarda
`overflow-x` yok. Soft-delete edilmiş kaydın detayı doğrudan id ile açılabiliyor.
