-- Faz T: MOC kaydı olmadan proje açma. Mevcut MOC bağlantılı kayıtlar korunur.
BEGIN;

ALTER TABLE public.moc_projects ALTER COLUMN moc_id DROP NOT NULL;
ALTER TABLE public.moc_projects ADD COLUMN IF NOT EXISTS description text;

CREATE OR REPLACE FUNCTION public.moc_project_can_manage(p_project bigint) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT public.is_admin() OR EXISTS(
  SELECT 1 FROM public.moc_projects p
  LEFT JOIN public.moc_requests r ON r.id=p.moc_id AND r.tenant_id=p.tenant_id
  WHERE p.id=p_project AND p.tenant_id=public.current_tenant_id()
    AND (p.created_by=auth.uid() OR p.project_lead_id=auth.uid() OR r.coordinator_id=auth.uid())
 )
$$;

CREATE OR REPLACE FUNCTION public.moc_project_create_standalone(
 p_name text, p_description text DEFAULT NULL, p_planned_start date DEFAULT NULL, p_planned_end date DEFAULT NULL
) RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_tenant uuid; v_project bigint;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_editor() OR NOT EXISTS
  (SELECT 1 FROM public.modul_yetki WHERE user_id=auth.uid() AND modul='moc')
  THEN RAISE EXCEPTION 'Proje oluşturma yetkiniz yok'; END IF;
 IF nullif(trim(p_name),'') IS NULL OR length(trim(p_name))>240 THEN RAISE EXCEPTION 'Proje adı 1–240 karakter olmalı'; END IF;
 IF p_planned_start IS NOT NULL AND p_planned_end IS NOT NULL AND p_planned_end<p_planned_start
  THEN RAISE EXCEPTION 'Bitiş tarihi başlangıçtan önce olamaz'; END IF;
 v_tenant:=public.current_tenant_id();
 IF v_tenant IS NULL THEN RAISE EXCEPTION 'Firma bulunamadı'; END IF;
 INSERT INTO public.moc_projects(tenant_id,moc_id,name,description,project_lead_id,planned_start,planned_end,created_by)
 VALUES(v_tenant,NULL,trim(p_name),nullif(trim(p_description),''),auth.uid(),p_planned_start,p_planned_end,auth.uid())
 RETURNING id INTO v_project;
 INSERT INTO public.moc_project_phases(tenant_id,project_id,name,sort_order) VALUES
  (v_tenant,v_project,'Başlatma',0),(v_tenant,v_project,'Planlama',1),
  (v_tenant,v_project,'Uygulama',2),(v_tenant,v_project,'İzleme ve kontrol',3),
  (v_tenant,v_project,'Kapanış',4);
 RETURN v_project;
