# TASARIM STANDARDI — Qdataline Platformu

> **Bu dosya, tüm Qdataline modüllerinin (Ekipman, Q-Kalite, Q-Tedarikçi ve gelecek modüller)
> ortak görsel kimlik standardıdır.** Değerler **Q-Tedarikçi Yönetimi** modülünün mevcut,
> onaylı arayüzünden birebir çıkarılmıştır ve REFERANS kabul edilir.
>
> **Yeni bir modüle başlarken:** Bu dosyayı Claude Code'a ilk iş olarak okut ve
> *"bu standarda birebir uy"* de. Mevcut bir modülü hizalarken: aşağıdaki her bölümü
> tek tek karşılaştır, farklıları bu değerlere çek.
>
> **Not (koyu tema):** Q-Tedarikçi'nin CSS'inde taban stiller açık renklidir (beyaz zemin),
> `</style>` sonundaki "FAZ 1 koyu tema override" bloğu bunları koyuya çevirir.
> **Aşağıdaki tüm değerler RENDER EDİLEN (nihai, koyu) hâldir** — kopyalarken doğrudan bunları kullan.

---

## 0. FONT + FAVICON YÜKLEME (head'e)

```html
<!-- Fontlar -->
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&family=Space+Grotesk:wght@400;500;600;700&display=swap" rel="stylesheet">

<!-- Favicon (bkz. §6) -->
<link rel="icon" href="data:image/svg+xml,...Q sembolü...">
```

---

## 1. RENK PALETİ

Tümü `:root` altında CSS değişkeni olarak tanımlanır. **Birebir kopyala:**

```css
:root{
  color-scheme:dark;

  /* Marka yeşilleri */
  --forest:#10241B;      /* koyu orman (başlık zemini, thead) */
  --forest-2:#7CD3AD;    /* açık orman (ikincil vurgu metni) */
  --forest-3:#1E6B52;    /* orta orman (hover) */
  --leaf:#10B981;        /* ANA marka yeşili */
  --leaf-d:#34D399;      /* açık yeşil (link/hover metin) */
  --lime:#A3E635;        /* lime vurgu */
  --ink-on-accent:#07120C; /* degrade buton üzerindeki KOYU metin */

  /* Zemin / yüzey / kenarlık */
  --sand:#0C1510;        /* SAYFA ZEMİNİ (en arka) */
  --card:#121A15;        /* KART / panel / topbar / sidebar zemini */
  --mint:#14261C;        /* aktif menü öğesi zemini */
  --mint-2:#101A14;      /* hover / iç alan zemini */
  --line:#1E2B22;        /* ana kenarlık */
  --line-2:#19241D;      /* ikincil (daha ince) kenarlık */

  /* Metin */
  --ink:#F2FBF6;         /* ANA METİN (neredeyse beyaz) */
  --muted:#8FA397;       /* ikincil / soluk metin */
  --accent:#D9C06A;      /* kum/altın nötr vurgu */

  /* Durum renkleri (metin + rgba zemin) — DEĞİŞTİRME */
  --ok:#34D399;   --ok-bg:rgba(16,185,129,.14);   /* başarılı / güncel */
  --warn:#F0A93B; --warn-bg:rgba(240,169,59,.14);  /* uyarı / yaklaşan */
  --crit:#F87171; --crit-bg:rgba(248,113,113,.14); /* kritik / geçmiş */
  --miss:#93A79B; --miss-bg:rgba(147,167,155,.12); /* eksik / pasif */
  --na:#5E7268;   --na-bg:rgba(94,114,104,.18);    /* uygulanamaz */

  /* Bilgi renkleri */
  --blue:#6FABEF;   --blue-bg:rgba(96,165,250,.14);
  --purple:#B9A5F2; --purple-bg:rgba(167,139,250,.15);

  /* Gölge + scrollbar */
  --shadow:0 1px 2px rgba(0,0,0,.3),0 8px 22px rgba(0,0,0,.28);
  --bar-track:#243129; --sb-thumb:#22332A; --sb-thumb-h:#2E4437;
}
```

### Marka degradesi (buton + wordmark)
- **Dolgu degradesi (butonlar, aktif segment):** `linear-gradient(135deg,#059669,#84CC16)`
  → hover: `linear-gradient(135deg,#10B981,#A3E635)`
