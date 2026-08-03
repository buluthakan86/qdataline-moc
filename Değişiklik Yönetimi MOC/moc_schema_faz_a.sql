-- ============================================================================
-- MOC (Değişiklik Yönetimi) — Faz A: Tablolar + RLS + Seed
-- Hedef proje: Ekipman Yönetimi Supabase projesi (bbltvuxxtacrpgrqnfoh)
-- Desen: Ekipman/Gıda/Q-Tedarikçi ile aynı — tek dosya HTML + Supabase JS
--        client + RLS. Node/Express katmanı YOK.
--
-- Kaynaklar: moc_schema_v1-1.sql (iş mantığı), moc_state_machine_v1.md,
--            moc_rbac_matrix_v1.md — current_setting('app.tenant_id')
--            deseni ATILDI, yerine public.current_tenant_id() kullanıldı.
--
-- Çalıştırma güvenliği:
--   * Idempotent: CREATE TABLE IF NOT EXISTS, CREATE OR REPLACE FUNCTION,
--     DROP POLICY/TRIGGER IF EXISTS + yeniden CREATE.
--   * DROP TABLE / DROP SCHEMA YOK. Bu script hiçbir mevcut nesneyi silmez.
--   * Yeni RPC/fonksiyon YOK bu fazda (moc_set_updated_at ve
--     moc_audit_trigger yalnız trigger fonksiyonu — istemciden çağrılmaz,
--     bu yüzden GRANT EXECUTE / Exposed Functions gerektirmez). Faz B'de
--     transition() gibi bir RPC eklenirse 3 katmanlı izin kontrolü
--     (GRANT EXECUTE → schema USAGE → Dashboard Exposed Functions) o
--     fazda ayrıca yapılacak.
--   * Sona eklenen GERİ ALMA bölümü YORUM SATIRI olarak durur, otomatik
--     çalışmaz — gerekirse elle çalıştırılır.
--
-- VARSAYIMLAR (mevcut projeden doğrulanmış):
--   * public.current_tenant_id() zaten var: profiles(id=auth.uid()).tenant_id
--     döner, SECURITY DEFINER. MOC bunu doğrudan kullanır, yeniden yazmaz.
--   * auth.users(id) tüm kullanıcı referansları için kaynak (initiator,
--     approver, assignee vb.) — ayrı bir users tablosu varsayılmadı.
--   * tenant PK tipi: UUID (current_tenant_id() UUID döndürdüğü için).
--   * "tenants" ana tenant tablosunun gerçek adı ortamda değişebilir;
--     bu yüzden tenant_id'ye FK, o tablo mevcutsa koşullu eklenir (aşağıda
--     equipment ile aynı DO bloğu deseni).
--   * equipment tablosu OPSİYONEL — Q-MOC bağımsız modül, equipment_id
--     koşullu FK ile bağlanır; yoksa asset_ref serbest metin kullanılır.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 0. Ortak fonksiyonlar (idempotent — CREATE OR REPLACE zaten güvenli)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.moc_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Audit trigger: değiştiren kullanıcı auth.uid()'den doğrudan alınır
-- (current_setting('app.user_id') Express deseniydi, Supabase'de gerek yok).
CREATE OR REPLACE FUNCTION public.moc_audit_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  INSERT INTO public.moc_audit_log (tenant_id, table_name, record_id, action, changed_by, old_data, new_data)
  VALUES (
    COALESCE(NEW.tenant_id, OLD.tenant_id),
    TG_TABLE_NAME,
    COALESCE(NEW.id, OLD.id),
    TG_OP,
    auth.uid(),
    CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) END,
    CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) END
  );
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- ----------------------------------------------------------------------------
-- 0b. Modül lisans bayrağı — Ekipman/Gıda/Q-Tedarikçi projesinde eşdeğeri
--     zaten varsa bu tablo ATLANABİLİR; şimdilik MOC'a özel, çakışmaz
--     (tenant_modules adı proje genelinde ortaksa bu bloğu kaldır).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tenant_modules (
  tenant_id    UUID NOT NULL,
  module_code  TEXT NOT NULL,   -- 'EQUIPMENT','MOC','CHEMICAL','CONSUMABLE'...
  enabled      BOOLEAN NOT NULL DEFAULT true,
  PRIMARY KEY (tenant_id, module_code)
);

