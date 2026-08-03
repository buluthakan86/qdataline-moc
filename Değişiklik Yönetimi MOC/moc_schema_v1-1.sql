-- ============================================================================
-- MOC (Management of Change) Modülü — PostgreSQL Şeması v1
-- Taslak referansı: MOC_Teknik_Taslak_v2.1
-- Tarih: 21.07.2026
--
-- NOT (03.08.2026, Faz B2 sonrası): Bu dosya orijinal tasarım taslağıdır,
-- doğrudan Supabase'e uygulanmadı. Gerçekte uygulanan/canlı sıra:
-- moc_schema_faz_a.sql -> moc_schema_faz_b_moc_no.sql -> moc_schema_faz_b2.sql.
-- Bilinen farklar: (1) tenant_id burada BIGINT varsayımıyla, gerçek şemada
-- current_tenant_id()/profiles tabanlı; (2) moc_types burada
-- extra_approval_risk_threshold/extra_approval_role_code kolonlarını
-- İÇERMİYOR — bunlar moc_schema_faz_b2.sql ile eklendi; (3) lookup RLS
-- burada SELECT-only, faz_b2 INSERT/UPDATE politikaları + GRANT ekledi
-- (Ayarlar CRUD için). Değişiklik gerektiğinde canlı şema (faz_* dosyaları)
-- esas alınır, bu dosya yalnız orijinal tasarım referansıdır.
--
-- VARSAYIMLAR (mevcut projenize göre uyarlayın):
--   * Platform çekirdeği: tenant(id BIGINT PK), users(id BIGINT PK).
--     PK tipiniz UUID ise BIGINT referanslarını UUID yapın.
--   * equipment tablosu OPSİYONELDİR — Q-MOC bağımsız modüldür ve tek
--     başına satılabilir. Ekipman modülü lisanslı tenantlarda FK koşullu
--     olarak eklenir (aşağıda), standalone kurulumda asset_ref kullanılır.
--   * Multi-tenant izolasyon: RLS + current_setting('app.tenant_id')
--     (backend her istekte SET app.tenant_id = '<id>' çalıştırmalı)
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 0. Ortak fonksiyonlar
-- ----------------------------------------------------------------------------

-- updated_at otomatik güncelleme
CREATE OR REPLACE FUNCTION moc_set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Genel audit trigger (append-only moc_audit_log'a yazar)
CREATE OR REPLACE FUNCTION moc_audit_trigger() RETURNS trigger AS $$
BEGIN
  INSERT INTO moc_audit_log (tenant_id, table_name, record_id, action, changed_by, old_data, new_data)
  VALUES (
    COALESCE(NEW.tenant_id, OLD.tenant_id),
    TG_TABLE_NAME,
    COALESCE(NEW.id, OLD.id),
    TG_OP,
    NULLIF(current_setting('app.user_id', true), '')::BIGINT,
    CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) END,
    CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) END
  );
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 0b. Modül lisans bayrağı (tenant hangi modülleri kullanıyor)
--     Platformunuzda benzer bir yapı zaten varsa bu tabloyu ATLAYIN,
--     mevcut yapınızı kullanın.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tenant_modules (
  tenant_id    BIGINT NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  module_code  TEXT NOT NULL,   -- 'EQUIPMENT','MOC','CHEMICAL','CONSUMABLE'...
  enabled      BOOLEAN NOT NULL DEFAULT true,
  PRIMARY KEY (tenant_id, module_code)
);
-- Backend kuralı: EQUIPMENT modülü kapalı tenantta MOC ekran/uçlarında
-- ekipman seçici gizlenir, asset_ref (serbest metin) kullanılır.

-- ----------------------------------------------------------------------------
-- 1. Lookup: Değişiklik kategorileri (8 kategori)
--    tenant_id NULL = tüm tenantlar için global varsayılan
-- ----------------------------------------------------------------------------
CREATE TABLE moc_change_categories (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     BIGINT REFERENCES tenant(id) ON DELETE CASCADE,
  code          TEXT NOT NULL,                -- EQUIPMENT, PROCESS, ...
  name_tr       TEXT NOT NULL,
  name_en       TEXT NOT NULL,
  requires_equipment_link BOOLEAN NOT NULL DEFAULT false,
  is_active     BOOLEAN NOT NULL DEFAULT true,
  sort_order    INT NOT NULL DEFAULT 0,
  UNIQUE (tenant_id, code)
);