- **Wordmark metin degradesi ("data" kelimesi):** `linear-gradient(90deg,#10B981,#A3E635)`
- **Logo SVG degradeleri:** `qg` (135°, `#059669`→`#84CC16`) ve `qgline` (yatay, `#10B981`→`#A3E635`)

---

## 2. TİPOGRAFİ

| Kullanım | Font ailesi |
|---|---|
| **Başlıklar + wordmark** (`h1,h2,h3,h4,.logo-txt .n`) | `"Space Grotesk","Inter","Segoe UI",system-ui,sans-serif` · `letter-spacing:.2px` |
| **Gövde** (`body`) | `"Inter","Segoe UI",system-ui,-apple-system,Roboto,Helvetica,Arial,sans-serif` |
| **Monospace** (sayılar, kodlar) | `"SFMono-Regular",Consolas,"Liberation Mono",Menlo,monospace` · `font-variant-numeric:tabular-nums` |

**Ağırlıklar:** Inter → 400 / 600 / 700 / 800 · Space Grotesk → 400 / 500 / 600 / 700

**Boyut ölçeği (nihai değerler):**

| Öğe | Boyut | Ağırlık | Notlar |
|---|---|---|---|
| Gövde (`body`) | 14px | 400 | `line-height:1.45` |
| Sayfa başlığı (`.topbar h1`) | 16px | 700 | |
| Bölüm başlığı (`h2.section`) | 17px | — | `letter-spacing:.2px` |
| Bölüm alt yazısı (`.section-sub`) | 12.5px | — | renk `--muted` |
| Menü kategori başlığı (`.nav-lbl`) | 10px | 700 | UPPERCASE · `letter-spacing:1px` |
| Menü öğesi (`.nav-item`) | 13px | 600 | |
| KPI değeri (`.kpi .val`) | 30px | 800 | `letter-spacing:-.5px` |
| KPI etiketi (`.kpi .lbl`) | 10.5px | 700 | UPPERCASE · `letter-spacing:.5px` |
| Buton (`button,.btn`) | 12.5px | 600 | |
| Wordmark ana satır (`.logo-txt .n`) | 16px | 500 | `letter-spacing:.5px` (koyu tema) |
| Wordmark alt satır / modül adı (`.logo-txt .s`) | 9.5px | — | UPPERCASE · `letter-spacing:.4px` · `--muted` |

---

## 3. ÜST BAR (topbar)

```css
.topbar{
  background:var(--card);
  border-bottom:1px solid var(--line);
  padding:14px 26px;
  display:flex; align-items:center; gap:16px;
  position:sticky; top:0; z-index:40; flex-wrap:wrap;
}
.topbar h1{font-size:16px; margin:0; font-weight:700}   /* modül/ekran başlığı */
.topbar .crumb{font-size:12px; color:var(--muted)}      /* breadcrumb */
```

- İçerik alanı: `.content{padding:24px 26px; max-width:1580px; width:100%}`
- **Marka/logo üst barda DEĞİL, sol menünün tepesindedir** (bkz. §4). Üst bar yalnız aktif ekranın başlığını + breadcrumb + aksiyon butonlarını taşır.

---

## 4. SOL MENÜ (sidebar) + LOGO/BAŞLIK YERLEŞİMİ

### 4.1 Çerçeve
```css
aside.side{
  width:248px; flex-shrink:0;
  background:var(--card); color:var(--ink);
  display:flex; flex-direction:column;
  position:sticky; top:0; height:100vh;
  border-right:1px solid var(--line);
  overflow-y:auto; transition:width .18s ease;
}
.side.collapsed{width:66px}   /* daraltılmış hâl */
```

### 4.2 Marka bloğu (logo + Qdataline + modül adı) — **REFERANS YERLEŞİM**

HTML iskeleti (sol menünün EN ÜSTÜ):
```html
<aside class="side">
  <div class="brand">
    <div class="logo-row brand-toggle" id="brandToggle" title="Menüyü aç / kapat" role="button" tabindex="0">
      <svg class="logo-mark" viewBox="-100 -100 200 200" aria-label="Qdataline">…Q sembolü (§6)…</svg>
      <div class="logo-txt">
        <div class="n">Q<b>data</b>line</div>   <!-- wordmark: "data" kalın + degrade -->
        <div class="s">Q-Tedarikçi Yönetimi</div> <!-- MODÜL ADI (her modülde değişir) -->
      </div>
    </div>
    <div class="side-search">…arama kutusu (standartta HER ZAMAN var)…</div>
  </div>
  <nav class="snav">…</nav>
</aside>
```

