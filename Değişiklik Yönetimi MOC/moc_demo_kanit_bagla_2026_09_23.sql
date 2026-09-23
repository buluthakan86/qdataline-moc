-- Özel Storage kovasına yüklenen kurgusal görseli DEMO görevine bağlar.
BEGIN;
DO $$ DECLARE v_tenant uuid:='675ac400-7f2a-4f82-a5d4-a7d7fb3c11a4';
 v_editor uuid; v_project bigint; v_task bigint; v_phase bigint;
 v_key text:='675ac400-7f2a-4f82-a5d4-a7d7fb3c11a4/61/task-8-demo-20260923.png';
BEGIN
 SELECT p.id INTO v_editor FROM public.profiles p JOIN auth.users u ON u.id=p.id
  WHERE p.tenant_id=v_tenant AND p.is_active AND u.email='demo.kullanici@qdataline.com';
 SELECT p.id INTO v_project FROM public.moc_projects p JOIN public.moc_requests r ON r.id=p.moc_id
  WHERE p.tenant_id=v_tenant AND r.title='[DEMO] Paketleme hattı sensör yenilemesi';
 SELECT t.id,t.phase_id INTO v_task,v_phase FROM public.moc_project_tasks t
  JOIN public.moc_project_phases ph ON ph.id=t.phase_id
  WHERE t.project_id=v_project AND ph.sort_order=1 AND t.assignee_id=v_editor;
 IF v_editor IS NULL OR v_project IS NULL OR v_task IS NULL THEN RAISE EXCEPTION 'DEMO_TASK_MISSING'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.moc_task_evidence e JOIN public.moc_documents d ON d.id=e.document_id
  WHERE e.task_id=v_task AND d.storage_key=v_key) THEN
  PERFORM set_config('request.jwt.claim.sub',v_editor::text,true);
  PERFORM public.moc_project_add_task_evidence(v_task,'[DEMO] Sensör talimatı örnek revizyonu',v_key,'image/png',37232);
 END IF;
 PERFORM set_config('request.jwt.claim.sub',v_editor::text,true);
 UPDATE public.moc_task_checklist_items SET done=true WHERE task_id=v_task AND done=false;
 UPDATE public.moc_project_tasks SET status='DONE',progress=100,completed_at=COALESCE(completed_at,now()),actual_hours=6
  WHERE id=v_task AND status<>'DONE';
 UPDATE public.moc_project_phases SET status='DONE' WHERE id=v_phase;
END $$;
COMMIT;