-- ----------------------------------------------------------------------------
-- 2. Lookup: Akış türleri (6 akış)
-- ----------------------------------------------------------------------------
CREATE TABLE moc_types (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     BIGINT REFERENCES tenant(id) ON DELETE CASCADE,
  code          TEXT NOT NULL,                -- PERMANENT, TEMPORARY, ...
  name_tr       TEXT NOT NULL,
  name_en       TEXT NOT NULL,
  requires_pssr        BOOLEAN NOT NULL DEFAULT true,
  requires_end_date    BOOLEAN NOT NULL DEFAULT false,  -- geçici değişiklik
  retro_hours          INT,                              -- acil: geriye dönük dosya süresi (saat)
  workflow_config      JSONB NOT NULL DEFAULT '{}'::jsonb, -- adımlar, koşullu dallanma
  is_active     BOOLEAN NOT NULL DEFAULT true,
  UNIQUE (tenant_id, code)
);

-- ----------------------------------------------------------------------------
-- 3. Ana tablo: MOC talepleri
-- ----------------------------------------------------------------------------
CREATE TABLE moc_requests (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     BIGINT NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  moc_no        TEXT NOT NULL,                -- MOC-2026-0001 (uygulama üretir)
  title         TEXT NOT NULL,
  description   TEXT,
  category_id   BIGINT NOT NULL REFERENCES moc_change_categories(id),
  type_id       BIGINT NOT NULL REFERENCES moc_types(id),
  status        TEXT NOT NULL DEFAULT 'DRAFT'
                CHECK (status IN ('DRAFT','SCREENING','RISK_ASSESSMENT','TECHNICAL_REVIEW',
                                  'APPROVAL','IMPLEMENTATION','DOC_UPDATE','TRAINING',
                                  'PSSR','STARTUP','CLOSED','REJECTED','CANCELLED')),
  priority      TEXT NOT NULL DEFAULT 'NORMAL'
                CHECK (priority IN ('LOW','NORMAL','HIGH','EMERGENCY')),
  initiator_id  BIGINT NOT NULL REFERENCES users(id),
  coordinator_id BIGINT REFERENCES users(id),
  unit_area     TEXT,                          -- etkilenen ünite/bölüm
  reason        TEXT,                          -- değişiklik gerekçesi
  is_rik        BOOLEAN NOT NULL DEFAULT false, -- birebir yenileme muafiyeti
  planned_start DATE,
  planned_end   DATE,                          -- geçici değişiklikte zorunlu (app katmanı doğrular)
  closed_at     TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, moc_no)
);

CREATE INDEX idx_moc_requests_tenant_status ON moc_requests (tenant_id, status);
CREATE INDEX idx_moc_requests_category      ON moc_requests (category_id);
CREATE INDEX idx_moc_requests_type          ON moc_requests (type_id);

-- ----------------------------------------------------------------------------
-- 4. MOC ↔ Varlık ilişkisi (bağımsız modül uyumlu)
--    Ekipman modülü lisanslıysa equipment_id kullanılır (FK koşullu eklenir);
--    standalone kurulumda asset_ref (serbest metin tag/varlık no) yeterlidir.
-- ----------------------------------------------------------------------------
CREATE TABLE moc_equipment (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     BIGINT NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  moc_id        BIGINT NOT NULL REFERENCES moc_requests(id) ON DELETE CASCADE,
  equipment_id  BIGINT,                        -- ekipman modülü varsa dolu
  asset_ref     TEXT,                          -- standalone: "P-101", "Hat-3 valfi" vb.
  note          TEXT,
  CHECK (equipment_id IS NOT NULL OR asset_ref IS NOT NULL),
  UNIQUE (moc_id, equipment_id)
);
CREATE INDEX idx_moc_equipment_equipment ON moc_equipment (equipment_id);