```css
.brand{padding:15px 15px 12px; border-bottom:1px solid var(--line-2)}
.logo-row{display:flex; align-items:center; gap:11px}
.logo-mark{width:54px; height:32px; flex-shrink:0}   /* nihai (koyu tema) boyut */
.logo-txt .n{font-size:16px; font-weight:500; letter-spacing:.5px; color:var(--ink); line-height:1}
.logo-txt .n b{                                       /* "data" kelimesi */
  font-weight:700;
  background:linear-gradient(90deg,#10B981,#A3E635);
  -webkit-background-clip:text; background-clip:text; -webkit-text-fill-color:transparent;
}
.logo-txt .s{font-size:9.5px; color:var(--muted); letter-spacing:.4px; margin-top:3px; text-transform:uppercase}
```

> **Kural:** Sol üstte **logo sembolü + "Qdataline" wordmark ("data" kalın+degrade)**, hemen ALTINDA
> küçük UPPERCASE **modül adı** = `[MODÜL ADI]` (her modülde değişen TEK yer; Q-Tedarikçi'de
> `Q-Tedarikçi Yönetimi`). Logo + "Qdataline" wordmark ise TÜM modüllerde AYNIDIR.

### 4.3 Kategori başlığı + menü öğeleri
```css
.nav-lbl{                    /* kategori başlığı (ör. "Belge Yönetimi") */
  font-size:10px; text-transform:uppercase; letter-spacing:1px;
  color:#5F7266; font-weight:700; padding:12px 10px 6px;
}
.nav-item{                   /* menü öğesi */
  display:flex; align-items:center; gap:11px;
  padding:9px 11px; border-radius:9px;
  color:#C9D8CF; font-size:13px; font-weight:600;
  border:none; background:transparent; width:100%; text-align:left;
  transition:.13s; margin-bottom:2px; cursor:pointer;
}
.nav-item .ico{width:19px; height:19px; flex-shrink:0}   /* ikon boyutu */
.nav-item:hover{background:var(--mint-2)}                 /* HOVER */
.nav-item.on{background:var(--mint); color:var(--ink); box-shadow:inset 3px 0 0 var(--leaf)} /* AKTİF: sol kenarda 3px yeşil şerit */
.nav-item .cnt{                                          /* sağdaki sayaç rozeti */
  margin-left:auto; font-size:11px; padding:1px 8px; border-radius:20px; font-weight:800;
  background:#1C2A21; color:#AFC6B8;
}
```
- **Sayaç rozetleri renk kodlu olabilir** (durum renkleri + `-bg`): kritik=`--crit`, uyarı=`--warn`,
  bilgi=`--blue`, başarılı=`--ok` (her biri kendi `-bg` zeminiyle).

---

## 5. HAMBURGER / LOGO-MENÜ DAVRANIŞI

> **Ayrı hamburger (☰) butonu YOKTUR.** Sol menünün **logo satırı (`.brand-toggle#brandToggle`)
> menü aç/kapat düğmesidir.**

- **Etkileşim:** tıklama · `Enter` · `Space` → `toggleNav()` → `aside.side`'a `.collapsed` sınıfı ekler/kaldırır.
- **Durum kalıcılığı:** `localStorage` anahtarı `qs_nav_collapsed` (`'1'`/`'0'`).
- **Görsel gösterge (çip):** logo satırının sağında `::after` ile `‹‹` (açık) / `››` (kapalı) işareti.
- **Daraltılınca (`.collapsed`, 66px):** wordmark + modül adı + kategori başlıkları + sayaçlar + arama gizlenir;
  yalnız ikonlar ortalı kalır. Alt menü butonları ikon/emoji'ye düşer.

