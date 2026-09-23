# QDATALINE MOC + Proje Takip Master Planı

**Sürüm:** 1.0  
**Tarih:** 23 Eylül 2026  
**Durum:** Uygulama başlangıç standardı  
**Kapsam:** Mevcut MOC Değişiklik Yönetimi modülüne, değişikliğin uygulanmasını izleyen proje takip katmanının eklenmesi.

## 1. Ürün kararı

QDATALINE'da proje takibi bağımsız ve genel amaçlı bir görev uygulaması olarak konumlanmayacak. **MOC Uygulama Planı**, onaylanmış bir değişikliğin görev, tarih, sorumlu, bağımlılık, maliyet, kanıt ve kapanış koşullarını yöneten MOC alt çalışma alanı olacak.

Ana akış:

`MOC talebi → ön tarama → risk/etki analizi → teknik inceleme → onay → MOC uygulama planı → doküman/eğitim/bakım → PSSR → devreye alma → etkinlik kontrolü → MOC kapanışı`

Mevcut MOC'nin risk, sıralı onay, doküman, eğitim, bakım, CAPA ve PSSR akışları korunur. Proje katmanı bu kayıtların yerine geçmez; her kayıt `moc_id` ve ortak `correlation_id` ile bağlanır.

## 2. Gönderilen rehberin değerlendirmesi

### Rehberden alınan güçlü noktalar

- Görev, alt görev, checklist, etiket, öncelik, süre ve sahiplik.
- Kanban, liste, takvim, Gantt/Timeline ve workload görünümlerinin aynı veriyi göstermesi.
- Portföy, milestone, bağımlılık, baseline ve planlanan/gerçekleşen karşılaştırması.
- Zaman kaydı, maliyet, kaynak kapasitesi ve bütçe takibi.
- Proje dokümanları, karar günlüğü, yorumlar ve bildirimler.
- Risk, sorun ve görev kayıtlarının birbirinden ayrılması.
- Rol, özel alan, şablon, entegrasyon ve otomasyon katmanı.

### Düzeltilmesi gereken noktalar

1. Rehberdeki araç fiyatları tarih ve kaynak bağlantısı olmadan yaklaşık verilmiş; ürün kararı fiyat iddiasına dayandırılmayacak.
2. Rehber genel proje yönetimine odaklanıyor; QDATALINE için PSSR, doküman yürürlük tarihi, eğitim kanıtı, geçici değişiklik geri dönüşü, CAPA ve etkinlik kontrolü zorunlu kapılar eklenmeli.
3. Müşteri portalı ilk sürüme alınmayacak; dış paydaş görünümü daha sonra yalnız seçilmiş görev/kanıtlarla açılacak.
4. “Faturalandırılabilir zaman” yerine üretim duruşu, dış hizmet, satın alma, iş gücü ve değişiklik maliyeti izlenecek.
5. AI destekli kaynak/atama önerisi ilk sürümde karar verici olmayacak; yalnız öneri üretecek ve kullanıcı onayı olmadan atama/tarih değiştirmeyecek.
6. Baseline yalnız rapor görüntüsü değil, tarihli ve değiştirilemez plan anlık görüntüsü olmalı.
7. Otomasyonlar modüllerin içine dağılmayacak; merkezi tetikleyici/aksiyon kayıtları üzerinden çalışacak.
8. Kapasite görünümü kişi bazlı fiyatlandırmayı zorunlu kılmayacak; takım/rol bazlı kapasite ve tenant yöneticisinin izinleri desteklenecek.

## 3. Piyasa deseni ve QDATALINE uyarlaması

Asana; görev sahibi, tarih, milestone, bağımlılık, teslimat, Timeline/Gantt ve portföy görünümünü aynı proje verisinden üretir. Jira bağımlılıkları “blocks / is blocked by” ilişkisiyle açıkça tutar ve sürüm/release planı sağlar. Bu desenler alınmalı; ancak MOC kapıları kullanıcı tarafından atlanamamalıdır.

