# QDATALINE GELİŞTİRME STANDARDI

> Bu doküman Qdataline platformundaki tüm modüllerin geliştirilmesi, modernizasyonu, UI/UX iyileştirmesi, test edilmesi ve kalite kontrolü sırasında Claude Code tarafından uygulanacak ortak çalışma standardıdır.
>
> Bu doküman mevcut `TASARIM_STANDARDI.md` dosyasının yerine geçmez.
>
> **TASARIM_STANDARDI.md = Qdataline nasıl görünmeli?**  
> **QDATALINE_GELISTIRME_STANDARDI.md = Claude Qdataline üzerinde nasıl çalışmalı?**

---

# 1. TEMEL PRENSİP

Qdataline bir demo veya basit admin paneli değildir.

Hedef:

**Profesyonel, ticari kullanıma hazır, kurumsal B2B SaaS platformu.**

Her geliştirmede şu kriterler birlikte değerlendirilmelidir:

- profesyonel görünüm
- kullanım kolaylığı
- bilgi hiyerarşisi
- tutarlılık
- performans
- erişilebilirlik
- responsive tasarım
- mevcut işlevlerin korunması
- modüller arası görsel bütünlük

Sadece kodun çalışması yeterli değildir.

**Render edilen gerçek kullanıcı arayüzünün kalitesi de doğrulanmalıdır.**

---

# 2. ÇALIŞMAYA BAŞLAMADAN ÖNCE

Kod değiştirmeden önce projeyi incele.

Öncelikle:

1. Proje klasör yapısını incele.
2. Kullanılan teknolojileri belirle.
3. Mevcut component yapısını belirle.
4. Ortak componentleri belirle.
5. Mevcut işlevleri anlamaya çalış.
6. İlgili proje dokümantasyonunu oku.

UI/UX görevi varsa mutlaka:

`TASARIM_STANDARDI.md`

ve varsa:

`07-ui-ux.md`

dosyalarını oku.

İş kurallarını etkileyebilecek görevlerde ilgili:

- gereksinimler
- mimari
- veri modeli
- modül spesifikasyonları
- iş kuralları

dokümanlarını incele.

---

# 3. TASARIM STANDARDININ ÖNCELİĞİ

Qdataline'ın görsel referansı:

`TASARIM_STANDARDI.md`

dosyasıdır.

Bu dosyada tanımlanan:

- renkler
- fontlar
- typography
- sidebar
- topbar
- butonlar
- tablolar
- kartlar
- durum renkleri
- spacing
- border
- shadow
- logo
- marka dili

korunmalıdır.

Yeni tasarım üretirken mevcut Qdataline tasarım sisteminin yerine farklı bir tasarım sistemi oluşturma.

---

# 4. TASARIMI KÖRÜ KÖRÜNE KOPYALAMA

TASARIM_STANDARDI görsel kimliği belirler.

Ancak kötü bir kullanıcı deneyimini korumak zorunda değildir.

Örneğin standartta tanımlanan:

- renk
- font
- buton stili
- sidebar kimliği
- kart görünümü

korunabilir.

Ancak mevcut bir ekranda:

- bilgi hiyerarşisi zayıfsa
- gereksiz büyük alanlar varsa
- önemli bilgi görünmüyorsa
- ekran alanı verimsiz kullanılıyorsa
- kullanıcı çok fazla scroll yapmak zorunda kalıyorsa
- önemli aksiyonlar bulunamıyorsa

layout yeniden düzenlenebilir.

**Marka kimliği sabittir. Kullanıcı deneyimi geliştirilebilir.**

---

# 5. ÖNCE ANALİZ, SONRA KOD

UI/UX geliştirme istendiğinde doğrudan kod değiştirmeye başlama.

Önce mevcut ekranı incele.

Şunları değerlendir:

### Görsel hiyerarşi

- İlk bakışta en önemli bilgi anlaşılıyor mu?
- Başlıklar yeterince belirgin mi?
- Kritik durumlar görünür mü?
- Kullanıcının dikkati doğru yere yönlendiriliyor mu?

### Alan kullanımı