```css
.brand-toggle{cursor:pointer; position:relative}
.brand-toggle:hover .logo-txt .n{filter:brightness(1.12)}
.brand-toggle::after{content:"‹‹"; position:absolute; top:14px; right:12px; font-size:13px; color:var(--muted); font-weight:800; line-height:1}
.side.collapsed .brand-toggle::after{content:"››"; right:0; left:0; text-align:center; top:auto; bottom:-2px}
```
```js
function toggleNav(){
  navCollapsed = !navCollapsed;
  applyNavCollapsed(navCollapsed);
  try{ localStorage.setItem('qs_nav_collapsed', navCollapsed?'1':'0'); }catch(e){}
}
var brandT = document.getElementById('brandToggle');
if(brandT){
  brandT.onclick = toggleNav;
  brandT.onkeydown = function(e){ if(e.key==='Enter'||e.key===' '){ e.preventDefault(); toggleNav(); } };
}
```

---

## 6. FAVICON

- **Kaynak = Q-Tedarikçi'nin sol menüdeki `.logo-mark` SVG'si** (ayrıntılı, takımyıldız noktalı Q
  sembolü: dairesel yeşil yay + yükselen "dataline" zigzag çizgisi + 3 nokta + ince bağlayıcı).
  Favicon, bu logonun **sadeleştirilmiş** hâlidir: küçük boyutta (16px) kaybolacak ince detaylar
  (takımyıldız noktaları, ince bağlayıcı çizgi, ok ucu) atılır; **dairesel yay + zigzag "dataline"
  çizgisi** korunur, düz marka renkleriyle (`#10B981` yay, `#84CC16` çizgi).
- **Boyutlar:** 16 / 32 / 180px. Küçük boyutta yukarıdaki sadeleştirilmiş hâl; büyük boyutta
  (180px) tam menü logosuna yaklaşan (degradeli, noktalı) hâl kullanılabilir.
- **Uygulama biçimi:** SVG'yi `data:image/svg+xml,...` olarak **inline** `<link rel="icon">` içine göm
  (harici dosya bağımlılığı olmasın; her modül tek dosya). SVG ölçeklendiğinden tek kaynak yeter;
  gerekirse ondan üretilmiş `.ico`/`.png` eklenir.
- **⚠️ Terk edilen:** Q-Tedarikçi'nin ESKİ inline favicon'u (basit yay + TEK düz çapraz çizgi) menü
  logosuyla TUTARSIZDI ve terk edildi. Yerine, menü logosundan türetilen aşağıdaki favicon geçti —
  **Q-Tedarikçi'nin kendi kodunda da güncellendi** (artık favicon = menü logosunun küçültülmüş hâli):
```html
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='-100 -100 200 200'%3E%3Ccircle cx='0' cy='0' r='78' fill='none' stroke='%2310B981' stroke-width='18' stroke-linecap='round' stroke-dasharray='425 65' stroke-dashoffset='-34' transform='rotate(45)'/%3E%3Cpath d='M 30 30 L 58 58 L 84 42' fill='none' stroke='%2384CC16' stroke-width='18' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E">
```
- **Hedef:** üç modülün de AYNI bu favicon'u (menü logosunun sadeleştirilmiş hâli) kullanması
  (şu an her modül farklı ikonda).

---

## 7. SEKME BAŞLIĞI (`<title>`) FORMATI