-- Koşullu FK: equipment tablosu bu kurulumda mevcutsa bağla, yoksa atla.
-- Böylece Q-MOC ekipman modülü olmadan da migrate edilir.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = current_schema() AND table_name = 'equipment') THEN
    ALTER TABLE moc_equipment
      ADD CONSTRAINT fk_moc_equipment_equipment
      FOREIGN KEY (equipment_id) REFERENCES equipment(id);
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 5. Risk değerlendirme (5x5 matris + HAZOP/What-If kayıtları)
-- ----------------------------------------------------------------------------
CREATE TABLE moc_risk_assessments (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     BIGINT NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  moc_id        BIGINT NOT NULL REFERENCES moc_requests(id) ON DELETE CASCADE,
  method        TEXT NOT NULL DEFAULT 'MATRIX'
                CHECK (method IN ('MATRIX','HAZOP','WHAT_IF','FMEA','OTHER')),
  hazard        TEXT NOT NULL,                 -- tehlike tanımı
  consequence   TEXT,
  likelihood_before  INT CHECK (likelihood_before BETWEEN 1 AND 5),
  severity_before    INT CHECK (severity_before BETWEEN 1 AND 5),
  likelihood_after   INT CHECK (likelihood_after BETWEEN 1 AND 5),
  severity_after     INT CHECK (severity_after BETWEEN 1 AND 5),
  risk_before   INT GENERATED ALWAYS AS (likelihood_before * severity_before) STORED,
  risk_after    INT GENERATED ALWAYS AS (likelihood_after * severity_after) STORED,
  controls      TEXT,                          -- alınacak önlemler
  assessed_by   BIGINT REFERENCES users(id),
  assessed_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_moc_risk_moc ON moc_risk_assessments (moc_id);

-- ----------------------------------------------------------------------------
-- 6. Onaylar (kademeli zincir + e-imza kanıtı)
-- ----------------------------------------------------------------------------
CREATE TABLE moc_approvals (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     BIGINT NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  moc_id        BIGINT NOT NULL REFERENCES moc_requests(id) ON DELETE CASCADE,
  step_order    INT NOT NULL,                  -- 1,2,3... onay sırası
  role_code     TEXT NOT NULL,                 -- HSE, ENGINEERING, PLANT_MANAGER...
  approver_id   BIGINT REFERENCES users(id),
  delegate_of   BIGINT REFERENCES users(id),   -- vekâleten onay ise asıl kişi
  decision      TEXT CHECK (decision IN ('APPROVED','REJECTED','RETURNED')),
  comment       TEXT,
  decided_at    TIMESTAMPTZ,
  evidence_hash TEXT,                          -- kayıt hash'i (e-imza kanıtı)
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (moc_id, step_order, role_code)
);
CREATE INDEX idx_moc_approvals_moc ON moc_approvals (moc_id);

-- ----------------------------------------------------------------------------
-- 7. Aksiyon / görevler (SLA takibi)
-- ----------------------------------------------------------------------------
CREATE TABLE moc_action_items (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     BIGINT NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  moc_id        BIGINT NOT NULL REFERENCES moc_requests(id) ON DELETE CASCADE,
  title         TEXT NOT NULL,
  description   TEXT,
  phase         TEXT NOT NULL DEFAULT 'IMPLEMENTATION'
                CHECK (phase IN ('PRE_APPROVAL','IMPLEMENTATION','DOC_UPDATE','TRAINING','PSSR','POST_STARTUP')),
  assignee_id   BIGINT REFERENCES users(id),
  due_date      DATE,
  status        TEXT NOT NULL DEFAULT 'OPEN'
                CHECK (status IN ('OPEN','IN_PROGRESS','DONE','OVERDUE','CANCELLED')),
  completed_at  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_moc_actions_assignee ON moc_action_items (tenant_id, assignee_id, status);
CREATE INDEX idx_moc_actions_due      ON moc_action_items (tenant_id, due_date) WHERE status IN ('OPEN','IN_PROGRESS');

-- ----------------------------------------------------------------------------
-- 8. PSSR kontrol listeleri (şablon + doldurulmuş)
-- ----------------------------------------------------------------------------
CREATE TABLE moc_pssr_checklists (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     BIGINT NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  moc_id        BIGINT REFERENCES moc_requests(id) ON DELETE CASCADE, -- NULL = şablon
  is_template   BOOLEAN NOT NULL DEFAULT false,
  name          TEXT NOT NULL,
  items         JSONB NOT NULL DEFAULT '[]'::jsonb,
                -- [{ "no":1, "question":"...", "answer":"YES|NO|NA", "comment":"", "checked_by":id }]
  result        TEXT CHECK (result IN ('RELEASED','CONDITIONAL','NOT_RELEASED')),
  performed_by  BIGINT REFERENCES users(id),
  performed_at  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_moc_pssr_moc ON moc_pssr_checklists (moc_id);

-- ----------------------------------------------------------------------------
-- 9. Dokümanlar (MinIO ekleri + etkilenen doküman listesi)
-- ----------------------------------------------------------------------------
CREATE TABLE moc_documents (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     BIGINT NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  moc_id        BIGINT NOT NULL REFERENCES moc_requests(id) ON DELETE CASCADE,
  doc_kind      TEXT NOT NULL DEFAULT 'ATTACHMENT'
                CHECK (doc_kind IN ('ATTACHMENT','AFFECTED_DOC')),
  title         TEXT NOT NULL,
  doc_ref       TEXT,                          -- etkilenen dokümanın no'su (P&ID-101 vb.)
  old_version   TEXT,
  new_version   TEXT,
  storage_key   TEXT,                          -- MinIO object key (ek ise)
  mime_type     TEXT,
  size_bytes    BIGINT,
  uploaded_by   BIGINT REFERENCES users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_moc_documents_moc ON moc_documents (moc_id);

-- ----------------------------------------------------------------------------
-- 10. Eğitim / bilgilendirme kayıtları
-- ----------------------------------------------------------------------------
CREATE TABLE moc_trainings (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     BIGINT NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  moc_id        BIGINT NOT NULL REFERENCES moc_requests(id) ON DELETE CASCADE,
  user_id       BIGINT NOT NULL REFERENCES users(id),
  training_type TEXT NOT NULL DEFAULT 'INFO'
                CHECK (training_type IN ('INFO','CLASSROOM','ON_JOB')),
  acknowledged  BOOLEAN NOT NULL DEFAULT false, -- "okudum-anladım"
  acknowledged_at TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (moc_id, user_id)
);

-- ----------------------------------------------------------------------------
-- 11. Geçici değişiklik takibi
-- ----------------------------------------------------------------------------
CREATE TABLE moc_temporary_tracking (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     BIGINT NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  moc_id        BIGINT NOT NULL UNIQUE REFERENCES moc_requests(id) ON DELETE CASCADE,
  expires_at    DATE NOT NULL,
  warned_t7     BOOLEAN NOT NULL DEFAULT false, -- T-7 uyarısı gönderildi mi
  warned_t1     BOOLEAN NOT NULL DEFAULT false,
  escalated     BOOLEAN NOT NULL DEFAULT false, -- süre doldu, eskalasyon
  extension_count INT NOT NULL DEFAULT 0,
  extension_history JSONB NOT NULL DEFAULT '[]'::jsonb,
                -- [{ "old_date":"", "new_date":"", "approved_by":id, "at":"" }]
  restored_at   TIMESTAMPTZ,                    -- eski duruma dönüş tarihi
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_moc_temp_expires ON moc_temporary_tracking (tenant_id, expires_at) WHERE restored_at IS NULL;

-- ----------------------------------------------------------------------------
-- 12. Bildirimler
-- ----------------------------------------------------------------------------
CREATE TABLE moc_notifications (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     BIGINT NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  user_id       BIGINT NOT NULL REFERENCES users(id),
  moc_id        BIGINT REFERENCES moc_requests(id) ON DELETE CASCADE,
  channel       TEXT NOT NULL DEFAULT 'IN_APP' CHECK (channel IN ('IN_APP','EMAIL')),
  subject       TEXT NOT NULL,
  body          TEXT,
  is_read       BOOLEAN NOT NULL DEFAULT false,
  sent_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_moc_notif_user ON moc_notifications (tenant_id, user_id, is_read);

-- ----------------------------------------------------------------------------
-- 13. Audit log (append-only)
-- ----------------------------------------------------------------------------
CREATE TABLE moc_audit_log (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     BIGINT,
  table_name    TEXT NOT NULL,
  record_id     BIGINT,
  action        TEXT NOT NULL,                 -- INSERT / UPDATE / DELETE
  changed_by    BIGINT,
  old_data      JSONB,
  new_data      JSONB,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_moc_audit_record ON moc_audit_log (table_name, record_id);
-- Append-only garanti: UPDATE/DELETE yetkisi uygulama rolünden alınmalı:
-- REVOKE UPDATE, DELETE ON moc_audit_log FROM app_user;

-- ----------------------------------------------------------------------------
-- Trigger bağlama
-- ----------------------------------------------------------------------------
CREATE TRIGGER trg_moc_requests_updated  BEFORE UPDATE ON moc_requests
  FOR EACH ROW EXECUTE FUNCTION moc_set_updated_at();
CREATE TRIGGER trg_moc_actions_updated   BEFORE UPDATE ON moc_action_items
  FOR EACH ROW EXECUTE FUNCTION moc_set_updated_at();
CREATE TRIGGER trg_moc_temp_updated      BEFORE UPDATE ON moc_temporary_tracking
  FOR EACH ROW EXECUTE FUNCTION moc_set_updated_at();

CREATE TRIGGER trg_audit_moc_requests  AFTER INSERT OR UPDATE OR DELETE ON moc_requests
  FOR EACH ROW EXECUTE FUNCTION moc_audit_trigger();
CREATE TRIGGER trg_audit_moc_approvals AFTER INSERT OR UPDATE OR DELETE ON moc_approvals
  FOR EACH ROW EXECUTE FUNCTION moc_audit_trigger();
CREATE TRIGGER trg_audit_moc_risk      AFTER INSERT OR UPDATE OR DELETE ON moc_risk_assessments
  FOR EACH ROW EXECUTE FUNCTION moc_audit_trigger();

-- ----------------------------------------------------------------------------
-- Row-Level Security (tenant izolasyonu)
-- Backend her bağlantıda: SET app.tenant_id = '<tenant_id>';
-- ----------------------------------------------------------------------------
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'moc_requests','moc_equipment','moc_risk_assessments','moc_approvals',
    'moc_action_items','moc_pssr_checklists','moc_documents','moc_trainings',
    'moc_temporary_tracking','moc_notifications','moc_audit_log'
  ] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format(
      'CREATE POLICY tenant_isolation_%s ON %I
         USING (tenant_id = NULLIF(current_setting(''app.tenant_id'', true), '''')::BIGINT)',
      t, t);
  END LOOP;
END $$;

-- Lookup tabloları: kendi tenant'ı + global (NULL) kayıtlar görünür
ALTER TABLE moc_change_categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_or_global_categories ON moc_change_categories
  USING (tenant_id IS NULL OR tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);

ALTER TABLE moc_types ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_or_global_types ON moc_types
  USING (tenant_id IS NULL OR tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::BIGINT);

-- ----------------------------------------------------------------------------
-- SEED: Global varsayılan kategoriler (8) ve akış türleri (6)
-- ----------------------------------------------------------------------------
INSERT INTO moc_change_categories (tenant_id, code, name_tr, name_en, requires_equipment_link, sort_order) VALUES
  (NULL, 'EQUIPMENT',    'Ekipman',               'Equipment',                true,  1),
  (NULL, 'PROCESS',      'Proses',                'Process',                  false, 2),
  (NULL, 'CHEMICAL',     'Kimyasal / Hammadde',   'Chemical / Raw Material',  false, 3),
  (NULL, 'NEW_PRODUCT',  'Yeni Ürün Geliştirme',  'New Product Development',  false, 4),
  (NULL, 'PROJECT',      'Proje',                 'Project',                  false, 5),
  (NULL, 'PROCEDURE',    'Prosedür / Doküman',    'Procedure / Document',     false, 6),
  (NULL, 'ORGANIZATION', 'Organizasyonel',        'Organizational',           false, 7),
  (NULL, 'AUTOMATION',   'Yazılım / Otomasyon',   'Software / Automation',    false, 8);

INSERT INTO moc_types (tenant_id, code, name_tr, name_en, requires_pssr, requires_end_date, retro_hours) VALUES
  (NULL, 'PERMANENT',  'Kalıcı Değişiklik',      'Permanent Change',        true,  false, NULL),
  (NULL, 'TEMPORARY',  'Geçici Değişiklik',      'Temporary Change',        true,  true,  NULL),
  (NULL, 'EMERGENCY',  'Acil Değişiklik',        'Emergency Change',        true,  false, 72),
  (NULL, 'RIK',        'Birebir Yenileme',       'Replacement-in-Kind',     false, false, NULL),
  (NULL, 'MOOC',       'Organizasyonel Değişiklik', 'Management of Organizational Change', false, false, NULL),
  (NULL, 'PROCEDURAL', 'Prosedürel Değişiklik',  'Procedural Change',       false, false, NULL);

COMMIT;

-- ============================================================================
-- SONRAKİ ADIMLAR (uygulama katmanı):
--  1. Backend bağlantı middleware'i: SET app.tenant_id / app.user_id
--  2. moc_no üretici: MOC-{YIL}-{SIRA} (tenant bazlı sayaç)
--  3. Geçici değişiklik cron/Bull job: T-7, T-1 uyarı + süre dolumu eskalasyon
--  4. Durum makinesi (status geçiş kuralları) — bir sonraki dosya olarak
--     Mermaid state diagram + geçiş matrisi hazırlanabilir
-- ============================================================================