END $$;
REVOKE ALL ON FUNCTION public.moc_project_create_standalone(text,text,date,date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.moc_project_create_standalone(text,text,date,date) TO authenticated;

-- Bağımsız projelerin kanıtı MOC belgesine zorla bağlanamaz.
ALTER TABLE public.moc_task_evidence ALTER COLUMN document_id DROP NOT NULL;
ALTER TABLE public.moc_task_evidence ADD COLUMN IF NOT EXISTS title text;
ALTER TABLE public.moc_task_evidence ADD COLUMN IF NOT EXISTS storage_key text;
ALTER TABLE public.moc_task_evidence ADD COLUMN IF NOT EXISTS mime_type text;
ALTER TABLE public.moc_task_evidence ADD COLUMN IF NOT EXISTS size_bytes bigint;
ALTER TABLE public.moc_task_evidence ADD CONSTRAINT moc_task_evidence_source_check CHECK
 ((document_id IS NOT NULL AND storage_key IS NULL) OR (document_id IS NULL AND storage_key IS NOT NULL));
CREATE UNIQUE INDEX IF NOT EXISTS moc_task_evidence_storage_key_idx ON public.moc_task_evidence(storage_key) WHERE storage_key IS NOT NULL;

ALTER TABLE public.moc_notifications ADD COLUMN IF NOT EXISTS project_id bigint;
ALTER TABLE public.moc_notifications ADD CONSTRAINT moc_notifications_project_tenant_fk
 FOREIGN KEY(project_id,tenant_id) REFERENCES public.moc_projects(id,tenant_id) ON DELETE CASCADE;

CREATE OR REPLACE FUNCTION public.moc_project_task_notify() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_moc bigint; v_no text; v_manager uuid;
BEGIN
 SELECT p.moc_id,COALESCE(r.moc_no,p.name),COALESCE(p.project_lead_id,r.coordinator_id,p.created_by)
 INTO v_moc,v_no,v_manager FROM public.moc_projects p
 LEFT JOIN public.moc_requests r ON r.id=p.moc_id AND r.tenant_id=p.tenant_id
 WHERE p.id=NEW.project_id AND p.tenant_id=NEW.tenant_id;
 IF NEW.assignee_id IS NOT NULL AND (TG_OP='INSERT' OR NEW.assignee_id IS DISTINCT FROM OLD.assignee_id) THEN
  INSERT INTO public.moc_notifications(tenant_id,user_id,moc_id,project_id,channel,subject,body)
  VALUES(NEW.tenant_id,NEW.assignee_id,v_moc,NEW.project_id,'IN_APP',v_no||' · Yeni proje görevi',
   NEW.title||CASE WHEN NEW.due_date IS NULL THEN '' ELSE ' · Termin: '||NEW.due_date::text END);
 ELSIF TG_OP='UPDATE' AND NEW.due_date IS DISTINCT FROM OLD.due_date AND NEW.assignee_id IS NOT NULL THEN
  INSERT INTO public.moc_notifications(tenant_id,user_id,moc_id,project_id,channel,subject,body)
  VALUES(NEW.tenant_id,NEW.assignee_id,v_moc,NEW.project_id,'IN_APP',v_no||' · Görev termini güncellendi',
   NEW.title||' · Yeni termin: '||COALESCE(NEW.due_date::text,'—'));
 END IF;
 IF TG_OP='UPDATE' AND NEW.status IS DISTINCT FROM OLD.status
  AND NEW.status IN ('IN_REVIEW','BLOCKED','DONE') AND v_manager IS NOT NULL AND v_manager IS DISTINCT FROM auth.uid() THEN
  INSERT INTO public.moc_notifications(tenant_id,user_id,moc_id,project_id,channel,subject,body)
  VALUES(NEW.tenant_id,v_manager,v_moc,NEW.project_id,'IN_APP',v_no||' · Görev durumu: '||NEW.status,NEW.title);
 END IF;
 RETURN NEW;
END $$;

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
 IF v_moc IS NULL THEN
  IF NEW.document_id IS NOT NULL OR NEW.storage_key NOT LIKE NEW.tenant_id::text||'/projects/'||NEW.project_id::text||'/%'
   OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='moc-belgeler' AND name=NEW.storage_key)
   THEN RAISE EXCEPTION 'MOC_GECERSIZ_KANIT'; END IF;
 ELSE
  IF EXISTS(SELECT 1 FROM public.moc_requests WHERE id=v_moc AND status='CLOSED')
   THEN RAISE EXCEPTION 'MOC_KAPALI_PROJE_DEGISTIRILEMEZ'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.moc_documents d WHERE d.id=NEW.document_id
    AND d.tenant_id=NEW.tenant_id AND d.moc_id=v_moc AND d.storage_key IS NOT NULL)
   THEN RAISE EXCEPTION 'MOC_GECERSIZ_KANIT'; END IF;
 END IF;
 IF NEW.created_by IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'MOC_GECERSIZ_KULLANICI'; END IF;
 RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.moc_project_add_task_evidence(
 p_task_id bigint,p_title text,p_storage_key text,p_mime_type text,p_size_bytes bigint
) RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_task public.moc_project_tasks%ROWTYPE; v_moc bigint; v_document bigint; v_evidence bigint;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_editor() OR NOT EXISTS
  (SELECT 1 FROM public.modul_yetki WHERE user_id=auth.uid() AND modul='moc')
  THEN RAISE EXCEPTION 'MOC_GOREV_YETKI_YOK'; END IF;
 SELECT * INTO v_task FROM public.moc_project_tasks WHERE id=p_task_id AND tenant_id=public.current_tenant_id();
 IF NOT FOUND OR NOT public.moc_project_can_work(p_task_id) THEN RAISE EXCEPTION 'MOC_GOREV_YETKI_YOK'; END IF;
 SELECT moc_id INTO v_moc FROM public.moc_projects WHERE id=v_task.project_id AND tenant_id=v_task.tenant_id;
 IF nullif(trim(p_title),'') IS NULL OR p_size_bytes IS NULL OR p_size_bytes<1 OR p_size_bytes>20971520
  OR p_mime_type NOT IN ('application/pdf','image/png','image/jpeg','image/webp')
  THEN RAISE EXCEPTION 'MOC_GECERSIZ_KANIT'; END IF;
 IF v_moc IS NULL THEN
  IF p_storage_key NOT LIKE v_task.tenant_id::text||'/projects/'||v_task.project_id::text||'/%'
   OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='moc-belgeler' AND name=p_storage_key)
   THEN RAISE EXCEPTION 'MOC_GECERSIZ_KANIT'; END IF;
  INSERT INTO public.moc_task_evidence(tenant_id,project_id,task_id,title,storage_key,mime_type,size_bytes,created_by)
  VALUES(v_task.tenant_id,v_task.project_id,p_task_id,left(trim(p_title),300),p_storage_key,p_mime_type,p_size_bytes,auth.uid())
  RETURNING id INTO v_evidence;
  RETURN v_evidence;
 END IF;
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

COMMIT;