QDATALINE karşılıkları:

| Piyasa deseni | MOC karşılığı |
|---|---|
| Proje | MOC uygulama planı |
| Faz | MOC uygulama, doküman, eğitim, PSSR, devreye alma |
| Görev | Sorumlusu ve kanıtı olan uygulama aksiyonu |
| Milestone | Onay tamam, doküman yürürlükte, eğitim tamam, PSSR geçti |
| Dependency | Doküman bitmeden eğitim başlayamaz; PSSR bitmeden devreye alma başlayamaz |
| Baseline | Onaylanan ilk planın değişmez kopyası |
| Risk | MOC risk kaydı ve azaltım planı |
| Budget | Planlanan/gerçekleşen iş gücü, satın alma, dış hizmet, duruş maliyeti |
| Release | Değişiklik paketi ve devreye alma tarihi |
| Portfolio | Tesis/modül/sponsor bazlı MOC projeleri görünümü |

## 4. Apify'nin konumu

Apify proje yönetim veritabanı değildir. Actor, Schedule, Dataset, API ve Webhook sağlayan harici otomasyon katmanıdır. Apify; mevzuat, standart, tedarikçi veya ekipman duyurusu gibi dış sinyalleri toplamak ve QDATALINE'a inceleme önerisi göndermek için kullanılabilir.

Önerilen akış:

`Apify Actor → Dataset → Edge Function webhook → harici değişiklik sinyali → insan incelemesi → gerekirse MOC önerisi`

Kurallar:

- Apify token'ı frontend'e konulmaz; Edge Function/worker secret olarak tutulur.
- Scoped token ve yalnız gerekli Actor/Dataset izinleri kullanılır.
- Harici içerik otomatik olarak MOC açmaz.
- Kaynak URL, yakalanma zamanı, içerik özeti, hash ve inceleyen kişi saklanır.
- Müşteri/firma özel bilgileri varsayılan olarak alınmaz; maskeleme ve saklama süresi uygulanır.
- Actor başarısızlığı, gecikmesi ve veri kalitesi merkezi entegrasyon uyarısı üretir.

## 5. Menü ve ekran mimarisi

MOC içinde yeni bir üst menü açmak yerine, MOC detayına **Uygulama Planı** sekmesi eklenir. Gerekirse sol menüde ayrıca “Proje Takip” yalnız MOC uygulama planlarını gösterir.

1. **Panel:** aktif MOC projeleri, geciken görevler, kritik yol, bütçe ve açık riskler.
2. **Projeler/Portföy:** tesis, modül, sponsor, risk ve durum filtresi.
3. **Görevler:** liste, Kanban, checklist, alt görev, yorum, dosya ve audit.
4. **Planlama:** Timeline/Gantt, milestone ve bağımlılık.
5. **Kaynaklar:** takım/rol kapasitesi, müsaitlik, aşırı yüklenme.
6. **Zaman ve Maliyet:** planlanan/gerçekleşen saat, dış hizmet, satın alma ve duruş maliyeti.
7. **Risk/Sorun/Karar:** birbirinden ayrı kayıt türleri ve eskalasyon.
8. **Doküman/Eğitim/Bakım bağlantıları:** ilgili modül kayıtlarının durumu.
9. **Kanıt/PSSR/Etkinlik:** dosya, ölçüm, test, karar ve kapanış kanıtı.
10. **Ayarlar:** roller, durum akışı, özel alanlar, şablonlar, bildirim ve entegrasyonlar.

## 6. Tek veri, çoklu görünüm kuralı

Görev Gantt'ta taşındığında liste, Kanban, takvim, workload, proje ilerlemesi ve bildirimler aynı kaynaktan güncellenir. Görünümler ayrı kopya tutmaz.

