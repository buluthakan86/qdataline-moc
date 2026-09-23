-- Faz O: MOC ile bağlı proje takip MVP şeması
-- Tenant bileşimi FK'lerle zorlanır; her tabloda RLS ve audit bulunur.
BEGIN;

CREATE UNIQUE INDEX IF NOT EXISTS uq_moc_requests_id_tenant ON public.moc_requests(id, tenant_id);

CREATE TABLE IF NOT EXISTS public.moc_projects (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 tenant_id UUID NOT NULL,
 moc_id BIGINT NOT NULL,
 name TEXT NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 240),
 status TEXT NOT NULL DEFAULT 'PLANNING' CHECK (status IN ('PLANNING','ACTIVE','BLOCKED','ON_HOLD','COMPLETED','CANCELLED')),
 project_lead_id UUID,
 sponsor_id UUID,
 planned_start DATE,
 planned_end DATE,
 actual_end DATE,
 risk_level TEXT NOT NULL DEFAULT 'NORMAL' CHECK (risk_level IN ('LOW','NORMAL','HIGH','CRITICAL')),
 budget_planned NUMERIC(14,2) CHECK (budget_planned IS NULL OR budget_planned >= 0),
 budget_actual NUMERIC(14,2) CHECK (budget_actual IS NULL OR budget_actual >= 0),
 currency CHAR(3) NOT NULL DEFAULT 'TRY',
 created_by UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 UNIQUE (tenant_id,moc_id), UNIQUE(id,tenant_id),
 FOREIGN KEY (moc_id,tenant_id) REFERENCES public.moc_requests(id,tenant_id) ON DELETE CASCADE,
 CHECK (planned_start IS NULL OR planned_end IS NULL OR planned_end >= planned_start)
);
CREATE INDEX IF NOT EXISTS idx_moc_projects_tenant_status ON public.moc_projects(tenant_id,status);