-- ----------------------------------------------------------------------------
-- 1. Lookup: Değişiklik kategorileri (8 kategori)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.moc_change_categories (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     UUID,                          -- NULL = tüm tenantlar için global varsayılan
  code          TEXT NOT NULL,
  name_tr       TEXT NOT NULL,
  name_en       TEXT NOT NULL,
  requires_equipment_link BOOLEAN NOT NULL DEFAULT false,
  is_active     BOOLEAN NOT NULL DEFAULT true,
  sort_order    INT NOT NULL DEFAULT 0,
  UNIQUE (tenant_id, code)
);

-- ----------------------------------------------------------------------------
-- 2. Lookup: Akış türleri (6 akış)
--    extra_approval_risk_threshold / extra_approval_role_code: basit eşik
--    deseni (Faz F / Q-Tedarikçi satın alma kısıtı gibi) — risk_after bu
--    eşiği geçerse belirtilen role_code'a ek onay adımı eklenir. Servis
--    katmanında uygulanır, burada sadece konfig kolonu.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.moc_types (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     UUID,
  code          TEXT NOT NULL,                -- PERMANENT, TEMPORARY, ...
  name_tr       TEXT NOT NULL,
  name_en       TEXT NOT NULL,
  requires_pssr        BOOLEAN NOT NULL DEFAULT true,
  requires_end_date    BOOLEAN NOT NULL DEFAULT false,  -- geçici değişiklik
  retro_hours          INT,                              -- acil: geriye dönük dosya süresi (saat)
  extra_approval_risk_threshold INT,                      -- örn. 15 (risk_after >= 15)
  extra_approval_role_code      TEXT,                     -- örn. 'PLANT_MANAGER'
  workflow_config      JSONB NOT NULL DEFAULT '{}'::jsonb, -- adımlar, koşullu dallanma
  is_active     BOOLEAN NOT NULL DEFAULT true,
  UNIQUE (tenant_id, code)
);

-- ----------------------------------------------------------------------------
-- 3. Ana tablo: MOC talepleri
--    location_id: ŞİMDİLİK KULLANILMIYOR (UI'da seçim/filtre yok). Çok
--    lokasyon/çatı-alt firma deseni ileride Gıda'daki gibi eklenirse
--    (ör. moc_gorulebilir_tenantlar() + hiyerarşi tablosu) bu kolon
--    üzerine kurulur. Şimdiden nullable olarak duruyor.
--    previous_moc_id: başarısız kalıcı değişiklik geri alınırken yeni
--    açılan MOC'un önceki MOC'a izlenebilirlik referansı (opsiyonel).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.moc_requests (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     UUID NOT NULL,
  moc_no        TEXT NOT NULL,                -- MOC-2026-0001 (uygulama üretir)
  title         TEXT NOT NULL,
  description   TEXT,
  category_id   BIGINT NOT NULL REFERENCES public.moc_change_categories(id),
  type_id       BIGINT NOT NULL REFERENCES public.moc_types(id),
  status        TEXT NOT NULL DEFAULT 'DRAFT'
                CHECK (status IN ('DRAFT','SCREENING','RISK_ASSESSMENT','TECHNICAL_REVIEW',
                                  'APPROVAL','IMPLEMENTATION','DOC_UPDATE','TRAINING',
                                  'PSSR','STARTUP','CLOSED','REJECTED','CANCELLED')),
  priority      TEXT NOT NULL DEFAULT 'NORMAL'
                CHECK (priority IN ('LOW','NORMAL','HIGH','EMERGENCY')),
  initiator_id  UUID NOT NULL REFERENCES auth.users(id),
  coordinator_id UUID REFERENCES auth.users(id),
  unit_area     TEXT,                          -- etkilenen ünite/bölüm (serbest metin)
  location_id   UUID,                          -- rezerve — şimdilik kullanılmıyor
  reason        TEXT,
  is_rik        BOOLEAN NOT NULL DEFAULT false,
  previous_moc_id BIGINT REFERENCES public.moc_requests(id),
  planned_start DATE,
  planned_end   DATE,
  closed_at     TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, moc_no)
);

