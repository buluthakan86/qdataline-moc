# MOC Modülü — RBAC İzin Matrisi v1

> Referanslar: `moc_api_endpoints_v1.md`, `moc_state_machine_v1.md`
> Mevcut Ekipman Yönetimi projesinin rol altyapısına **MOC izin seti** olarak eklenir.
> Yeni rol tablosu açılmaz; mevcut role-permission yapınıza aşağıdaki izin kodları tanımlanır.

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

*Sürüm: v1 — 21.07.2026 · Sıradaki aşama: UI wireframe (tema tokenlarıyla talep formu + dashboard).*
