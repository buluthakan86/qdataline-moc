-- Proje&MOC: görev kontrol listesi, kanıt ve kapanış güvenceleri.
BEGIN;

CREATE TABLE IF NOT EXISTS public.moc_task_checklist_items (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 tenant_id uuid NOT NULL,
 project_id bigint NOT NULL,
 task_id bigint NOT NULL,
 title text NOT NULL CHECK (length(trim(title)) BETWEEN 1 AND 300),
 done boolean NOT NULL DEFAULT false,
 done_by uuid REFERENCES auth.users(id),
 done_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(id,tenant_id,project_id,task_id),
 FOREIGN KEY(task_id,tenant_id,project_id) REFERENCES public.moc_project_tasks(id,tenant_id,project_id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_moc_task_checklist_task ON public.moc_task_checklist_items(tenant_id,project_id,task_id);

CREATE TABLE IF NOT EXISTS public.moc_task_evidence (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 tenant_id uuid NOT NULL,
 project_id bigint NOT NULL,
 task_id bigint NOT NULL,
 document_id bigint NOT NULL UNIQUE REFERENCES public.moc_documents(id) ON DELETE RESTRICT,
 created_by uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(task_id,tenant_id,project_id) REFERENCES public.moc_project_tasks(id,tenant_id,project_id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_moc_task_evidence_task ON public.moc_task_evidence(tenant_id,project_id,task_id);

DROP TRIGGER IF EXISTS moc_task_checklist_guard ON public.moc_task_checklist_items;
DROP TRIGGER IF EXISTS moc_task_evidence_guard ON public.moc_task_evidence;
DROP TRIGGER IF EXISTS moc_task_checklist_audit ON public.moc_task_checklist_items;
DROP TRIGGER IF EXISTS moc_task_evidence_audit ON public.moc_task_evidence;
DROP TRIGGER IF EXISTS moc_project_task_integrity_guard ON public.moc_project_tasks;
DROP TRIGGER IF EXISTS moc_project_close_guard ON public.moc_requests;
DROP TRIGGER IF EXISTS moc_project_task_notify ON public.moc_project_tasks;
DROP TRIGGER IF EXISTS moc_project_status_guard ON public.moc_projects;
DO $$ DECLARE p text; BEGIN
 FOREACH p IN ARRAY ARRAY['moc_task_checklist_select','moc_task_checklist_insert','moc_task_checklist_update','moc_task_checklist_delete'] LOOP
  EXECUTE format('DROP POLICY IF EXISTS %I ON public.moc_task_checklist_items',p);
 END LOOP;
 FOREACH p IN ARRAY ARRAY['moc_task_evidence_select','moc_task_evidence_insert','moc_task_evidence_delete'] LOOP
  EXECUTE format('DROP POLICY IF EXISTS %I ON public.moc_task_evidence',p);
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.moc_project_can_manage(p_project bigint) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT public.is_admin() OR EXISTS(
  SELECT 1 FROM public.moc_projects p JOIN public.moc_requests r ON r.id=p.moc_id AND r.tenant_id=p.tenant_id
  WHERE p.id=p_project AND p.tenant_id=public.current_tenant_id()
    AND (p.created_by=auth.uid() OR p.project_lead_id=auth.uid() OR r.coordinator_id=auth.uid())
 )
$$;
REVOKE ALL ON FUNCTION public.moc_project_can_manage(bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.moc_project_can_manage(bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.moc_project_can_work(p_task bigint) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT EXISTS(SELECT 1 FROM public.moc_project_tasks t WHERE t.id=p_task
  AND t.tenant_id=public.current_tenant_id()
  AND (t.assignee_id=auth.uid() OR public.moc_project_can_manage(t.project_id)))
$$;
REVOKE ALL ON FUNCTION public.moc_project_can_work(bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.moc_project_can_work(bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.moc_task_checklist_guard() RETURNS trigger
LANGUAGE plpgsql SET search_path=public AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM public.moc_projects p JOIN public.moc_requests r ON r.id=p.moc_id
  WHERE p.id=NEW.project_id AND r.status='CLOSED') THEN RAISE EXCEPTION 'MOC_KAPALI_PROJE_DEGISTIRILEMEZ'; END IF;
 IF TG_OP='UPDATE' THEN
  IF (NEW.tenant_id,NEW.project_id,NEW.task_id,NEW.title) IS DISTINCT FROM
     (OLD.tenant_id,OLD.project_id,OLD.task_id,OLD.title)
    AND NOT public.moc_project_can_manage(OLD.project_id) THEN RAISE EXCEPTION 'MOC_GOREV_YETKI_YOK'; END IF;
  IF NEW.done IS DISTINCT FROM OLD.done THEN
   NEW.done_by:=CASE WHEN NEW.done THEN auth.uid() ELSE NULL END;
   NEW.done_at:=CASE WHEN NEW.done THEN now() ELSE NULL END;
  END IF;
 ELSIF TG_OP='INSERT' THEN
  NEW.done:=false; NEW.done_by:=NULL; NEW.done_at:=NULL;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER moc_task_checklist_guard BEFORE INSERT OR UPDATE ON public.moc_task_checklist_items
 FOR EACH ROW EXECUTE FUNCTION public.moc_task_checklist_guard();

CREATE OR REPLACE FUNCTION public.moc_task_evidence_guard() RETURNS trigger
LANGUAGE plpgsql SET search_path=public AS $$
DECLARE v_moc bigint;
BEGIN
 IF TG_OP='DELETE' THEN
  IF EXISTS(SELECT 1 FROM public.moc_projects p JOIN public.moc_requests r ON r.id=p.moc_id
    WHERE p.id=OLD.project_id AND r.status='CLOSED') THEN RAISE EXCEPTION 'MOC_KAPALI_KANIT_SILINEMEZ'; END IF;
  RETURN OLD;
 END IF;
 SELECT moc_id INTO v_moc FROM public.moc_projects WHERE id=NEW.project_id AND tenant_id=NEW.tenant_id;
 IF EXISTS(SELECT 1 FROM public.moc_requests WHERE id=v_moc AND status='CLOSED')
  THEN RAISE EXCEPTION 'MOC_KAPALI_PROJE_DEGISTIRILEMEZ'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.moc_documents d WHERE d.id=NEW.document_id
   AND d.tenant_id=NEW.tenant_id AND d.moc_id=v_moc AND d.storage_key IS NOT NULL)
   THEN RAISE EXCEPTION 'MOC_GECERSIZ_KANIT'; END IF;
 IF NEW.created_by IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'MOC_GECERSIZ_KULLANICI'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER moc_task_evidence_guard BEFORE INSERT OR DELETE ON public.moc_task_evidence
 FOR EACH ROW EXECUTE FUNCTION public.moc_task_evidence_guard();

ALTER TABLE public.moc_task_checklist_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moc_task_evidence ENABLE ROW LEVEL SECURITY;
CREATE POLICY moc_task_checklist_select ON public.moc_task_checklist_items FOR SELECT USING
 (tenant_id=public.current_tenant_id() AND EXISTS(SELECT 1 FROM public.modul_yetki WHERE user_id=auth.uid() AND modul='moc'));
CREATE POLICY moc_task_checklist_insert ON public.moc_task_checklist_items FOR INSERT WITH CHECK
 (tenant_id=public.current_tenant_id() AND public.is_editor() AND public.moc_project_can_manage(project_id));
CREATE POLICY moc_task_checklist_update ON public.moc_task_checklist_items FOR UPDATE USING
 (tenant_id=public.current_tenant_id() AND public.is_editor() AND public.moc_project_can_work(task_id)) WITH CHECK
 (tenant_id=public.current_tenant_id() AND public.is_editor() AND public.moc_project_can_work(task_id));
CREATE POLICY moc_task_checklist_delete ON public.moc_task_checklist_items FOR DELETE USING
 (tenant_id=public.current_tenant_id() AND public.is_editor() AND public.moc_project_can_manage(project_id));
CREATE POLICY moc_task_evidence_select ON public.moc_task_evidence FOR SELECT USING
 (tenant_id=public.current_tenant_id() AND EXISTS(SELECT 1 FROM public.modul_yetki WHERE user_id=auth.uid() AND modul='moc'));
CREATE POLICY moc_task_evidence_insert ON public.moc_task_evidence FOR INSERT WITH CHECK
 (tenant_id=public.current_tenant_id() AND public.is_editor() AND public.moc_project_can_work(task_id));
CREATE POLICY moc_task_evidence_delete ON public.moc_task_evidence FOR DELETE USING
 (tenant_id=public.current_tenant_id() AND public.is_editor() AND public.moc_project_can_manage(project_id));
GRANT SELECT,INSERT,UPDATE,DELETE ON public.moc_task_checklist_items,public.moc_task_evidence TO authenticated;
GRANT USAGE,SELECT ON SEQUENCE public.moc_task_checklist_items_id_seq,public.moc_task_evidence_id_seq TO authenticated;
CREATE TRIGGER moc_task_checklist_audit AFTER INSERT OR UPDATE OR DELETE ON public.moc_task_checklist_items
 FOR EACH ROW EXECUTE FUNCTION public.moc_audit_trigger();
CREATE TRIGGER moc_task_evidence_audit AFTER INSERT OR UPDATE OR DELETE ON public.moc_task_evidence
 FOR EACH ROW EXECUTE FUNCTION public.moc_audit_trigger();

-- Dosya Storage'a yüklendikten sonra belge ve görev bağlantısını tek işlemde kaydeder.
CREATE OR REPLACE FUNCTION public.moc_project_add_task_evidence(
 p_task_id bigint,p_title text,p_storage_key text,p_mime_type text,p_size_bytes bigint
) RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_task public.moc_project_tasks%ROWTYPE; v_moc bigint; v_document bigint;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_editor() OR NOT EXISTS
  (SELECT 1 FROM public.modul_yetki WHERE user_id=auth.uid() AND modul='moc')
  THEN RAISE EXCEPTION 'MOC_GOREV_YETKI_YOK'; END IF;
 SELECT * INTO v_task FROM public.moc_project_tasks WHERE id=p_task_id AND tenant_id=public.current_tenant_id();
 IF NOT FOUND OR NOT public.moc_project_can_work(p_task_id) THEN RAISE EXCEPTION 'MOC_GOREV_YETKI_YOK'; END IF;
 SELECT moc_id INTO v_moc FROM public.moc_projects WHERE id=v_task.project_id AND tenant_id=v_task.tenant_id;
 IF nullif(trim(p_title),'') IS NULL OR p_size_bytes IS NULL OR p_size_bytes<1 OR p_size_bytes>20971520
  OR p_mime_type IS NULL OR p_mime_type NOT IN ('application/pdf','image/png','image/jpeg','image/webp')
  THEN RAISE EXCEPTION 'MOC_GECERSIZ_KANIT'; END IF;
 IF p_storage_key NOT LIKE v_task.tenant_id::text||'/'||v_moc::text||'/%'
  OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='moc-belgeler' AND name=p_storage_key)
  THEN RAISE EXCEPTION 'MOC_GECERSIZ_KANIT'; END IF;
 INSERT INTO public.moc_documents(tenant_id,moc_id,doc_kind,title,storage_key,mime_type,size_bytes,uploaded_by)
 VALUES(v_task.tenant_id,v_moc,'ATTACHMENT',left(trim(p_title),300),p_storage_key,p_mime_type,p_size_bytes,auth.uid())
 RETURNING id INTO v_document;
 INSERT INTO public.moc_task_evidence(tenant_id,project_id,task_id,document_id,created_by)
 VALUES(v_task.tenant_id,v_task.project_id,p_task_id,v_document,auth.uid());
 RETURN v_document;
END $$;
REVOKE ALL ON FUNCTION public.moc_project_add_task_evidence(bigint,text,text,text,bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.moc_project_add_task_evidence(bigint,text,text,text,bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.moc_project_task_integrity_guard() RETURNS trigger
LANGUAGE plpgsql SET search_path=public AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM public.moc_projects p JOIN public.moc_requests r ON r.id=p.moc_id
   WHERE p.id=NEW.project_id AND r.status='CLOSED')
  THEN RAISE EXCEPTION 'MOC_KAPALI_PROJE_DEGISTIRILEMEZ'; END IF;
 IF TG_OP='INSERT' AND auth.uid() IS NOT NULL AND NOT public.moc_project_can_manage(NEW.project_id)
  THEN RAISE EXCEPTION 'MOC_GOREV_YETKI_YOK'; END IF;
 IF TG_OP='UPDATE' AND auth.uid() IS NOT NULL AND NOT public.moc_project_can_manage(OLD.project_id) THEN
  IF OLD.assignee_id IS DISTINCT FROM auth.uid() OR
   (to_jsonb(NEW) - 'status' - 'progress' - 'completed_at' - 'actual_hours' - 'updated_at')
   IS DISTINCT FROM
   (to_jsonb(OLD) - 'status' - 'progress' - 'completed_at' - 'actual_hours' - 'updated_at')
   THEN RAISE EXCEPTION 'MOC_GOREV_YETKI_YOK'; END IF;
 END IF;
 IF NEW.status='DONE' THEN
  IF EXISTS(SELECT 1 FROM public.moc_task_checklist_items c WHERE c.task_id=NEW.id AND NOT c.done)
   THEN RAISE EXCEPTION 'MOC_KONTROL_LISTESI_EKSIK'; END IF;
  IF NEW.evidence_required AND NOT EXISTS(SELECT 1 FROM public.moc_task_evidence e WHERE e.task_id=NEW.id)
   THEN RAISE EXCEPTION 'MOC_GOREV_KANITI_EKSIK'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER moc_project_task_integrity_guard BEFORE INSERT OR UPDATE ON public.moc_project_tasks
 FOR EACH ROW EXECUTE FUNCTION public.moc_project_task_integrity_guard();

CREATE OR REPLACE FUNCTION public.moc_project_task_notify() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_moc bigint; v_no text; v_manager uuid;
BEGIN
 SELECT p.moc_id,r.moc_no,COALESCE(p.project_lead_id,r.coordinator_id,p.created_by)
 INTO v_moc,v_no,v_manager FROM public.moc_projects p
 JOIN public.moc_requests r ON r.id=p.moc_id WHERE p.id=NEW.project_id AND p.tenant_id=NEW.tenant_id;
 IF NEW.assignee_id IS NOT NULL AND (TG_OP='INSERT' OR NEW.assignee_id IS DISTINCT FROM OLD.assignee_id) THEN
  INSERT INTO public.moc_notifications(tenant_id,user_id,moc_id,channel,subject,body)
  VALUES(NEW.tenant_id,NEW.assignee_id,v_moc,'IN_APP',v_no||' · Yeni proje görevi',
   NEW.title||CASE WHEN NEW.due_date IS NULL THEN '' ELSE ' · Termin: '||NEW.due_date::text END);
 ELSIF TG_OP='UPDATE' AND NEW.due_date IS DISTINCT FROM OLD.due_date AND NEW.assignee_id IS NOT NULL THEN
  INSERT INTO public.moc_notifications(tenant_id,user_id,moc_id,channel,subject,body)
  VALUES(NEW.tenant_id,NEW.assignee_id,v_moc,'IN_APP',v_no||' · Görev termini güncellendi',
   NEW.title||' · Yeni termin: '||COALESCE(NEW.due_date::text,'—'));
 END IF;
 IF TG_OP='UPDATE' AND NEW.status IS DISTINCT FROM OLD.status
  AND NEW.status IN ('IN_REVIEW','BLOCKED','DONE') AND v_manager IS NOT NULL AND v_manager IS DISTINCT FROM auth.uid() THEN
  INSERT INTO public.moc_notifications(tenant_id,user_id,moc_id,channel,subject,body)
  VALUES(NEW.tenant_id,v_manager,v_moc,'IN_APP',v_no||' · Görev durumu: '||NEW.status,NEW.title);
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER moc_project_task_notify AFTER INSERT OR UPDATE OF assignee_id,status,due_date ON public.moc_project_tasks
 FOR EACH ROW EXECUTE FUNCTION public.moc_project_task_notify();

CREATE OR REPLACE FUNCTION public.moc_project_status_guard() RETURNS trigger
LANGUAGE plpgsql SET search_path=public AS $$
BEGIN
 IF NEW.status='COMPLETED' AND OLD.status IS DISTINCT FROM NEW.status
  AND EXISTS(SELECT 1 FROM public.moc_project_tasks t WHERE t.project_id=NEW.id AND t.required AND t.status<>'DONE')
  THEN RAISE EXCEPTION 'MOC_ZORUNLU_GOREV_ACIK'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER moc_project_status_guard BEFORE UPDATE OF status ON public.moc_projects
 FOR EACH ROW EXECUTE FUNCTION public.moc_project_status_guard();

CREATE OR REPLACE FUNCTION public.moc_project_close_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_project bigint;
BEGIN
 IF TG_OP='UPDATE' AND NEW.status='CLOSED' AND OLD.status IS DISTINCT FROM NEW.status AND OLD.status='STARTUP' THEN
  SELECT id INTO v_project FROM public.moc_projects WHERE moc_id=NEW.id AND tenant_id=NEW.tenant_id;
  IF v_project IS NOT NULL THEN
   IF EXISTS(SELECT 1 FROM public.moc_project_tasks t WHERE t.project_id=v_project AND t.required AND t.status<>'DONE')
    THEN RAISE EXCEPTION 'MOC_ZORUNLU_GOREV_ACIK'; END IF;
   IF EXISTS(SELECT 1 FROM public.moc_task_checklist_items c JOIN public.moc_project_tasks t ON t.id=c.task_id
     WHERE c.project_id=v_project AND t.required AND NOT c.done)
    THEN RAISE EXCEPTION 'MOC_KONTROL_LISTESI_EKSIK'; END IF;
   IF EXISTS(SELECT 1 FROM public.moc_project_tasks t WHERE t.project_id=v_project AND t.required AND t.evidence_required
     AND NOT EXISTS(SELECT 1 FROM public.moc_task_evidence e WHERE e.task_id=t.id))
    THEN RAISE EXCEPTION 'MOC_GOREV_KANITI_EKSIK'; END IF;
   IF EXISTS(SELECT 1 FROM public.moc_project_milestones m WHERE m.project_id=v_project
     AND m.milestone_type IN ('DOC_EFFECTIVE','TRAINING','PSSR','EFFECTIVENESS') AND m.completed_at IS NULL)
    THEN RAISE EXCEPTION 'MOC_KILOMETRE_TASI_EKSIK'; END IF;
   UPDATE public.moc_projects SET status='COMPLETED',actual_end=COALESCE(actual_end,current_date)
    WHERE id=v_project AND status<>'COMPLETED';
  END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER moc_project_close_guard BEFORE UPDATE OF status ON public.moc_requests
 FOR EACH ROW EXECUTE FUNCTION public.moc_project_close_guard();
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
 INSERT INTO public.moc_project_tasks(tenant_id,project_id,phase_id,title,description,status,created_by,required,evidence_required)
 SELECT v_tenant,v_project_id,p.id,x.title,x.description,'TODO',auth.uid(),true,x.phase_order IN (1,2,3,4)
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

COMMIT;
