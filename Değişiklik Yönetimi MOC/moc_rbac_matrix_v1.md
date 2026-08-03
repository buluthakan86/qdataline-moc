# MOC Modülü — RBAC İzin Matrisi v1

> Referanslar: `moc_api_endpoints_v1-1.md`, `moc_state_machine_v1.md`
> Mevcut Ekipman Yönetimi projesinin rol altyapısına **MOC izin seti** olarak eklenir.
> Yeni rol tablosu açılmaz; mevcut role-permission yapınıza aşağıdaki izin kodları tanımlanır.

> **UYGULANAN MODEL (Faz B, canlı) — bu dosyanın §1/§2'sinden farklı,
> bkz. §6.** Aşağıdaki 14 izin kodu × 8 rol tasarımı **uygulanmadı**.
> Gerçekte platformun paylaşılan `profiles.role` (ADMIN/EDITOR/VIEWER)
> kolonu kullanılıyor; `MOC.html` `canDo(action)` fonksiyonu bunu MOC
> aksiyonlarına eşliyor (bkz. §6 — "Gerçek Uygulanan Model"). §1–§5
> orijinal vizyon/kapsam referansı olarak korunuyor, ileride ayrıntılı
> role-permission tablosuna geçilirse yol haritası olarak kullanılabilir.

---

## 1. İzin Kodları (14 izin)

| Kod | Açıklama |
|---|---|
| `moc.view` | MOC kayıtlarını görüntüleme (liste, detay, timeline, dashboard) |
| `moc.create` | Yeni talep oluşturma, kendi DRAFT'ını düzenleme/gönderme |
| `moc.screen` | Ön tarama: sınıflandırma, RIK muafiyeti, reddetme |
| `moc.coordinate` | Akış yürütme: aksiyon ekleme, faz geçişleri, doküman/eğitim adımları |
| `moc.risk` | Risk değerlendirme ekleme/düzenleme, RISK→REVIEW geçişi |
| `moc.review` | Teknik inceleme, REVIEW→APPROVAL geçişi veya revizyona iade |
| `moc.approve` | Onay zincirinde karar verme (kendisine atanmış adımlarda) |
| `moc.pssr` | PSSR checklist oluşturma/doldurma, RELEASED kararı |
| `moc.close` | STARTUP→CLOSED kapanış onayı |
| `moc.temp.manage` | Geçici değişiklik uzatma talebi ve eski duruma dönüş kaydı |
| `moc.reopen` | Terminal durumdan (CLOSED/REJECTED) gerekçeli yeniden açma |
| `moc.admin` | Akış/şablon konfigürasyonu, kategori-tür yönetimi, izin atama |
| `moc.report` | KPI dashboard ve rapor dışa aktarımı |
| `moc.audit.view` | Audit log ham kayıtlarını görüntüleme |

---

## 2. Rol × İzin Matrisi (8 rol)

| İzin | Sistem Yön. | Talep Sahibi* | MOC Koord. | Alan Sorumlusu | HSE/İSG | Teknik Ekip | Onay Otoritesi | PSSR Ekibi |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `moc.view` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `moc.create` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `moc.screen` | ✅ | — | ✅ | — | — | — | — | — |
| `moc.coordinate` | ✅ | — | ✅ | — | — | — | — | — |
| `moc.risk` | ✅ | — | — | ➖¹ | ✅ | ➖¹ | — | — |
| `moc.review` | ✅ | — | — | ✅ | — | ✅ | — | — |
| `moc.approve` | ✅ | — | — | ➖² | ➖² | ➖² | ✅ | — |
| `moc.pssr` | ✅ | — | — | — | ✅ | — | — | ✅ |
| `moc.close` | ✅ | — | ✅ | — | — | — | — | — |
| `moc.temp.manage` | ✅ | — | ✅ | — | — | — | — | — |
| `moc.reopen` | ✅ | — | — | — | — | — | — | — |
| `moc.admin` | ✅ | — | — | — | — | — | — | — |
| `moc.report` | ✅ | — | ✅ | ✅ | ✅ | ✅ | ✅ | — |
| `moc.audit.view` | ✅ | — | ✅ | — | ✅ | — | — | — |

\* **Talep Sahibi** ayrı bir rol değil, tüm oturum kullanıcılarının taban iznidir (herkes MOC başlatabilir — PSM iyi uygulaması).
¹ Katkı verebilir (risk kaydı ekleme) ama HSE onayı olmadan RISK→REVIEW geçişi yapamaz.
² `moc.approve` genel izindir; kimin hangi adımda karar verebileceğini **onay zinciri ataması** (`moc_approvals.role_code`) belirler. İzin + atama birlikte gerekir.

---

## 3. Kayıt Bazlı (Satır Seviyesi) Kurallar

