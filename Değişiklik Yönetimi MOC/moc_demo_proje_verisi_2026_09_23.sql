-- Yalnız canlı DEMO tenant için; gerçek müşteri verisi içermez.
-- Aynı başlık varsa yeniden kayıt açmaz. Önce COMMIT yerine ROLLBACK ile prova edilir.
BEGIN;
DO $$
DECLARE
 v_tenant uuid:='675ac400-7f2a-4f82-a5d4-a7d7fb3c11a4';
 v_manager uuid; v_editor uuid; v_cat bigint; v_type bigint;
 v_moc bigint; v_approval bigint; v_project bigint;
 v_implementation bigint; v_doc bigint; v_training bigint;
 v_snapshot jsonb;
 v_title text:='[DEMO] Paketleme hattı sensör yenilemesi';
BEGIN
 SELECT p.id INTO v_manager FROM public.profiles p JOIN auth.users u ON u.id=p.id
  WHERE p.tenant_id=v_tenant AND p.is_active AND p.role='ADMIN'
    AND u.email='demo.yonetici@qdataline.com'
    AND EXISTS(SELECT 1 FROM public.modul_yetki y WHERE y.user_id=p.id AND y.modul='moc');
 SELECT p.id INTO v_editor FROM public.profiles p JOIN auth.users u ON u.id=p.id
  WHERE p.tenant_id=v_tenant AND p.is_active AND p.role='EDITOR'
    AND u.email='demo.kullanici@qdataline.com'
    AND EXISTS(SELECT 1 FROM public.modul_yetki y WHERE y.user_id=p.id AND y.modul='moc');
 IF v_manager IS NULL OR v_editor IS NULL THEN RAISE EXCEPTION 'DEMO_USERS_MISSING'; END IF;
 SELECT id INTO v_moc FROM public.moc_requests WHERE tenant_id=v_tenant AND title=v_title AND deleted_at IS NULL;
 IF v_moc IS NOT NULL THEN
  RAISE NOTICE 'Demo MOC zaten mevcut: %',v_moc;
  RETURN;
 END IF;
 SELECT id INTO v_cat FROM public.moc_change_categories WHERE code='EQUIPMENT' AND tenant_id IS NULL LIMIT 1;
 SELECT id INTO v_type FROM public.moc_types WHERE code='PERMANENT' AND tenant_id IS NULL LIMIT 1;
 IF v_cat IS NULL OR v_type IS NULL THEN RAISE EXCEPTION 'DEMO_CLASSIFICATION_MISSING'; END IF;

 PERFORM set_config('request.jwt.claim.sub',v_manager::text,true);
 INSERT INTO public.moc_requests(tenant_id,moc_no,title,description,category_id,type_id,status,
  priority,initiator_id,coordinator_id,unit_area,reason,planned_start,planned_end)
 VALUES(v_tenant,NULL,v_title,
  'Tamamen kurgusal örnek: paketleme hattında bir algılayıcının yenilenmesi ve devreye alınması. Gerçek tesis, müşteri veya üretim verisi içermez.',
  v_cat,v_type,'DRAFT','NORMAL',v_editor,v_manager,'DEMO tesis / Paketleme hattı',
  'Örnek proje yönetimi ve MOC iş akışını denemek',current_date-3,current_date+35)
 RETURNING id INTO v_moc;
 UPDATE public.moc_requests SET status='SCREENING' WHERE id=v_moc;
 UPDATE public.moc_requests SET status='RISK_ASSESSMENT' WHERE id=v_moc;
 INSERT INTO public.moc_risk_assessments(tenant_id,moc_id,method,hazard,consequence,
  likelihood_before,severity_before,likelihood_after,severity_after,controls,assessed_by)
 VALUES(v_tenant,v_moc,'MATRIX','[DEMO] Yanlış sensör okuması',
  'Örnek hat duruşu ve yanlış ayırma kararı',3,3,1,2,
  'Kurulum sonrası ölçüm doğrulaması ve operatör eğitimi',v_manager);
 UPDATE public.moc_requests SET status='TECHNICAL_REVIEW' WHERE id=v_moc;
 INSERT INTO public.moc_approvals(tenant_id,moc_id,step_order,role_code,approver_id,comment)
 VALUES(v_tenant,v_moc,1,'DEMO_MANAGER',v_manager,'[DEMO] Eğitim amaçlı örnek onay adımı')
 RETURNING id INTO v_approval;
 UPDATE public.moc_requests SET status='APPROVAL' WHERE id=v_moc;
 PERFORM public.moc_decide_approval(v_approval,'APPROVED');
 IF (SELECT status FROM public.moc_requests WHERE id=v_moc)<>'IMPLEMENTATION'
  THEN RAISE EXCEPTION 'DEMO_APPROVAL_DID_NOT_ADVANCE'; END IF;

 v_project:=public.moc_project_create_for_request(v_moc);
 UPDATE public.moc_projects SET status='ACTIVE',project_lead_id=v_manager,sponsor_id=v_editor,
  planned_start=current_date-3,planned_end=current_date+35,risk_level='NORMAL',
  budget_planned=185000,budget_actual=6500,currency='TRY' WHERE id=v_project;
 UPDATE public.moc_project_phases SET
  planned_start=current_date+(sort_order*5)-3,
  planned_end=current_date+(sort_order*5)+5,
  status=CASE WHEN sort_order=0 THEN 'DONE' WHEN sort_order=1 THEN 'IN_PROGRESS' ELSE 'OPEN' END
 WHERE project_id=v_project;
 UPDATE public.moc_project_tasks t SET
  assignee_id=CASE WHEN p.sort_order IN (1,2) THEN v_editor ELSE v_manager END,
  planned_start=current_date+(p.sort_order*5)-3,
  due_date=current_date+(p.sort_order*5)+4,
  priority=CASE WHEN p.sort_order IN (1,3) THEN 'HIGH' ELSE 'NORMAL' END,
  estimated_hours=CASE WHEN p.sort_order IN (0,5) THEN 4 ELSE 8 END
 FROM public.moc_project_phases p
 WHERE p.id=t.phase_id AND p.project_id=v_project;
 SELECT t.id INTO v_implementation FROM public.moc_project_tasks t
  JOIN public.moc_project_phases p ON p.id=t.phase_id WHERE t.project_id=v_project AND p.sort_order=0;
 SELECT t.id INTO v_doc FROM public.moc_project_tasks t
  JOIN public.moc_project_phases p ON p.id=t.phase_id WHERE t.project_id=v_project AND p.sort_order=1;
 SELECT t.id INTO v_training FROM public.moc_project_tasks t
  JOIN public.moc_project_phases p ON p.id=t.phase_id WHERE t.project_id=v_project AND p.sort_order=2;
 INSERT INTO public.moc_task_checklist_items(tenant_id,project_id,task_id,title)
 SELECT v_tenant,v_project,t.id,x.title
 FROM (VALUES
  (0,'[DEMO] Kapsam ve görev sahiplerini doğrula'),
  (1,'[DEMO] Sensör talimatı revizyonunu kaydet'),
  (2,'[DEMO] Eğitim katılımcılarını belirle'),
  (3,'[DEMO] Devreye alma öncesi saha kontrolünü yap'),
  (4,'[DEMO] İlk 30 gün ölçüm doğrulamasını yap'),
  (5,'[DEMO] Kapanış kanıtlarını gözden geçir')
 ) AS x(phase_order,title)
 JOIN public.moc_project_phases p ON p.project_id=v_project AND p.sort_order=x.phase_order
 JOIN public.moc_project_tasks t ON t.phase_id=p.id AND t.project_id=v_project;
 UPDATE public.moc_task_checklist_items SET done=true
  WHERE project_id=v_project AND task_id=v_implementation;
 UPDATE public.moc_project_tasks SET status='DONE',progress=100,completed_at=now(),actual_hours=3.5
  WHERE id=v_implementation;
 PERFORM public.moc_project_set_predecessor(v_doc,v_implementation);
 PERFORM set_config('request.jwt.claim.sub',v_editor::text,true);
 UPDATE public.moc_project_tasks SET status='IN_PROGRESS',progress=35 WHERE id=v_doc;
 UPDATE public.moc_project_tasks SET status='BLOCKED',progress=0 WHERE id=v_training;
 PERFORM set_config('request.jwt.claim.sub',v_manager::text,true);
 INSERT INTO public.moc_project_milestones(tenant_id,project_id,name,milestone_type,target_date,completed_at,completed_by)
 VALUES(v_tenant,v_project,'[DEMO] MOC onayı','APPROVAL',current_date-1,now(),v_manager),
       (v_tenant,v_project,'[DEMO] Doküman yürürlüğü','DOC_EFFECTIVE',current_date+5,NULL,NULL),
       (v_tenant,v_project,'[DEMO] Eğitim tamamlandı','TRAINING',current_date+12,NULL,NULL),
       (v_tenant,v_project,'[DEMO] PSSR serbest bırakma','PSSR',current_date+20,NULL,NULL),
       (v_tenant,v_project,'[DEMO] Etkinlik doğrulaması','EFFECTIVENESS',current_date+30,NULL,NULL);
 INSERT INTO public.moc_project_costs(tenant_id,project_id,cost_type,description,planned,actual,currency,document_ref,created_by)
 VALUES(v_tenant,v_project,'PURCHASE','[DEMO] Sensör ve montaj malzemesi',140000,0,'TRY',NULL,v_manager),
       (v_tenant,v_project,'LABOR','[DEMO] Teknik ekip işçiliği',30000,6500,'TRY',NULL,v_manager),
       (v_tenant,v_project,'EXTERNAL_SERVICE','[DEMO] Doğrulama hizmeti',15000,0,'TRY',NULL,v_manager);
 INSERT INTO public.moc_action_items(tenant_id,moc_id,title,description,phase,assignee_id,due_date)
 VALUES(v_tenant,v_moc,'[DEMO] Sensör ölçüm doğrulaması',
  'Kurgusal örnek aksiyon; ilk doğrulama sonucunu proje görevine ekleyin.',
  'IMPLEMENTATION',v_editor,current_date+10);
 SELECT jsonb_build_object('captured_at',now(),'project',jsonb_build_object(
  'name',v_title,'planned_start',current_date-3,'planned_end',current_date+35,
  'budget_planned',185000,'currency','TRY'),
  'tasks',(SELECT jsonb_agg(jsonb_build_object('id',id,'title',title,'phase_id',phase_id,
   'planned_start',planned_start,'due_date',due_date,'assignee_id',assignee_id,
   'estimated_hours',estimated_hours,'required',required) ORDER BY id)
   FROM public.moc_project_tasks WHERE project_id=v_project)) INTO v_snapshot;
 INSERT INTO public.moc_project_baselines(tenant_id,project_id,version_no,snapshot,snapshot_hash)
 VALUES(v_tenant,v_project,1,v_snapshot,encode(extensions.digest(v_snapshot::text,'sha256'),'hex'));
 RAISE NOTICE 'DEMO_READY moc_id=%, project_id=%',v_moc,v_project;
END $$;
COMMIT;