- Gereksiz boşluk var mı?
- İçerik gereksiz sıkışık mı?
- Kartlar gereğinden büyük mü?
- Sidebar gereğinden fazla alan kullanıyor mu?
- Dashboard ekran genişliğini verimli kullanıyor mu?

### Okunabilirlik

- Metinler yeterince büyük mü?
- Kontrast yeterli mi?
- Secondary text gereğinden soluk mu?
- Yoğun veri rahat taranabiliyor mu?

### Etkileşim

- Kullanıcı nereye tıklayacağını anlayabiliyor mu?
- Primary action belirgin mi?
- Hover/focus durumları anlaşılır mı?
- Tıklanabilir öğeler tıklanabilir görünüyor mu?

### Tutarlılık

- Aynı tür öğeler aynı görünüyor mu?
- Butonlar tutarlı mı?
- Kartlar tutarlı mı?
- Durum göstergeleri tutarlı mı?
- Spacing tutarlı mı?

Önce problemleri belirle.

Sonra kod değişikliklerine başla.

---

# 6. DASHBOARD STANDARDI

Dashboard yalnızca bilgi göstermek için değil:

**kullanıcının neye dikkat etmesi gerektiğini anlaması için tasarlanmalıdır.**

Dashboard hiyerarşisi mümkün olduğunca:

1. Kritik durum
2. Aksiyon gerektiren durum
3. Genel performans
4. Trend
5. Detay

mantığında kurulmalıdır.

---

# 7. KPI KARTLARI

Her KPI iş açısından anlamlı olmalıdır.

KPI mümkünse:

**Değer + Açıklama + Durum + Gerekirse aksiyon**

sunmalıdır.

Örneğin yalnızca:

`59%`

yerine kullanıcı bunun ne anlama geldiğini anlamalıdır.

KPI'lar gereksiz büyük olmamalıdır.

Ekrandaki tüm KPI'lar aynı görsel ağırlığa sahip olmamalıdır.

Kritik KPI gerektiğinde daha fazla dikkat çekebilir.

---

# 8. KRİTİK DURUM ALANLARI

Çok sayıda kayıt büyük tek bir kart içinde sürekli gösterilmemelidir.

Örneğin:

`Geçerliliği Dolmuş Eğitim (44)`

gibi bir durumda dashboard üzerinde 44 kaydın tamamını göstermeye çalışma.

Tercih:

- en kritik birkaç kayıt
- toplam kayıt sayısı
- "Tümünü Gör"
- filtrelenmiş detay ekranına geçiş

olmalıdır.

Dashboard özet ekranıdır.

Detay ekranının yerine geçmemelidir.

---

# 9. DURUM GÖSTERİMLERİ

Durumu yalnızca renk ile anlatma.

Örneğin:

🔴 kırmızı

tek başına yeterli değildir.

Tercihen:

`Gecikmiş`

`Yaklaşıyor`

`Güncel`

gibi metinsel durum da bulunmalıdır.

TASARIM_STANDARDI içerisindeki semantic renkler kullanılmalıdır.

---

# 10. SIDEBAR

Sidebar:

- hızlı taranabilir
- sade
- tutarlı
- yeterince kompakt

olmalıdır.

Aktif modül açıkça anlaşılmalıdır.

Sidebar gereğinden fazla geniş olmamalıdır.

İkon ve metin hizaları tutarlı olmalıdır.

Menü kategorileri gerektiğinde gruplanmalıdır.

Uzun menülerde bilgi mimarisi yeniden değerlendirilmelidir.

---

# 11. TOPBAR

Topbar mümkün olduğunca:

- bağlam
- şirket
- ekran
- kullanıcı
- bildirim

bilgilerini düzenli sunmalıdır.

Gereksiz yüksek olmamalıdır.

Dashboard alanından gereksiz yer çalmamalıdır.

---

# 12. ARAMA

Arama alanı sadece dekoratif olmamalıdır.

Placeholder kullanıcıya ne arayabileceğini açıklamalıdır.

Örneğin:

`Personel veya eğitim ara`

gibi.

Arama sonuçları anlaşılır olmalıdır.

Gerekirse klavye kullanımını destekle.

---

# 13. TABLOLAR