- **Standart format:** `[Modül Adı] · Qdataline` (Q-Tedarikçi'nin MEVCUT, doğru kullanımı — referans budur)
  - Q-Tedarikçi → `Q-Tedarikçi Yönetimi · Qdataline`
  - Ekipman → `Ekipman Yönetimi · Qdataline`
  - Q-Kalite → `Şikayet ve DÖF Yönetimi · Qdataline`
- Ayraç: orta nokta `·` (U+00B7), iki yanında boşluk. Modül adı önce, `Qdataline` sonra.
- **Not:** Diğer modüller (Ekipman, Q-Kalite) bu formata geçirilecek; Q-Tedarikçi'nin başlığı DEĞİŞMEZ.

---

## 8. BUTON / KART STİLLERİ

### 8.1 Köşe yuvarlaklığı (radius) ölçeği
| Öğe | radius |
|---|---|
| Buton, giriş alanı (input/select), arama kutusu | **8px** |
| Menü öğesi (`.nav-item`), mail kutusu (`.mail-box`) | **9px** |
| Belge eki / sürükle-bırak (`.doc-attach`, `.dropzone`) | **10px** |
| KPI kartı (`.kpi`) | **11px** |
| Panel/kart (`.panel`) | **12px** |
| Uyarı çipi (`.alert-chip`) | **12px** (sol kenar 4px renkli) |
| Grafik kartı (`.chart-card`), modal (`.modal`) | **14px** |
| Rozet / hap / sayaç (`.cnt`, `.pill`, `.cat-chip`) | **20px** (tam yuvarlak) |
| Yardım butonu (`.help-btn`) | **50%** (daire) |

### 8.2 Butonlar
```css
button,.btn{
  font-family:inherit; font-size:12.5px; font-weight:600;
  border-radius:8px; border:1px solid transparent;
  padding:8px 14px; transition:.12s; cursor:pointer; white-space:nowrap;
}
/* Ana (degrade) buton */
.btn-leaf{background:linear-gradient(135deg,#059669,#84CC16); color:var(--ink-on-accent); font-weight:700}
.btn-leaf:hover{background:linear-gradient(135deg,#10B981,#A3E635)}
/* İkincil (çerçeveli) buton */
.btn-line{background:var(--card); color:var(--ink); border-color:var(--line)}
.btn-line:hover{border-color:var(--leaf); color:var(--leaf-d)}
```

### 8.3 Kartlar
```css
/* Panel (ana içerik kartı) */
.panel{background:var(--card); border:1px solid var(--line); border-radius:12px;
       box-shadow:var(--shadow); overflow:hidden; margin-bottom:20px}

/* KPI kartı — sol kenarda 4px renkli vurgu şeridi */
.kpi{background:var(--card); border:1px solid var(--line); border-radius:11px;
     padding:15px 16px; box-shadow:var(--shadow); position:relative; overflow:hidden}
.kpi::before{content:""; position:absolute; left:0; top:0; bottom:0; width:4px; background:var(--leaf)}
.kpi.clk{cursor:pointer; transition:transform .12s, box-shadow .12s, border-color .12s}
.kpi.clk:hover{transform:translateY(-2px); box-shadow:0 6px 18px rgba(0,0,0,.45); border-color:var(--leaf)}

/* Grafik kartı */
.chart-card{background:var(--card); border:1px solid var(--line); border-radius:14px;
            box-shadow:var(--shadow); padding:16px 18px; transition:transform .14s, box-shadow .14s}
.chart-card:hover{box-shadow:0 10px 26px rgba(0,0,0,.4)}

/* Modal */
.modal{background:var(--card); border-radius:14px; width:100%; max-width:720px;
       box-shadow:0 24px 60px rgba(0,0,0,.6); overflow:hidden; animation:pop .18s ease}
.overlay{background:rgba(3,9,6,.68)}
```

### 8.4 Hover / animasyon dili (tutarlılık için)
- **Standart geçiş süresi:** `.12s`–`.14s` (butonlar/kartlar), `.13s` (menü), `.18s` (panel/modal giriş).
- **Kart hover:** `translateY(-2px)` + gölgeyi büyüt + kenarlığı `--leaf`'e çevir.
- **Giriş animasyonları:** `@keyframes fade{from{opacity:0;transform:translateY(4px)}to{opacity:1;transform:none}}` (ekran),
  `pop .18s` (modal).
- **Buton hover:** degrade butonlarda degradeyi parlat; çerçeveli butonlarda kenarlık+metni `--leaf-d`,
  zemini `--mint-2`.
- **Scrollbar:** `11px`; thumb `var(--sb-thumb)` (#22332A), radius 6px, hover `var(--sb-thumb-h)`.

---

## 9. ÖZET — YENİ MODÜLDE İLK 5 İŞ

1. Head'e Inter + Space Grotesk fontlarını ve **§6 inline favicon**'u ekle.
2. `<title>` → `[Modül Adı] · Qdataline` (§7).
3. `:root`'a **§1 tüm renk değişkenlerini** birebir koy (koyu tema).
4. Sol menü tepesine **§4.2 marka bloğunu** kur (logo + Q**data**line + altında UPPERCASE modül adı) ve
   **§5 logo-menü davranışını** bağla (hamburger yok).
5. Buton/kart/menü stillerini **§2, §4.3, §8** ölçeğine göre uygula; durum renkleri (§1) DEĞİŞMEZ.