CREATE INDEX IF NOT EXISTS idx_moc_requests_tenant_status ON public.moc_requests (tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_moc_requests_category      ON public.moc_requests (category_id);
CREATE INDEX IF NOT EXISTS idx_moc_requests_type          ON public.moc_requests (type_id);
CREATE INDEX IF NOT EXISTS idx_moc_requests_previous       ON public.moc_requests (previous_moc_id);

-- ----------------------------------------------------------------------------
-- 4. MOC ↔ Varlık ilişkisi (bağımsız modül uyumlu)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.moc_equipment (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     UUID NOT NULL,
  moc_id        BIGINT NOT NULL REFERENCES public.moc_requests(id) ON DELETE CASCADE,
  equipment_id  UUID,                          -- ekipman modülü varsa dolu
  asset_ref     TEXT,                          -- standalone: "P-101" vb.
  note          TEXT,
  CHECK (equipment_id IS NOT NULL OR asset_ref IS NOT NULL),
  UNIQUE (moc_id, equipment_id)
);
CREATE INDEX IF NOT EXISTS idx_moc_equipment_equipment ON public.moc_equipment (equipment_id);

-- Koşullu FK: equipment tablosu bu projede mevcutsa bağla, yoksa atla.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public' AND table_name = 'equipment')
     AND NOT EXISTS (SELECT 1 FROM information_schema.table_constraints
             WHERE constraint_name = 'fk_moc_equipment_equipment') THEN
    ALTER TABLE public.moc_equipment
      ADD CONSTRAINT fk_moc_equipment_equipment
      FOREIGN KEY (equipment_id) REFERENCES public.equipment(id);
  END IF;
END $$;

-- Koşullu FK: tenant ana tablosu 'tenants' adıyla mevcutsa moc_requests.tenant_id'yi bağla.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public' AND table_name = 'tenants')
     AND NOT EXISTS (SELECT 1 FROM information_schema.table_constraints
             WHERE constraint_name = 'fk_moc_requests_tenant') THEN
    ALTER TABLE public.moc_requests
      ADD CONSTRAINT fk_moc_requests_tenant
      FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 5. Risk değerlendirme (5x5 matris + HAZOP/What-If kayıtları)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.moc_risk_assessments (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     UUID NOT NULL,
  moc_id        BIGINT NOT NULL REFERENCES public.moc_requests(id) ON DELETE CASCADE,
  method        TEXT NOT NULL DEFAULT 'MATRIX'
                CHECK (method IN ('MATRIX','HAZOP','WHAT_IF','FMEA','OTHER')),
  hazard        TEXT NOT NULL,
  consequence   TEXT,
  likelihood_before  INT CHECK (likelihood_before BETWEEN 1 AND 5),
  severity_before    INT CHECK (severity_before BETWEEN 1 AND 5),
  likelihood_after   INT CHECK (likelihood_after BETWEEN 1 AND 5),
  severity_after     INT CHECK (severity_after BETWEEN 1 AND 5),
  risk_before   INT GENERATED ALWAYS AS (likelihood_before * severity_before) STORED,
  risk_after    INT GENERATED ALWAYS AS (likelihood_after * severity_after) STORED,
  controls      TEXT,
  assessed_by   UUID REFERENCES auth.users(id),
  assessed_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_moc_risk_moc ON public.moc_risk_assessments (moc_id);

-- ----------------------------------------------------------------------------
-- 6. Onaylar (kademeli zincir + e-imza kanıtı)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.moc_approvals (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     UUID NOT NULL,
  moc_id        BIGINT NOT NULL REFERENCES public.moc_requests(id) ON DELETE CASCADE,
  step_order    INT NOT NULL,
  role_code     TEXT NOT NULL,                 -- HSE, ENGINEERING, PLANT_MANAGER...
  approver_id   UUID REFERENCES auth.users(id),
  delegate_of   UUID REFERENCES auth.users(id),
  decision      TEXT CHECK (decision IN ('APPROVED','REJECTED','RETURNED')),
  comment       TEXT,
  decided_at    TIMESTAMPTZ,
  evidence_hash TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (moc_id, step_order, role_code)
);
CREATE INDEX IF NOT EXISTS idx_moc_approvals_moc ON public.moc_approvals (moc_id);

-- ----------------------------------------------------------------------------
-- 7. Aksiyon / görevler (SLA takibi)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.moc_action_items (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     UUID NOT NULL,
  moc_id        BIGINT NOT NULL REFERENCES public.moc_requests(id) ON DELETE CASCADE,
  title         TEXT NOT NULL,
  description   TEXT,
  phase         TEXT NOT NULL DEFAULT 'IMPLEMENTATION'
                CHECK (phase IN ('PRE_APPROVAL','IMPLEMENTATION','DOC_UPDATE','TRAINING','PSSR','POST_STARTUP')),
  assignee_id   UUID REFERENCES auth.users(id),
  due_date      DATE,
  status        TEXT NOT NULL DEFAULT 'OPEN'
                CHECK (status IN ('OPEN','IN_PROGRESS','DONE','OVERDUE','CANCELLED')),
  completed_at  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_moc_actions_assignee ON public.moc_action_items (tenant_id, assignee_id, status);
CREATE INDEX IF NOT EXISTS idx_moc_actions_due      ON public.moc_action_items (tenant_id, due_date) WHERE status IN ('OPEN','IN_PROGRESS');

-- ----------------------------------------------------------------------------
-- 8. PSSR kontrol listeleri (şablon + doldurulmuş)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.moc_pssr_checklists (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     UUID NOT NULL,
  moc_id        BIGINT REFERENCES public.moc_requests(id) ON DELETE CASCADE, -- NULL = şablon
  is_template   BOOLEAN NOT NULL DEFAULT false,
  name          TEXT NOT NULL,
  items         JSONB NOT NULL DEFAULT '[]'::jsonb,
  result        TEXT CHECK (result IN ('RELEASED','CONDITIONAL','NOT_RELEASED')),
  performed_by  UUID REFERENCES auth.users(id),
  performed_at  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_moc_pssr_moc ON public.moc_pssr_checklists (moc_id);

-- ----------------------------------------------------------------------------
-- 9. Dokümanlar (ekler + etkilenen doküman listesi)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.moc_documents (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     UUID NOT NULL,
  moc_id        BIGINT NOT NULL REFERENCES public.moc_requests(id) ON DELETE CASCADE,
  doc_kind      TEXT NOT NULL DEFAULT 'ATTACHMENT'
                CHECK (doc_kind IN ('ATTACHMENT','AFFECTED_DOC')),
  title         TEXT NOT NULL,
  doc_ref       TEXT,
  old_version   TEXT,
  new_version   TEXT,
  storage_key   TEXT,                          -- Supabase Storage object key (ek ise)
  mime_type     TEXT,
  size_bytes    BIGINT,
  uploaded_by   UUID REFERENCES auth.users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_moc_documents_moc ON public.moc_documents (moc_id);

-- ----------------------------------------------------------------------------
-- 10. Eğitim / bilgilendirme kayıtları
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.moc_trainings (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     UUID NOT NULL,
  moc_id        BIGINT NOT NULL REFERENCES public.moc_requests(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id),
  training_type TEXT NOT NULL DEFAULT 'INFO'
                CHECK (training_type IN ('INFO','CLASSROOM','ON_JOB')),
  acknowledged  BOOLEAN NOT NULL DEFAULT false,
  acknowledged_at TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (moc_id, user_id)
);

-- ----------------------------------------------------------------------------
-- 11. Geçici değişiklik takibi
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.moc_temporary_tracking (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     UUID NOT NULL,
  moc_id        BIGINT NOT NULL UNIQUE REFERENCES public.moc_requests(id) ON DELETE CASCADE,
  expires_at    DATE NOT NULL,
  warned_t7     BOOLEAN NOT NULL DEFAULT false,
  warned_t1     BOOLEAN NOT NULL DEFAULT false,
  escalated     BOOLEAN NOT NULL DEFAULT false,
  extension_count INT NOT NULL DEFAULT 0,
  extension_history JSONB NOT NULL DEFAULT '[]'::jsonb,
  restored_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_moc_temp_expires ON public.moc_temporary_tracking (tenant_id, expires_at) WHERE restored_at IS NULL;

-- ----------------------------------------------------------------------------
-- 12. Bildirimler
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.moc_notifications (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     UUID NOT NULL,
  user_id       UUID NOT NULL REFERENCES auth.users(id),
  moc_id        BIGINT REFERENCES public.moc_requests(id) ON DELETE CASCADE,
  channel       TEXT NOT NULL DEFAULT 'IN_APP' CHECK (channel IN ('IN_APP','EMAIL')),
  subject       TEXT NOT NULL,
  body          TEXT,
  is_read       BOOLEAN NOT NULL DEFAULT false,
  sent_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_moc_notif_user ON public.moc_notifications (tenant_id, user_id, is_read);

-- ----------------------------------------------------------------------------
-- 13. Audit log (append-only)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.moc_audit_log (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     UUID,
  table_name    TEXT NOT NULL,
  record_id     BIGINT,
  action        TEXT NOT NULL,
  changed_by    UUID,
  old_data      JSONB,
  new_data      JSONB,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_moc_audit_record ON public.moc_audit_log (table_name, record_id);
-- Append-only garanti: UPDATE/DELETE'i normal rollerden almak isterseniz
-- (Supabase'de "authenticated" rolü) ayrıca REVOKE UPDATE, DELETE gerekir;
-- RLS zaten aşağıda UPDATE/DELETE politikası TANIMLAMAYARAK bunu sağlıyor.

-- ----------------------------------------------------------------------------
-- Trigger bağlama (idempotent: DROP IF EXISTS + CREATE)
-- ----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_moc_requests_updated ON public.moc_requests;
CREATE TRIGGER trg_moc_requests_updated  BEFORE UPDATE ON public.moc_requests
  FOR EACH ROW EXECUTE FUNCTION public.moc_set_updated_at();

DROP TRIGGER IF EXISTS trg_moc_actions_updated ON public.moc_action_items;
CREATE TRIGGER trg_moc_actions_updated   BEFORE UPDATE ON public.moc_action_items
  FOR EACH ROW EXECUTE FUNCTION public.moc_set_updated_at();

DROP TRIGGER IF EXISTS trg_moc_temp_updated ON public.moc_temporary_tracking;
CREATE TRIGGER trg_moc_temp_updated      BEFORE UPDATE ON public.moc_temporary_tracking
  FOR EACH ROW EXECUTE FUNCTION public.moc_set_updated_at();

DROP TRIGGER IF EXISTS trg_audit_moc_requests ON public.moc_requests;
CREATE TRIGGER trg_audit_moc_requests  AFTER INSERT OR UPDATE OR DELETE ON public.moc_requests
  FOR EACH ROW EXECUTE FUNCTION public.moc_audit_trigger();

DROP TRIGGER IF EXISTS trg_audit_moc_approvals ON public.moc_approvals;
CREATE TRIGGER trg_audit_moc_approvals AFTER INSERT OR UPDATE OR DELETE ON public.moc_approvals
  FOR EACH ROW EXECUTE FUNCTION public.moc_audit_trigger();

DROP TRIGGER IF EXISTS trg_audit_moc_risk ON public.moc_risk_assessments;
CREATE TRIGGER trg_audit_moc_risk      AFTER INSERT OR UPDATE OR DELETE ON public.moc_risk_assessments
  FOR EACH ROW EXECUTE FUNCTION public.moc_audit_trigger();

-- ----------------------------------------------------------------------------
-- Row-Level Security — public.current_tenant_id() zaten var, doğrudan kullanılır.
-- Çok-lokasyon/hiyerarşi YOK bu fazda (tek lokasyon kararı); location_id
-- kolonu ileride moc_gorulebilir_tenantlar() ile union'a genişletilebilir.
-- ----------------------------------------------------------------------------
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'moc_requests','moc_equipment','moc_risk_assessments','moc_approvals',
    'moc_action_items','moc_pssr_checklists','moc_documents','moc_trainings',
    'moc_temporary_tracking','moc_notifications'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation_%s ON public.%I', t, t);
    EXECUTE format(
      'CREATE POLICY tenant_isolation_%s ON public.%I
         FOR ALL
         USING (tenant_id = public.current_tenant_id())
         WITH CHECK (tenant_id = public.current_tenant_id())',
      t, t);
  END LOOP;
END $$;

-- Audit log: yalnız kendi tenant'ını görebilir, INSERT trigger üzerinden
-- (SECURITY DEFINER) yapılır — istemciden doğrudan INSERT/UPDATE/DELETE
-- politikası TANIMLANMIYOR (append-only + tenant izolasyonu).
ALTER TABLE public.moc_audit_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation_moc_audit_log ON public.moc_audit_log;
CREATE POLICY tenant_isolation_moc_audit_log ON public.moc_audit_log
  FOR SELECT
  USING (tenant_id = public.current_tenant_id());

-- tenant_modules: kendi tenant'ının satırını görür
ALTER TABLE public.tenant_modules ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation_tenant_modules ON public.tenant_modules;
CREATE POLICY tenant_isolation_tenant_modules ON public.tenant_modules
  FOR ALL
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

-- Lookup tabloları: kendi tenant'ı + global (NULL) kayıtlar görünür.
-- Yazma (admin konfig ekranı) Faz sonrasında ayrı policy ile açılacak;
-- şimdilik yalnız SELECT.
ALTER TABLE public.moc_change_categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_or_global_categories ON public.moc_change_categories;
CREATE POLICY tenant_or_global_categories ON public.moc_change_categories
  FOR SELECT
  USING (tenant_id IS NULL OR tenant_id = public.current_tenant_id());

ALTER TABLE public.moc_types ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_or_global_types ON public.moc_types;
CREATE POLICY tenant_or_global_types ON public.moc_types
  FOR SELECT
  USING (tenant_id IS NULL OR tenant_id = public.current_tenant_id());

-- ----------------------------------------------------------------------------
-- GRANT — authenticated rolüne tablo erişimi (RLS zaten satır filtreliyor).
-- anon rolü MOC'ta kullanılmıyor, GRANT verilmiyor.
-- ----------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON
  public.moc_requests, public.moc_equipment, public.moc_risk_assessments,
  public.moc_approvals, public.moc_action_items, public.moc_pssr_checklists,
  public.moc_documents, public.moc_trainings, public.moc_temporary_tracking,
  public.moc_notifications, public.tenant_modules
  TO authenticated;

GRANT SELECT ON public.moc_change_categories, public.moc_types, public.moc_audit_log TO authenticated;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ----------------------------------------------------------------------------
-- SEED: Global varsayılan kategoriler (8) ve akış türleri (6)
-- Idempotent: (tenant_id, code) UNIQUE olduğu için ON CONFLICT DO NOTHING.
-- ----------------------------------------------------------------------------
INSERT INTO public.moc_change_categories (tenant_id, code, name_tr, name_en, requires_equipment_link, sort_order) VALUES
  (NULL, 'EQUIPMENT',    'Ekipman',               'Equipment',                true,  1),
  (NULL, 'PROCESS',      'Proses',                'Process',                  false, 2),
  (NULL, 'CHEMICAL',     'Kimyasal / Hammadde',   'Chemical / Raw Material',  false, 3),
  (NULL, 'NEW_PRODUCT',  'Yeni Ürün Geliştirme',  'New Product Development',  false, 4),
  (NULL, 'PROJECT',      'Proje',                 'Project',                  false, 5),
  (NULL, 'PROCEDURE',    'Prosedür / Doküman',    'Procedure / Document',     false, 6),
  (NULL, 'ORGANIZATION', 'Organizasyonel',        'Organizational',           false, 7),
  (NULL, 'AUTOMATION',   'Yazılım / Otomasyon',   'Software / Automation',    false, 8)
ON CONFLICT (tenant_id, code) DO NOTHING;

INSERT INTO public.moc_types (tenant_id, code, name_tr, name_en, requires_pssr, requires_end_date, retro_hours) VALUES
  (NULL, 'PERMANENT',  'Kalıcı Değişiklik',      'Permanent Change',        true,  false, NULL),
  (NULL, 'TEMPORARY',  'Geçici Değişiklik',      'Temporary Change',        true,  true,  NULL),
  (NULL, 'EMERGENCY',  'Acil Değişiklik',        'Emergency Change',        true,  false, 72),
  (NULL, 'RIK',        'Birebir Yenileme',       'Replacement-in-Kind',     false, false, NULL),
  (NULL, 'MOOC',       'Organizasyonel Değişiklik', 'Management of Organizational Change', false, false, NULL),
  (NULL, 'PROCEDURAL', 'Prosedürel Değişiklik',  'Procedural Change',       false, false, NULL)
ON CONFLICT (tenant_id, code) DO NOTHING;

COMMIT;

-- ============================================================================
-- STATE MACHINE NOTU (uygulama katmanı, Faz B):
-- PSSR gerektirmeyen türlerde (requires_pssr=false: RIK, MOOC, PROCEDURAL)
-- geçiş matrisinde TRAINING → STARTUP direkt yolu da tanımlanmalı (PSSR
-- adımı atlanır). Bu şema fazında constraint gerekmiyor, transitions
-- config'inde (moc.transitions.js yerine moc-transitions.js/JSON, tek
-- dosya HTML içinde) ele alınacak.
-- ============================================================================

-- ============================================================================
-- GERİ ALMA (yalnız elle, gerekirse — bu script bunu ÇALIŞTIRMAZ)
-- ============================================================================
-- BEGIN;
-- DROP TABLE IF EXISTS public.moc_audit_log;
-- DROP TABLE IF EXISTS public.moc_notifications;
-- DROP TABLE IF EXISTS public.moc_temporary_tracking;
-- DROP TABLE IF EXISTS public.moc_trainings;
-- DROP TABLE IF EXISTS public.moc_documents;
-- DROP TABLE IF EXISTS public.moc_pssr_checklists;
-- DROP TABLE IF EXISTS public.moc_action_items;
-- DROP TABLE IF EXISTS public.moc_approvals;
-- DROP TABLE IF EXISTS public.moc_risk_assessments;
-- DROP TABLE IF EXISTS public.moc_equipment;
-- DROP TABLE IF EXISTS public.moc_requests;
-- DROP TABLE IF EXISTS public.moc_types;
-- DROP TABLE IF EXISTS public.moc_change_categories;
-- DROP TABLE IF EXISTS public.tenant_modules;
-- DROP FUNCTION IF EXISTS public.moc_audit_trigger();
-- DROP FUNCTION IF EXISTS public.moc_set_updated_at();
-- COMMIT;
-- ============================================================================