Kurumsal Qdataline uygulamalarında tablolar önemli componentlerdir.

Tablolarda değerlendir:

- kolon genişlikleri
- hizalama
- okunabilirlik
- sorting
- filtreleme
- arama
- pagination
- sticky header
- durum badge'leri
- satır aksiyonları

Gereksiz yatay scroll oluşturmamaya çalış.

Çok fazla satır aksiyonu varsa overflow menu değerlendir.

---

# 14. FORMLAR

Formlar kullanıcıyı yormamalıdır.

İlgili alanları grupla.

Uzun formları gerektiğinde bölümlere ayır.

Placeholder'ı label yerine kullanma.

Zorunlu alanları açıkça göster.

Hata mesajı yalnızca hata olduğunu değil mümkünse nasıl düzeltileceğini de açıklamalıdır.

---

# 15. EMPTY STATE

Boş ekran bırakma.

Örneğin:

`Henüz eğitim planı bulunmuyor.`

ve uygun olduğunda:

`Yeni Eğitim Planı`

aksiyonu gösterilebilir.

---

# 16. LOADING STATE

Veri yüklenirken kullanıcı uygulamanın bozulduğunu düşünmemelidir.

Gerektiğinde:

- skeleton
- spinner
- progress

kullan.

Ancak gereksiz animasyon oluşturma.

---

# 17. ERROR STATE

Teknik hata mesajlarını doğrudan kullanıcıya gösterme.

Örneğin:

`Database query failed`

yerine:

`Veriler yüklenemedi. Tekrar deneyin.`

gibi anlaşılır mesaj kullan.

Teknik detay gerekiyorsa log tarafında tutulmalıdır.

---

# 18. RESPONSIVE KONTROL

Önemli UI değişiklikleri en az şu genişliklerde kontrol edilmelidir:

- 1440px desktop
- 1024px laptop
- 768px tablet
- 390px mobile

Desktop tasarımını yalnızca küçültme.

Gerekirse layout değiştir.

Özellikle kontrol et:

- sidebar
- tablolar
- dashboard grid
- KPI kartları
- formlar
- modal
- grafikler
- aksiyon butonları

---

# 19. ERİŞİLEBİLİRLİK

Kontrol et:

- metin kontrastı
- font büyüklüğü
- keyboard navigation
- focus state
- form label
- touch target
- renk bağımlılığı

Dark theme olması düşük kontrastlı metin kullanmak anlamına gelmez.

Okunabilirlik estetikten önce gelir.

---

# 20. ORTAK COMPONENT KORUMASI

Bir shared component değiştirilmeden önce:

1. Nerelerde kullanıldığını belirle.
2. Değişikliğin diğer ekranları etkileyip etkilemeyeceğini kontrol et.
3. Mümkün olduğunca backward-compatible değişiklik yap.
4. Tek bir ekranı düzeltmek için diğer ekranları bozma.
5. Değişiklikten etkilenen önemli ekranları kontrol et.

---

# 21. İŞ MANTIĞINI KORU

UI görevi sırasında:

- hesaplamaları değiştirme
- database yapısını değiştirme
- veri silme
- mevcut workflow'u değiştirme
- yetkilendirmeyi değiştirme
- validasyon kurallarını kaldırma
- çalışan özelliği kaldırma

UI değişikliği iş mantığı değişikliği gerektiriyorsa bunu ayrı konu olarak değerlendir.

---

# 22. VERİ GÜVENLİĞİ

UI problemi çözmek için:

- database resetleme
- tablo silme
- production verisi silme
- RLS kapatma
- authentication bypass etme

gibi işlemler yapma.

Frontend içinde:

- API secret
- service role key
- database password
- authentication secret

bulundurma.

---

# 23. MODÜL İZOLASYONU

Bir modül üzerinde çalışırken diğer Qdataline modüllerini gereksiz yere değiştirme.

Ortak altyapı değişikliği gerekiyorsa etkisini değerlendir.

Bir modülün lokal problemi global component değiştirilmeden çözülebiliyorsa lokal çözümü tercih et.

---

# 24. TARAYICI KONTROLÜ