CREATE TABLE IF NOT EXISTS public.moc_project_phases (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 tenant_id UUID NOT NULL,
 project_id BIGINT NOT NULL,
 name TEXT NOT NULL,
 sort_order INT NOT NULL DEFAULT 0,
 planned_start DATE,
 planned_end DATE,
 status TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','IN_PROGRESS','DONE','BLOCKED')),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 UNIQUE(project_id,sort_order), UNIQUE(id,tenant_id,project_id),
 FOREIGN KEY(project_id,tenant_id) REFERENCES public.moc_projects(id,tenant_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.moc_project_tasks (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 tenant_id UUID NOT NULL,
 project_id BIGINT NOT NULL,
 phase_id BIGINT,
 title TEXT NOT NULL CHECK (length(trim(title)) BETWEEN 1 AND 300),
 description TEXT,
 status TEXT NOT NULL DEFAULT 'TODO' CHECK (status IN ('TODO','IN_PROGRESS','IN_REVIEW','BLOCKED','DONE','CANCELLED')),
 priority TEXT NOT NULL DEFAULT 'NORMAL' CHECK (priority IN ('LOW','NORMAL','HIGH','CRITICAL')),
 assignee_id UUID,
 planned_start DATE,
 due_date DATE,
 completed_at TIMESTAMPTZ,
 progress SMALLINT NOT NULL DEFAULT 0 CHECK (progress BETWEEN 0 AND 100),
 estimated_hours NUMERIC(10,2) CHECK (estimated_hours IS NULL OR estimated_hours >= 0),
 actual_hours NUMERIC(10,2) CHECK (actual_hours IS NULL OR actual_hours >= 0),
 required BOOLEAN NOT NULL DEFAULT false,
 evidence_required BOOLEAN NOT NULL DEFAULT false,
 created_by UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 UNIQUE(id,tenant_id,project_id),
 FOREIGN KEY(project_id,tenant_id) REFERENCES public.moc_projects(id,tenant_id) ON DELETE CASCADE,
 FOREIGN KEY(phase_id,tenant_id,project_id) REFERENCES public.moc_project_phases(id,tenant_id,project_id) ON DELETE RESTRICT,
 CHECK (planned_start IS NULL OR due_date IS NULL OR due_date >= planned_start)
);
CREATE INDEX IF NOT EXISTS idx_moc_tasks_project_status ON public.moc_project_tasks(tenant_id,project_id,status);
CREATE INDEX IF NOT EXISTS idx_moc_tasks_assignee_due ON public.moc_project_tasks(tenant_id,assignee_id,due_date);

CREATE TABLE IF NOT EXISTS public.moc_task_dependencies (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 tenant_id UUID NOT NULL,
 project_id BIGINT NOT NULL,
 predecessor_task_id BIGINT NOT NULL,
 successor_task_id BIGINT NOT NULL,
 dependency_type TEXT NOT NULL DEFAULT 'FINISH_TO_START' CHECK (dependency_type IN ('FINISH_TO_START','START_TO_START','FINISH_TO_FINISH','BLOCKS')),
 lag_days INT NOT NULL DEFAULT 0,
 created_by UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CHECK(predecessor_task_id <> successor_task_id),
 UNIQUE(predecessor_task_id,successor_task_id,dependency_type),
 FOREIGN KEY(project_id,tenant_id) REFERENCES public.moc_projects(id,tenant_id) ON DELETE CASCADE,
 FOREIGN KEY(predecessor_task_id,tenant_id,project_id) REFERENCES public.moc_project_tasks(id,tenant_id,project_id) ON DELETE CASCADE,
 FOREIGN KEY(successor_task_id,tenant_id,project_id) REFERENCES public.moc_project_tasks(id,tenant_id,project_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.moc_project_milestones (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 tenant_id UUID NOT NULL, project_id BIGINT NOT NULL,
 name TEXT NOT NULL,
 milestone_type TEXT NOT NULL CHECK (milestone_type IN ('APPROVAL','DOC_EFFECTIVE','TRAINING','PSSR','STARTUP','EFFECTIVENESS','CUSTOM')),
 target_date DATE, completed_at TIMESTAMPTZ, completed_by UUID REFERENCES auth.users(id),
 evidence_required BOOLEAN NOT NULL DEFAULT true, created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 FOREIGN KEY(project_id,tenant_id) REFERENCES public.moc_projects(id,tenant_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.moc_project_baselines (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 tenant_id UUID NOT NULL, project_id BIGINT NOT NULL,
 version_no INT NOT NULL CHECK(version_no > 0), snapshot JSONB NOT NULL, snapshot_hash TEXT NOT NULL,
 approved_by UUID REFERENCES auth.users(id), approved_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 UNIQUE(project_id,version_no), FOREIGN KEY(project_id,tenant_id) REFERENCES public.moc_projects(id,tenant_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.moc_project_costs (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 tenant_id UUID NOT NULL, project_id BIGINT NOT NULL, task_id BIGINT,
 cost_type TEXT NOT NULL CHECK (cost_type IN ('LABOR','PURCHASE','EXTERNAL_SERVICE','DOWNTIME','OTHER')),
 description TEXT, planned NUMERIC(14,2) CHECK(planned IS NULL OR planned >= 0), actual NUMERIC(14,2) CHECK(actual IS NULL OR actual >= 0),
 currency CHAR(3) NOT NULL DEFAULT 'TRY', document_ref TEXT,
 created_by UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id), created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 FOREIGN KEY(project_id,tenant_id) REFERENCES public.moc_projects(id,tenant_id) ON DELETE CASCADE,
 FOREIGN KEY(task_id,tenant_id,project_id) REFERENCES public.moc_project_tasks(id,tenant_id,project_id) ON DELETE RESTRICT
);

CREATE OR REPLACE FUNCTION public.moc_project_people_tenant_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF TG_TABLE_NAME='moc_projects' THEN
  IF NEW.project_lead_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=NEW.project_lead_id AND tenant_id=NEW.tenant_id) THEN RAISE EXCEPTION 'Proje lideri aynı firmada olmalıdır'; END IF;
  IF NEW.sponsor_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=NEW.sponsor_id AND tenant_id=NEW.tenant_id) THEN RAISE EXCEPTION 'Sponsor aynı firmada olmalıdır'; END IF;
 ELSIF TG_TABLE_NAME='moc_project_tasks' THEN
  IF NEW.assignee_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=NEW.assignee_id AND tenant_id=NEW.tenant_id) THEN RAISE EXCEPTION 'Görev sorumlusu aynı firmada olmalıdır'; END IF;
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS moc_projects_people_tenant_guard ON public.moc_projects;
CREATE TRIGGER moc_projects_people_tenant_guard BEFORE INSERT OR UPDATE OF project_lead_id,sponsor_id,tenant_id ON public.moc_projects FOR EACH ROW EXECUTE FUNCTION public.moc_project_people_tenant_guard();
DROP TRIGGER IF EXISTS moc_project_tasks_people_tenant_guard ON public.moc_project_tasks;
CREATE TRIGGER moc_project_tasks_people_tenant_guard BEFORE INSERT OR UPDATE OF assignee_id,tenant_id ON public.moc_project_tasks FOR EACH ROW EXECUTE FUNCTION public.moc_project_people_tenant_guard();

CREATE OR REPLACE FUNCTION public.moc_project_created_by_guard() RETURNS trigger LANGUAGE plpgsql SET search_path=public AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  IF NEW.created_by IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'created_by kullanıcı oturumuyla aynı olmalıdır'; END IF;
 ELSIF NEW.created_by IS DISTINCT FROM OLD.created_by THEN RAISE EXCEPTION 'created_by değiştirilemez';
 END IF;
 RETURN NEW;
END $$;
DO $$ DECLARE t text; BEGIN FOREACH t IN ARRAY ARRAY['moc_projects','moc_project_tasks','moc_task_dependencies','moc_project_costs'] LOOP EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I',t||'_created_by_guard',t); EXECUTE format('CREATE TRIGGER %I BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.moc_project_created_by_guard()',t||'_created_by_guard',t); END LOOP; END $$;
CREATE OR REPLACE FUNCTION public.moc_project_milestone_actor_guard() RETURNS trigger LANGUAGE plpgsql SET search_path=public AS $$
BEGIN
 IF NEW.completed_at IS NULL THEN
  NEW.completed_by:=NULL;
 ELSIF TG_OP='INSERT' THEN
  IF NEW.completed_by IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Tamamlayan kullanıcı oturumla aynı olmalıdır'; END IF;
 ELSIF NEW.completed_at IS DISTINCT FROM OLD.completed_at OR NEW.completed_by IS DISTINCT FROM OLD.completed_by THEN
  IF NEW.completed_by IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Tamamlayan bilgisi oturum kullanıcısıyla aynı olmalıdır'; END IF;
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS moc_project_milestones_actor_guard ON public.moc_project_milestones;
CREATE TRIGGER moc_project_milestones_actor_guard BEFORE INSERT OR UPDATE OF completed_at,completed_by ON public.moc_project_milestones FOR EACH ROW EXECUTE FUNCTION public.moc_project_milestone_actor_guard();

CREATE OR REPLACE FUNCTION public.moc_project_updated_at() RETURNS trigger LANGUAGE plpgsql SET search_path=public AS $$ BEGIN NEW.updated_at=now(); RETURN NEW; END $$;
DO $$ DECLARE t text; BEGIN FOREACH t IN ARRAY ARRAY['moc_projects','moc_project_phases','moc_project_tasks'] LOOP EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I',t||'_updated_at',t); EXECUTE format('CREATE TRIGGER %I BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.moc_project_updated_at()',t||'_updated_at',t); END LOOP; END $$;

ALTER TABLE public.moc_projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moc_project_phases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moc_project_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moc_task_dependencies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moc_project_milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moc_project_baselines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moc_project_costs ENABLE ROW LEVEL SECURITY;
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['moc_projects','moc_project_phases','moc_project_tasks','moc_task_dependencies','moc_project_milestones','moc_project_baselines','moc_project_costs'] LOOP
  EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I',t||'_select',t);
  EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT USING (tenant_id=public.current_tenant_id() AND EXISTS(SELECT 1 FROM public.modul_yetki WHERE user_id=auth.uid() AND modul=''moc''))',t||'_select',t);
  EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I',t||'_insert',t);
  EXECUTE format('CREATE POLICY %I ON public.%I FOR INSERT WITH CHECK (tenant_id=public.current_tenant_id() AND public.is_editor() AND EXISTS(SELECT 1 FROM public.modul_yetki WHERE user_id=auth.uid() AND modul=''moc''))',t||'_insert',t);
  EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I',t||'_update',t);
  EXECUTE format('CREATE POLICY %I ON public.%I FOR UPDATE USING (tenant_id=public.current_tenant_id() AND public.is_editor() AND EXISTS(SELECT 1 FROM public.modul_yetki WHERE user_id=auth.uid() AND modul=''moc'')) WITH CHECK (tenant_id=public.current_tenant_id() AND public.is_editor() AND EXISTS(SELECT 1 FROM public.modul_yetki WHERE user_id=auth.uid() AND modul=''moc''))',t||'_update',t);
  EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I',t||'_delete',t);
  EXECUTE format('CREATE POLICY %I ON public.%I FOR DELETE USING (tenant_id=public.current_tenant_id() AND public.is_admin() AND EXISTS(SELECT 1 FROM public.modul_yetki WHERE user_id=auth.uid() AND modul=''moc''))',t||'_delete',t);
  EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I',t||'_audit',t);
  EXECUTE format('CREATE TRIGGER %I AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.moc_audit_trigger()',t||'_audit',t);
  EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO authenticated',t);
  EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE public.%I_id_seq TO authenticated',t);
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.moc_project_create_for_request(p_moc_id bigint)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_tenant uuid; v_req public.moc_requests%ROWTYPE; v_project_id bigint;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_editor() THEN RAISE EXCEPTION 'Proje oluşturma yetkiniz yok'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.modul_yetki WHERE user_id=auth.uid() AND modul='moc') THEN RAISE EXCEPTION 'MOC modül erişimi bulunamadı'; END IF;
 v_tenant:=public.current_tenant_id();
 SELECT * INTO v_req FROM public.moc_requests WHERE id=p_moc_id AND tenant_id=v_tenant AND deleted_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'MOC kaydı bulunamadı'; END IF;
 IF v_req.status NOT IN ('IMPLEMENTATION','DOC_UPDATE','TRAINING','PSSR','STARTUP') THEN RAISE EXCEPTION 'Bu durumdaki MOC için uygulama planı açılamaz'; END IF;
 INSERT INTO public.moc_projects(tenant_id,moc_id,name,created_by)
 VALUES(v_tenant,p_moc_id,COALESCE(NULLIF(trim(v_req.title),''),v_req.moc_no),auth.uid())
 ON CONFLICT(tenant_id,moc_id) DO UPDATE SET moc_id=EXCLUDED.moc_id RETURNING id INTO v_project_id;
 INSERT INTO public.moc_project_phases(tenant_id,project_id,name,sort_order) VALUES
 (v_tenant,v_project_id,'Uygulama',0),(v_tenant,v_project_id,'Doküman güncelleme',1),(v_tenant,v_project_id,'Eğitim',2),(v_tenant,v_project_id,'PSSR / Devreye alma',3),(v_tenant,v_project_id,'Etkinlik kontrolü',4),(v_tenant,v_project_id,'Kapanış',5)
 ON CONFLICT(project_id,sort_order) DO NOTHING;
 INSERT INTO public.moc_project_tasks(tenant_id,project_id,phase_id,title,description,status,created_by)
 SELECT v_tenant,v_project_id,p.id,x.title,x.description,'TODO',auth.uid()
 FROM (VALUES
  (0,'Uygulama planını ve sorumluları netleştir','Onaylı değişiklik için uygulanacak adımları ve sorumluları doğrula.'),
  (1,'Etkilenen dokümanları güncelle','İlgili prosedür, talimat ve kayıtların revizyon ihtiyacını değerlendir.'),
  (2,'Etkilenen personel eğitimlerini tamamla','Yeni veya güncellenen iş adımları için eğitimleri planla ve kaydet.'),
  (3,'PSSR kontrollerini tamamla','Devreye alma öncesi gerekli saha ve güvenlik kontrollerini gözden geçir.'),
  (4,'Etkinlik kontrolünü gerçekleştir','Değişiklik sonrası beklenen sonucun sağlandığını belirlenen ölçütlerle doğrula.'),
  (5,'Açık aksiyonları ve kapanışı gözden geçir','Kalan işleri değerlendir ve MOC kapanışına hazırla.')
 ) AS x(phase_order,title,description)
 JOIN public.moc_project_phases p ON p.project_id=v_project_id AND p.tenant_id=v_tenant AND p.sort_order=x.phase_order
 WHERE NOT EXISTS(SELECT 1 FROM public.moc_project_tasks t WHERE t.project_id=v_project_id AND t.phase_id=p.id AND t.title=x.title);
 RETURN v_project_id;
END $$;
REVOKE ALL ON FUNCTION public.moc_project_create_for_request(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.moc_project_create_for_request(bigint) TO authenticated;

COMMIT;
