> **ARŞİV — KULLANILMADI.** Bu dosya Node.js/Express/React/TS mimarisi
> varsayımıyla yazıldı; gerçek uygulama tek dosya HTML (`MOC.html`,
> Supabase doğrudan istemci erişimi) olarak farklı bir mimariyle
> geliştirildi (bkz. proje `CLAUDE.md`). İçindeki dosya referansları
> (`moc_schema_v1.sql`, `moc_api_endpoints_v1.md` vb.) kasıtlı olarak
> sürüm eki almadan bırakıldı — güncel karşılıkları `moc_schema_v1-1.sql`,
> `moc_api_endpoints_v1-1.md`'dir. Yalnız kapsam/vizyon referansı olarak
> tutuluyor, güncellenmeyecek.

# MOC Modülü — Kodlama Başlangıç Promptu (Sprint 1)

> Kullanım: Bu promptu Claude'a (Claude Code veya sohbet) yapıştır.
> Öncesinde 7 hazırlık dosyasını proje köküne `docs/moc/` klasörüne koy:
> `MOC_Teknik_Taslak_v2.md`, `moc_schema_v1.sql`, `moc_state_machine_v1.md`,
> `moc_api_endpoints_v1.md`, `moc_rbac_matrix_v1.md`, `moc_theme_tokens.css`,
> `moc_wireframe_v1.html`

---

## PROMPT (kopyala-yapıştır)

```
Mevcut Ekipman Yönetimi projeme (Node.js + Express + PostgreSQL + React/TS)
MOC (Management of Change) modülü ekliyorum. Tüm tasarım kararları
docs/moc/ klasöründeki 7 dosyada tanımlı — önce hepsini oku, bu dosyalar
tek doğruluk kaynağıdır, onlarla çelişen hiçbir şey yazma.

SPRINT 1 KAPSAMI (sadece bunları yap):

1. VERİTABANI
   - docs/moc/moc_schema_v1.sql dosyasını mevcut migration sistemime uygun
     migration dosyasına çevir. Önce mevcut tenant/users tablolarımın PK
     tipini kontrol et; şemadaki BIGINT varsayımı uymuyorsa uyarlayıp bildir.
   - ÖNEMLİ: Q-MOC bağımsız satılabilir modüldür. equipment tablosuna FK
     şemadaki gibi KOŞULLU kalacak (DO bloğu); tenant_modules bayrağı ve
     asset_ref yumuşak referansı aynen uygulanacak. Ekipman modülü olmadan
     migration çalışabilmeli.
   - Migration'ı çalıştırmadan önce bana özet göster, onayımı al.

2. BACKEND İSKELETİ (src/modules/moc/)
   - moc_api_endpoints_v1.md dosyasının sonundaki klasör yapısını kur:
     controller → service → repository katmanları. İş mantığı SADECE
     service katmanında olacak (dış API sonradan eklenecek, kapı açık kalsın).
   - moc_state_machine_v1.md içindeki geçiş matrisini moc.transitions.js
     config dosyası olarak yaz ve service'te tek bir transition() fonksiyonu
     ile uygula: matris kontrolü → RBAC izni → koşul kontrolü → güncelle.
   - Sadece şu endpoint gruplarını yaz: Lookup (kategori/tür), Talep CRUD,
     durum geçişi (transition), ekipman bağlama. Diğer gruplar sonraki sprint.

3. RBAC
   - moc_rbac_matrix_v1.md izin kodlarını mevcut permission yapıma ekle
     (yapımı önce incele, kendi tablolarıma uyarla).
   - requirePermission middleware'ini transition matrisiyle bağla.
   - Kural: initiator kendi talebini onaylayamaz — service'te zorunlu kontrol.

4. TEST
   - Talep oluşturma → SCREENING geçişi → RIK kapama akışının
     entegrasyon testini yaz (Jest + Supertest). Geçici türde planned_end
     eksikse 422 döndüğünü test et.

ÇALIŞMA KURALLARI:
- Her adımda ne yaptığını kısaca açıkla, büyük kararlarda önce sor.
- Mevcut projemin kod stilini (lint kuralları, dosya adlandırma) takip et.
- Frontend'e bu sprint'te DOKUNMA — sadece backend + DB.
- Bitince değişen dosyaların listesini ve sıradaki sprint önerini ver.
```

---

## Sonraki Sprint Promptları (sıra)

| Sprint | Kapsam | Referans dosya |
|---|---|---|
| 2 | Risk + Onay zinciri endpoint'leri, evidence_hash üretimi | api §4-5, state machine |
| 3 | Geçici değişiklik Bull job'ları (T-7/T-1, eskalasyon), bildirimler | api §7, §10 |
| 4 | React: MOC menüsü + panel + talep formu (wireframe'e göre) | wireframe, theme tokens |
| 5 | PSSR + doküman (MinIO) + dashboard KPI | api §8-9, taslak §12 |

---

*21.07.2026 · Gantt'taki Phase 1 planına karşılık gelir; sprint biterken tabloyu güncelle.*
