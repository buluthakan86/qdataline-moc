# MOC Modülü — İç API Endpoint Listesi v1 (Phase 1 Kapsamı)

> Referanslar: `moc_schema_v1.sql`, `moc_state_machine_v1.md`
> Temel yol: `/api/moc/*` — mevcut Ekipman Yönetimi backend'ine route grubu olarak eklenir.
> Kimlik: Mevcut JWT middleware. Her istekte `SET app.tenant_id / app.user_id` (RLS için).
> Dış API ertelendi — katmanlı mimari sayesinde ileride `/api/v1/public/moc/*` olarak eklenebilir.

---

## Genel Kurallar

- **Yanıt zarfı:** `{ "data": ..., "meta": { "page", "limit", "total" } }` — hata: `{ "error": { "code", "message", "details" } }`
- **Sayfalama:** `?page=1&limit=20` (varsayılan 20, maks 100)
- **Sıralama/filtre:** `?sort=-created_at&status=APPROVAL&category=EQUIPMENT`
- **HTTP kodları:** 200 OK · 201 Created · 400 doğrulama · 403 izin yok · 404 yok · 409 geçersiz durum geçişi · 422 koşul eksik
- **Doğrulama:** zod şemaları `src/modules/moc/schemas/` altında

---

## 1. Lookup / Konfigürasyon

| Metot | Yol | Açıklama | İzin |
|---|---|---|---|
| GET | `/api/moc/categories` | 8 kategori (global + tenant) | oturum |
| GET | `/api/moc/types` | 6 akış türü + kuralları | oturum |
| PUT | `/api/moc/types/:id/workflow` | Akış konfigürasyonu güncelle | `moc.admin` |

## 2. Talep (Request) CRUD