| Olay | Zorunlu sonuç |
|---|---|
| Durum değişti | İlerleme, KPI, bildirim ve audit güncellenir |
| Tarih değişti | Bağımlı görev etkisi hesaplanır; gerekiyorsa uyarı çıkar |
| Görev atandı | Kaynak kapasitesi ve sorumlu görünümü güncellenir |
| Zaman/maliyet girildi | Plan-gerçekleşen ve MOC maliyetine işlenir |
| Dosya eklendi | Görevde ve proje doküman arşivinde görünür |
| Onay istendi | Yetkili kişiye bildirim ve aktivite kaydı oluşur |
| Gecikme oluştu | Panel, eskalasyon ve rapor uyarısı oluşur |
| Şablon seçildi | Faz, görev, milestone, alan ve kapı koşulları oluşturulur |

Otomasyon kuralları merkezi tutulur: `tetikleyici → koşul → aksiyon → alıcı → audit`. Hiçbir alt modül kendi bildirim mantığını ayrı uygulamaz.

## 7. Veri modeli

- `moc_projects`: MOC ilişkisi, ad, sponsor, proje yöneticisi, durum, tarih, risk, bütçe.
- `moc_project_phases`: faz, sıra, planlanan tarih, tamamlanma koşulu.
- `moc_project_tasks`: görev, faz, sahip, ekip, durum, öncelik, başlangıç/bitiş, yüzde, tahmini/gerçek saat, zorunlu/kanıt gerekli.
- `moc_task_checklists`: görev içi kontrol maddeleri ve tamamlayan kişi.
- `moc_task_dependencies`: predecessor, successor, ilişki tipi, tampon süre.
- `moc_project_milestones`: kapı adı, tarih, durum, kanıt ve kural.
- `moc_project_risks`: olasılık, etki, skor, azaltım, sahip, artık risk.
- `moc_project_issues`: sorun, blokaj, eskalasyon, karar tarihi.
- `moc_project_decisions`: karar, seçenekler, karar sahibi, gerekçe ve kanıt.
- `moc_project_costs`: maliyet tipi, planlanan/gerçekleşen, para birimi, belge ve onay.
- `moc_project_baselines`: onaylı plan anlık görüntüsü, tarih, oluşturan kişi, hash.
- `moc_project_links`: doküman, eğitim, bakım, CAPA, İSG, ekipman, tedarikçi ve stok kaydı.
- `moc_project_updates`: durum özeti, blokaj, bir sonraki adım.
- `moc_project_templates`: değişiklik tipine göre hazır faz/görev/milestone paketi.
- `moc_external_signals`: Apify/harici kaynak, URL, zaman, hash, inceleme ve onay durumu.

Her tabloda `tenant_id`, `created_by`, `created_at`, `updated_at` ve `correlation_id` bulunur. RLS, composite tenant ilişkileri ve sunucu yetkisi birlikte test edilir.

## 8. MOC ile proje kapı kuralları

- **Taslak → Ön inceleme:** amaç, kapsam, değişiklik türü ve sponsor zorunlu.
- **Ön inceleme → Risk:** etkilenen tesis, ekipman, ürün, doküman ve çalışan alanları seçilmiş.
- **Risk → Teknik inceleme:** risk kaydı ve yüksek risk için azaltım tamamlanmış.
- **Teknik inceleme → Onay:** teknik değerlendirme notu mevcut.
- **Onay → Uygulama:** tüm sıralı onaylar tamamlanmış; uygulama planı oluşmuş.
- **Uygulama → Doküman:** zorunlu uygulama görevleri tamamlanmış.
- **Doküman → Eğitim:** etkilenen dokümanların yeni onaylı sürümü yürürlükte.
- **Eğitim → PSSR/Devreye alma:** gerekli eğitim kanıtları tamamlanmış.
- **PSSR → Devreye alma:** checklist sonucu RELEASED; kritik açık aksiyon yok.
- **Devreye alma → Kapanış:** etkinlik ölçümü, kalan risk ve kapanış onayı kayıtlı.