İzin matrisi "ne yapabilir"i, aşağıdaki kurallar "hangi kayıtta"yı belirler.
Service katmanında izin kontrolünden **sonra** uygulanır:

1. **Sahiplik:** DRAFT'taki talebi yalnız `initiator_id` düzenler/siler (koordinatör hariç).
2. **Onay ataması:** `moc.approve` izni olsa bile kullanıcı yalnız kendisine (veya vekâleten) atanmış `moc_approvals` satırında karar verebilir.
3. **Kendi talebini onaylayamaz:** `initiator_id = approver_id` ise karar engellenir (çıkar çatışması — denetim bulgusu olur).
4. **Aksiyon tamamlama:** Yalnız `assignee_id` veya koordinatör.
5. **Tenant izolasyonu:** RLS zaten DB seviyesinde uygular; service katmanı ikinci savunma hattıdır.

---

## 4. Seed Örneği (mevcut RBAC yapınıza uyarlayın)

```sql
-- Varsayım: permissions(code) ve role_permissions(role_id, permission_code)
-- tablolarınız var. Yoksa kendi yapınıza çevirin.

INSERT INTO permissions (code, module) VALUES
  ('moc.view','moc'), ('moc.create','moc'), ('moc.screen','moc'),
  ('moc.coordinate','moc'), ('moc.risk','moc'), ('moc.review','moc'),
  ('moc.approve','moc'), ('moc.pssr','moc'), ('moc.close','moc'),
  ('moc.temp.manage','moc'), ('moc.reopen','moc'), ('moc.admin','moc'),
  ('moc.report','moc'), ('moc.audit.view','moc')
ON CONFLICT (code) DO NOTHING;
```

```js
// Middleware kullanımı (mevcut auth altyapınızla):
router.post('/requests', requirePermission('moc.create'), mocController.create);
router.post('/requests/:id/transition', requireAuth, mocService.transitionGuard, ...);
// transitionGuard: hedef duruma göre matristen gerekli izni okur (moc.transitions.js)
```

---

## 5. UI Görünürlük Notları

- Menüde **MOC** başlığı `moc.view` olan herkese görünür (taban izin → herkes).
- "Bana bekleyen onaylar" ve "Aksiyonlarım" kutuları izinden bağımsız, atamaya göre dolar.
- `moc.admin` olmayanlar konfigürasyon ekranını hiç görmez (buton gizlenir + API 403).
- Geçici değişiklik uyarı bandı (süre dolumu) koordinatör ve HSE dashboard'unda kalıcı gösterilir.

---

## 6. Gerçek Uygulanan Model (Faz B/B2, canlı — kod esas alınır)

§1–§5'teki 14 izinli/8 rollü tasarım yerine **3 kademeli rol** kullanılıyor
(`profiles.role`: `ADMIN` / `EDITOR` / `VIEWER`). `MOC.html` `canDo(action)`:

| `action` | ADMIN | EDITOR | VIEWER |
|---|:---:|:---:|:---:|
| `create` | ✅ | ✅ | ✅ (taban izin — herkes talep başlatabilir) |
| `screen`, `coordinate`, `risk`, `review`, `pssr`, `close` | ✅ | ✅ | — |
| `admin`, `reopen` | ✅ | — | — |

- Tek bir aksiyon seti var; §1'deki `moc.approve`, `moc.temp.manage`,
  `moc.report`, `moc.audit.view` gibi ayrı izin kodları yok — bu
  yetenekler ya EDITOR/ADMIN'in genel yetkisine dahil ya da (rapor/audit
  gibi) henüz UI'da ayrı bir ekran olarak yok.
- **Onaycı ataması yok (bilinçli tercih).** §1'deki `moc.approve` +
  "kimin hangi adımda karar verebileceği ataması" modeli **uygulanmadı**.
  Bunun yerine: `moc_approvals.approver_id` boş oluşturulur, EDITOR/ADMIN
  yetkisine sahip herhangi bir kullanıcı (talep sahibi hariç) o anki
  kararı "üstlenerek" verir — karar anında `approver_id` kendisine set
  edilir. B2 planlamasında bu model yeniden sorgulandı, korunması
  seçildi (bkz. `MOC.html` proje `CLAUDE.md` §"Bilinen sınırlamalar").
- §3'teki kayıt-bazlı kurallar (sahiplik, kendi talebini onaylayamama,
  aksiyon tamamlama) **tam uygulanıyor** — bunlar rol modelinden bağımsız
  ve kod bu kısıtları koruyor.
- §4 seed örneği ve §5 UI notları (menü görünürlüğü, admin ekranı
  gizleme) kavramsal olarak geçerli, yalnız izin kodu sayısı `canDo()`
  aksiyon listesine indirgendi.

---

*Sürüm: v1 — 21.07.2026 · §6 eklendi: 03.08.2026 (Faz B2 sonrası kod↔plan taraması).*