| Metot | Yol | Açıklama | İzin |
|---|---|---|---|
| GET | `/api/moc/requests` | Liste (filtre: status, category, type, unit, tarih aralığı, q) | `moc.view` |
| POST | `/api/moc/requests` | Yeni talep (DRAFT) — geçici türde `planned_end` zorunlu | `moc.create` |
| GET | `/api/moc/requests/:id` | Detay (ilişkili ekipman, risk, onay özeti dahil) | `moc.view` |
| PUT | `/api/moc/requests/:id` | Güncelle (yalnız DRAFT/SCREENING'de) | sahibi veya `moc.coordinate` |
| DELETE | `/api/moc/requests/:id` | Sil (yalnız DRAFT) | sahibi |
| POST | `/api/moc/requests/:id/transition` | Durum geçişi `{ "target": "SCREENING" }` — matris + koşul kontrolü | matrise göre |
| GET | `/api/moc/requests/:id/timeline` | Durum geçmişi (audit log'dan) | `moc.view` |

## 3. Varlık / Ekipman Bağlantısı (modül lisansına duyarlı)

| Metot | Yol | Açıklama | İzin |
|---|---|---|---|
| GET | `/api/tenant/modules` | Tenant'ın açık modülleri (UI ekipman seçiciyi buna göre gösterir/gizler) | oturum |
| POST | `/api/moc/requests/:id/equipment` | Varlık bağla: `{ "equipment_id": 42 }` **veya** `{ "asset_ref": "P-101" }` (standalone) | sahibi, koordinatör |
| DELETE | `/api/moc/requests/:id/equipment/:linkId` | Bağlantıyı kaldır | koordinatör |
| GET | `/api/equipment/:id/moc` | Ekipman kartındaki MOC sekmesi — **yalnız EQUIPMENT modülü lisanslıysa aktif** | `moc.view` |

> Servis kuralı: EQUIPMENT modülü kapalıysa `equipment_id` gönderimi 422 döner ("asset_ref kullanın").

## 4. Risk Değerlendirme

| Metot | Yol | Açıklama | İzin |
|---|---|---|---|
| GET | `/api/moc/requests/:id/risks` | Risk kayıtları | `moc.view` |
| POST | `/api/moc/requests/:id/risks` | Risk ekle (5×5 önce/sonra skorlar) | `moc.risk` |
| PUT | `/api/moc/risks/:riskId` | Güncelle | `moc.risk` |
| DELETE | `/api/moc/risks/:riskId` | Sil (RISK_ASSESSMENT aşamasında) | `moc.risk` |

## 5. Onay Zinciri

| Metot | Yol | Açıklama | İzin |
|---|---|---|---|
| GET | `/api/moc/requests/:id/approvals` | Zincir ve durumları | `moc.view` |
| POST | `/api/moc/approvals/:approvalId/decide` | `{ "decision": "APPROVED\|REJECTED\|RETURNED", "comment" }` — evidence_hash sunucuda üretilir; tüm adımlar bitince otomatik geçiş | atanmış onaycı |
| POST | `/api/moc/approvals/:approvalId/delegate` | Vekâlet ata `{ "delegate_id": 7 }` | atanmış onaycı |
| GET | `/api/moc/my/pending-approvals` | **Bana bekleyen onaylar** (dashboard kutusu) | oturum |

## 6. Aksiyonlar & SLA

| Metot | Yol | Açıklama | İzin |
|---|---|---|---|
| GET | `/api/moc/requests/:id/actions` | Aksiyon listesi (faz filtresi) | `moc.view` |
| POST | `/api/moc/requests/:id/actions` | Aksiyon ekle | koordinatör |
| PUT | `/api/moc/actions/:actionId` | Güncelle / tamamla | atanan kişi, koordinatör |
| GET | `/api/moc/my/actions` | **Bana atanan açık aksiyonlar** | oturum |

## 7. Geçici Değişiklik Takibi

| Metot | Yol | Açıklama | İzin |
|---|---|---|---|
| GET | `/api/moc/temporary` | Açık geçici değişiklikler (kalan gün, uyarı durumu) | `moc.view` |
| POST | `/api/moc/temporary/:mocId/extend` | Uzatma talebi `{ "new_date", "reason" }` → mini onay | koordinatör |
| POST | `/api/moc/temporary/:mocId/restore` | Eski duruma dönüş kaydı | koordinatör |

## 8. Dokümanlar

| Metot | Yol | Açıklama | İzin |
|---|---|---|---|
| POST | `/api/moc/requests/:id/documents` | Ek yükle (multipart → MinIO) veya etkilenen doküman kaydı | sahibi, koordinatör |
| GET | `/api/moc/documents/:docId/download` | İmzalı URL ile indirme | `moc.view` |
| DELETE | `/api/moc/documents/:docId` | Sil (kapanmamış MOC'ta) | yükleyen, koordinatör |

## 9. PSSR

| Metot | Yol | Açıklama | İzin |
|---|---|---|---|
| GET | `/api/moc/pssr/templates` | Şablon listesi | `moc.pssr` |
| POST | `/api/moc/requests/:id/pssr` | Şablondan checklist oluştur | `moc.pssr` |
| PUT | `/api/moc/pssr/:checklistId` | Maddeleri doldur / sonucu kaydet (RELEASED vb.) | `moc.pssr` |

## 10. Bildirim & Dashboard

| Metot | Yol | Açıklama | İzin |
|---|---|---|---|
| GET | `/api/moc/notifications` | Bildirimlerim (`?unread=true`) | oturum |
| PUT | `/api/moc/notifications/:id/read` | Okundu işaretle | oturum |
| GET | `/api/moc/dashboard/kpi` | KPI özet: açık MOC, ort. kapanış, süresi geçen geçici, geciken aksiyon | `moc.view` |
| GET | `/api/moc/dashboard/charts` | ECharts veri setleri (tür/ünite dağılımı, trend) | `moc.view` |

---

## Phase 1 Dışında (sonraya)

- `POST /api/moc/requests/:id/export-pdf` (jsPDF MOC dosyası) — Phase 3
- Eğitim modülü uçları (`/api/moc/requests/:id/trainings`) — Phase 2
- Dış API (`/api/v1/public/moc/*`, API key) — karar sonrası

---

## Önerilen Klasör Yapısı

```
src/modules/moc/
├── moc.routes.js          # route tanımları (bu dosyadaki liste)
├── controllers/           # sadece req/res — iş mantığı YOK
├── services/              # tüm iş mantığı (transition, approval, sla...)
├── repositories/          # SQL / ORM erişimi
├── schemas/               # zod doğrulama şemaları
├── moc.transitions.js     # durum geçiş matrisi (state machine dosyasından)
└── jobs/                  # Bull: temp-expiry.job.js, sla-check.job.js
```

*Sürüm: v1 — 21.07.2026 · Sıradaki aşama: RBAC izin matrisi veya UI wireframe (tema tokenlarıyla).*