Acil değişiklikte uygulama öne alınabilir; risk, onay ve kayıt görevleri tanımlı geri dönüş süresinde otomatik açılır. Geçici değişiklik süresi dolunca geri dönüş veya yetkili uzatma olmadan kayıt aktif kalamaz.

## 9. Rol ve yetki modeli

- **Sistem yöneticisi:** yapılandırma, rol, şablon ve yeniden açma.
- **MOC koordinatörü:** tarama, risk akışı, kapı geçişleri ve kapanış.
- **Proje lideri:** plan, görev, tarih ve kaynak.
- **Görev sahibi:** yalnız atanmış görevi ve kanıtı günceller.
- **Onaycı:** kendisine gelen kapı kararını verir; kendi talebini onaylayamaz.
- **Gözlemci:** yetkili kapsamda okur ve yorum yapar.
- **Dış paydaş:** ilk sürümde yok; sonraki fazda yalnız paylaşılmış görev/kanıt görünümü.

Her durum geçişi sunucu tarafında doğrulanır. Audit kayıtları güncellenemez veya silinemez.

## 10. Yol haritası

### Faz 0 — Kapsam ve teknik sözleşme (3–5 gün)

MOC ve proje durumlarını ayır, roller/kapılar/maliyet tanımlarını kesinleştir, `correlation_id`, audit ve tenant sözleşmesini yaz.

### Faz 1 — Veri modeli ve RBAC (1–2 hafta)

Proje, faz, görev, checklist, milestone, bağımlılık, risk, karar, maliyet ve baseline tablolarını; RLS, migration tekrar çalıştırma ve audit testleriyle oluştur.

### Faz 2 — MOC Uygulama Planı MVP (1–2 hafta)

MOC'den proje oluşturma, değişiklik tipi şablonu, görev sahibi, tarih, durum, checklist, kanıt, liste ve Kanban görünümü.

### Faz 3 — Planlama (1–2 hafta)

Timeline/Gantt, milestone, bağımlılık doğrulama, kritik yol, gecikme etkisi ve takvim.

### Faz 4 — Çapraz modül ve kapanış (2 hafta)

Doküman, Eğitim, Bakım, CAPA, İSG, Ekipman, Tedarikçi ve Depo bağlantıları; PSSR, devreye alma ve etkinlik kontrolü zorunlulukları.

### Faz 5 — Maliyet ve portföy (1 hafta)

Planlanan/gerçekleşen saat, satın alma, dış hizmet, üretim duruşu, bütçe sapması ve tesis/proje portföy panosu.

### Faz 6 — Merkezi otomasyon (1 hafta)

Gecikme, atama, onay, blokaj, abonelik, e-posta ve rapor kurallarının merkezi motoru.

### Faz 7 — Apify pilotu (1–2 hafta)

Tek bir mevzuat/standart kaynağıyla Actor, Dataset, scoped token, webhook, idempotency, kaynak hash'i ve insan onayı pilotu.

### Faz 8 — Pilot ve sertleştirme (1–2 hafta)

Ekipman değişikliği ve doküman revizyonu senaryoları; tenant izolasyonu, eşzamanlı onay, yetkisiz REST, rollback, dosya hatası, mobil ve performans testleri.

## 11. Kabul ölçütleri

- Onaylanan MOC'den tek tıkla değişiklik tipine uygun proje planı oluşur.
- Görev sahibi yalnız kendi görevini güncelleyebilir; onaycı olmayan kişi kapı kararı veremez.
- Bağımlı görev, öncül tamamlanmadan başlatılamaz veya gerekçeli istisna ister.
- Tarih kaydırıldığında ardıl görev etkisi ve bildirim görünür.
- Doküman, eğitim, PSSR ve etkinlik kanıtı olmadan MOC kapanamaz.
- Baseline ile gerçekleşen plan ve bütçe sapması raporlanır.
- Audit kayıtları değiştirilemez; tenant A tenant B kaydını göremez veya değiştiremez.
- Apify çıktısı kaynak, zaman, hash ve insan onayı olmadan MOC kaydına dönüşmez.
- 100.000 görev/MOC kaydında liste ve panel sunucu sayfalamasıyla çalışır.