Frontend değişikliği tamamlandıktan sonra mümkünse gerçek uygulamayı çalıştır.

Sadece kaynak kodu okuyarak tasarımın doğru olduğuna karar verme.

Kontrol et:

- render
- spacing
- alignment
- overflow
- typography
- responsive
- hover
- focus
- modal
- dropdown
- table
- chart
- navigation

---

# 25. CHROME DEVTOOLS

Chrome DevTools erişimi mevcutsa kullan.

Kontrol et:

- console errors
- network errors
- layout
- overflow
- responsive görünüm
- performans sorunları

Bulunan problemleri gider.

---

# 26. PLAYWRIGHT

Playwright mevcutsa önemli kullanıcı akışlarını test et.

Örneğin:

- navigasyon
- arama
- filtreleme
- kayıt ekleme
- düzenleme
- modal açma/kapatma
- form validation
- responsive menu

Test amacı sadece test üretmek değildir.

Gerçek kullanıcı akışının çalıştığını doğrulamaktır.

---

# 27. İTERATİF GELİŞTİRME

Önemli UI görevlerini tek turda tamamlanmış kabul etme.

## TUR 1 — Yapısal

Kontrol et:

- layout
- bilgi hiyerarşisi
- navigasyon
- içerik organizasyonu

## TUR 2 — Görsel

Kontrol et:

- typography
- spacing
- alignment
- renk
- component tutarlılığı

## TUR 3 — Kullanılabilirlik

Kontrol et:

- butonlar
- formlar
- arama
- filtreler
- tablolar
- modal
- kullanıcı akışı

## TUR 4 — Responsive

Kontrol et:

- desktop
- laptop
- tablet
- mobile

## TUR 5 — Final Polish

Ara:

- hizalama hatası
- gereksiz boşluk
- küçük metin
- düşük kontrast
- tutarsız component
- gereksiz görsel karmaşa
- eksik hover/focus
- overflow
- kırık layout

Gerekli düzeltmeleri yap.

---

# 28. DEFINITION OF DONE

Bir UI görevi ancak aşağıdaki şartlar sağlandığında tamamlanmış kabul edilir:

- Kod çalışıyor.
- Mevcut işlevler korunuyor.
- TASARIM_STANDARDI ile uyumlu.
- Gerçek arayüz kontrol edildi.
- Console kritik hata içermiyor.
- Layout bozuk değil.
- Desktop kontrol edildi.
- Tablet/mobile davranışı değerlendirildi.
- Önemli kullanıcı akışları çalışıyor.
- Görsel tutarsızlıklar giderildi.
- Son kalite turu gerçekleştirildi.

---

# 29. SON KALİTE SORULARI

Görevi bitirmeden önce kendine sor:

**Bu ekran ticari bir B2B SaaS ürünü seviyesinde mi?**

**Kullanıcı ilk birkaç saniyede önemli bilgiyi anlayabiliyor mu?**

**Ekran alanı verimli kullanılıyor mu?**

**Gereksiz görsel karmaşa var mı?**

**Metinler rahat okunuyor mu?**

**Kritik durumlar anlaşılır mı?**

**Aksiyonlar bulunabilir mi?**

**Qdataline'ın diğer modülleriyle aynı ürünün parçası gibi görünüyor mu?**

**Gerçek tarayıcı görünümünü kontrol ettim mi?**

**İlk sonuçla yetinmeyip son bir kalite kontrolü yaptım mı?**

Önemli bir sorunun cevabı "Hayır" ise geliştirmeye devam et.

---

# 30. VARSAYILAN UI GÖREV AKIŞI

Kullanıcı bir ekranı:

- geliştir
- profesyonelleştir
- modernize et
- düzenle
- iyileştir

dediğinde varsayılan süreç:

**İNCELE → KARŞILAŞTIR → PLANLA → UYGULA → ÇALIŞTIR → GÖR → TEST ET → ELEŞTİR → DÜZELT → TEKRAR KONTROL ET**

olmalıdır.

İlk çalışan sonuç nihai sonuç değildir.

**Qdataline kalite hedefi: tutarlı, profesyonel, kullanılabilir ve ticari ürün seviyesinde arayüz.**