## 12. Uygulama başlangıcı

İlk geliştirme paketi **Faz 0 + Faz 1 + Faz 2'nin ilk dikey dilimi** olmalı:

1. Proje/faz/görev/milestone tabloları ve RLS.
2. MOC detayında “Uygulama Planı” sekmesi.
3. Değişiklik tipine göre görev şablonu seçimi.
4. Liste görünümü, görev sahibi, tarih, durum, checklist ve kanıt.
5. MOC durum geçişine bağlı kapanış kontrolleri.

Gantt, workload, portföy, maliyet ve Apify; ilk dikey dilim doğrulanıp veri sözleşmesi sabitlendikten sonra eklenir. Böylece MOC'nin canlı akışı bozulmadan proje takibi kontrollü biçimde büyütülür.

## Kaynaklar

- QDATALINE MOC teknik denetim raporu ve mevcut `moc_state_machine_v1.md`.
- [Asana proje zaman çizelgesi ve şablonları](https://asana.com/templates/project-schedule)
- [Asana Timeline](https://help.asana.com/s/article/plan-and-execute-projects-with-timeline?nocache=https%3A%2F%2Fhelp.asana.com%2Fs%2Farticle%2Fplan-and-execute-projects-with-timeline%3Flanguage%3Dit)
- [Asana portföyleri](https://asana.com/features/goals-reporting/portfolios)
- [Jira bağımlılıkları](https://support.atlassian.com/jira-software-cloud/docs/create-or-remove-dependencies-on-your-timeline/)
- [Jira releases](https://support.atlassian.com/jira-software-cloud/docs/manage-releases-in-advanced-roadmaps/)
- [Apify başlangıç](https://docs.apify.com/get-started)
- [Apify schedules](https://docs.apify.com/actors/running/schedules)
- [Apify API ve yetkiler](https://docs.apify.com/integrations/api)

## 13. Uygulama durumu

Faz 0 kapsamı master olarak sabitlendi. Faz 1 için moc_schema_faz_o_proje_takip.sql taslak migration dosyası oluşturuldu. Bu migration canlı veritabanına uygulanmadan önce temiz kurulum, tekrar çalıştırma, RLS tenant izolasyonu ve mevcut MOC durum geçişleriyle çakışma testleri yapılacak. UI ve canlı yayın, bu testlerden sonra Faz 2 dikey diliminde başlayacak; mevcut MOC akışı bu aşamada değiştirilmedi.


### 23.09.2026 — Çalışma alanı seçici uygulandı

MOC.html giriş sonrası iki büyük çalışma alanı kartı gösterecek şekilde güncellendi: MOC ve Proje Yönetimi. MOC kartı mevcut dashboard/nav akışını açar; Proje Yönetimi kartı uygulama planı çalışma alanını açar. Mevcut MOC ekranları korunmuştur. Proje verisi migration uygulanıp UI dikey dilimi tamamlanana kadar proje ekranı hazırlık durumu ve dönüş bağlantılarıyla çalışır. JavaScript syntax kontrolü geçmiştir.


## 13. İlk dikey dilim — uygulama durumu (22.09.2026)

İlk işlevsel sürüm MOC oturumu içindeki iki çalışma alanı seçimini ve **MOC Uygulama Planları** ekranını içerir. MOC çalışma alanı eski ekran akışına döner; Proje Yönetimi, MOC'nin uygulama/doküman/eğitim/PSSR/devreye alma aşamalarındaki kayıtlarından plan oluşturur.

- Proje listesi; durum, görev ilerlemesi ve termin KPI'ları.
- Uygun durumdaki MOC kayıtlarından RPC ile bir kez plan oluşturma ve altı varsayılan faz.
- Proje adı/durumu/lideri/sponsoru/tarihleri/bütçesi düzenleme.
- Faz, sorumlu, öncelik, durum, tarih ve kanıt gereksinimi ile görev ekleme/düzenleme.
- Proje, faz, görev, bağımlılık, milestone, baseline ve maliyet tabloları; tenant bileşik FK'leri, RLS, modül yetkisi, audit ve creator/personel tenant kontrolleri.
- Şema 22.09.2026'da önce staging (`cfcwsoufsnwpycebhxdb`), ardından canlı Eksenpro veritabanına (`bbltvuxxtacrpgrqnfoh`) idempotent olarak uygulandı.

Bu dikey dilim Gantt/Kanban, milestone-baseline arayüzü, dosya/kanıt saklama, otomatik bildirim, MOC kapanış kapıları, portföy raporu ve Apify entegrasyonunu henüz içermez; sonraki fazlarda ele alınacaktır. Proje alanında temel işlevlerin kabul testi sonrası faz 3 planlamasına geçilir.

## 14. Görev panosu ve kilometre taşları (23.09.2026)

İkinci dikey dilim proje detayına erişilebilir liste/Kanban geçişi ekler. Kanban kartları masaüstünde sürüklenerek; klavye ve dokunmatik kullanımında kart içindeki durum seçicisiyle taşınabilir. İptal edilen işler de ayrı sütunda görünür. Kilometre taşları tür/tarih/kanıt gereksinimi ile eklenir ve yetkili kişi tarafından tamamlandı/yeniden açıldı olarak işaretlenir. Bu kayıtlar henüz MOC kapanışını otomatik engellemez; kapanış kapıları ayrı güvenlik kabul testine bırakılmıştır.

## 15. Dil ve güvenli durum güncellemesi (23.09.2026)

Çalışma alanı seçimi TR/EN etiketleriyle birlikte değişir; proje fazlarının standart adları da iki dilde gösterilir. Kanban'daki durum değişimi klavye/dokunmatik seçicisiyle ve sürükle-bırakla yapılabilir; tamamlanan görev tekrar açılırsa ilerleme yüzdesi de tutarlı biçimde sıfırlanır. Milestone tamamlayan kullanıcı DB tetikleyicisiyle oturum kimliğine bağlanır. Bu aşamada milestone kanıt dosyası ve kanıta bağlı kapanış zorunluluğu yoktur; bu, sonraki kabul kapıları işidir.

## Faz O devamı — görev zaman çizelgesi ve başlangıç kontrol listesi (23.09.2026)
- Proje görevlerinde Liste, Kanban ve Zaman çizelgesi görünümleri bulunur. Zaman çizelgesi planlanan başlangıç ve termin alanlarından çizilir; tarihsiz görevler ayrı listelenir, tarihler düzenlenerek çizelgeye alınabilir.
- MOC kaydından proje planı oluşturulduğunda altı faza birer başlangıç görevi eklenir: uygulama planı, doküman güncelleme, eğitim, PSSR/devreye alma, etkinlik kontrolü ve kapanış gözden geçirmesi. Bunlar düzenlenebilir öneri görevleridir; otomatik onay veya zorunlu kapatma kuralı oluşturmaz.
- Canlı ve staging veritabanında yetkili MOC düzenleyicisi ve kaynak kayıt bulunmadığından RPC uçtan uca çağrı testi yapılmadı; yeni veri uydurulmadı. Şema/işlev SQL'i her iki ortamda uygulandı, mevcut kullanıcı verisi değiştirilmedi.

## Ürün adı standardı (23.09.2026)
- Kullanıcıya görünen modül adı **Proje&MOC** olarak birleştirildi. Ana site katalog başlık/etiketleri, giriş ekranı, tarayıcı başlığı, üst çubuk ve çalışma alanı etiketi bu adı kullanır; İngilizce arayüzde “Project & MOC” görünür.
- Uygulama içindeki iki çalışma alanı “MOC” ve “Proje Yönetimi” olarak kalır; modül kodu, Supabase yetkileri, tablolar, URL ve teknik API sözleşmesi `moc` olarak korunur.
