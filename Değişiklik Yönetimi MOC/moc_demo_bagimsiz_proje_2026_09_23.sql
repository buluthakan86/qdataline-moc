-- Yalnız Qdataline DEMO tenant için hayalî, MOC bağlantısı olmayan proje.
-- Aynı başlık varsa ikinci kayıt açmaz. Önce COMMIT -> ROLLBACK değiştirilerek prova edilir.
BEGIN;
DO $$
DECLARE
 v_tenant uuid:='675ac400-7f2a-4f82-a5d4-a7d7fb3c11a4';
 v_manager uuid; v_editor uuid; v_project bigint; v_title text:='[DEMO] Dijital üretim izleme pilotu';
 v_plan bigint; v_design bigint; v_install bigint; v_validate bigint;
 v_snapshot jsonb;
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
 IF EXISTS(SELECT 1 FROM public.moc_projects WHERE tenant_id=v_tenant AND name=v_title) THEN
  RAISE NOTICE 'Bağımsız demo proje zaten mevcut'; RETURN;
 END IF;

 PERFORM set_config('request.jwt.claim.sub',v_manager::text,true);
 v_project:=public.moc_project_create_standalone(v_title,
  'Tamamen kurgusal örnek. Bir üretim hattında veri toplama, gösterge paneli, pilot kurulum ve sonuç değerlendirmesini izler. Gerçek tesis, müşteri veya üretim verisi içermez.',
  DATE '2026-09-01',DATE '2026-12-20');
 UPDATE public.moc_projects SET status='ACTIVE',project_lead_id=v_manager,sponsor_id=v_editor,
  risk_level='NORMAL',budget_planned=760000,currency='TRY' WHERE id=v_project;
 UPDATE public.moc_project_phases SET
  planned_start=(ARRAY[DATE '2026-09-01',DATE '2026-09-08',DATE '2026-09-19',DATE '2026-11-01',DATE '2026-12-05'])[sort_order+1],
  planned_end=(ARRAY[DATE '2026-09-07',DATE '2026-09-28',DATE '2026-11-05',DATE '2026-12-05',DATE '2026-12-20'])[sort_order+1],
  status=CASE WHEN sort_order=0 THEN 'DONE' WHEN sort_order IN (1,2) THEN 'IN_PROGRESS' ELSE 'OPEN' END
 WHERE project_id=v_project;

 INSERT INTO public.moc_project_tasks
  (tenant_id,project_id,phase_id,title,description,status,priority,assignee_id,planned_start,due_date,progress,estimated_hours,actual_hours,completed_at,created_by)
 SELECT v_tenant,v_project,p.id,x.title,x.description,x.status,x.priority,
  CASE WHEN x.owner='editor' THEN v_editor ELSE v_manager END,
  x.started,x.due,x.progress,x.estimated,x.actual,
  CASE WHEN x.status='DONE' THEN TIMESTAMPTZ '2026-09-18 10:00:00+03' ELSE NULL END,v_manager
 FROM (VALUES
  (0,'[DEMO] Kapsam ve başarı ölçütlerini onayla','Pilotun hedeflerini ve ölçüm aralığını tanımla.','DONE','NORMAL','manager',DATE '2026-09-01',DATE '2026-09-05',100,12::numeric,11::numeric),
  (0,'[DEMO] Proje ekibini ve rolleri belirle','Görev sahiplerini ve karar noktalarını kaydet.','DONE','NORMAL','manager',DATE '2026-09-03',DATE '2026-09-07',100,8::numeric,8::numeric),
  (1,'[DEMO] Veri modelini tasarla','Göstergelerin veri alanlarını eşleştir.','DONE','HIGH','editor',DATE '2026-09-08',DATE '2026-09-14',100,24::numeric,22::numeric),
  (1,'[DEMO] İş takvimini ve bağımlılıkları kesinleştir','Kurulum ve doğrulama tarihlerini netleştir.','DONE','NORMAL','manager',DATE '2026-09-10',DATE '2026-09-18',100,10::numeric,9::numeric),
  (1,'[DEMO] Teknik şartnameyi gözden geçir','Pilot istasyon ekipman listesini kontrol et.','IN_REVIEW','HIGH','editor',DATE '2026-09-15',DATE '2026-09-28',85,20::numeric,15::numeric),
  (2,'[DEMO] Gösterge panelini geliştir','Örnek verilerle üretim göstergelerini kur.','IN_PROGRESS','HIGH','editor',DATE '2026-09-19',DATE '2026-10-05',65,80::numeric,43::numeric),
  (2,'[DEMO] Veri akışını entegre et','Pilot kaynaklardan verinin düzenli aktarımını sağla.','IN_PROGRESS','HIGH','manager',DATE '2026-09-22',DATE '2026-10-20',35,96::numeric,31::numeric),
  (2,'[DEMO] Pilot istasyonu kur','Örnek donanım kurulumunu tamamla.','BLOCKED','HIGH','editor',DATE '2026-09-24',DATE '2026-10-10',20,48::numeric,12::numeric),
  (2,'[DEMO] Kullanıcı eğitimini hazırla','Kısa kullanım senaryoları oluştur.','TODO','NORMAL','editor',DATE '2026-10-15',DATE '2026-11-05',0,24::numeric,0::numeric),
  (3,'[DEMO] Canlı veriyi doğrula','Pilot ölçümleri örnek kaynakla karşılaştır.','TODO','HIGH','manager',DATE '2026-11-01',DATE '2026-11-20',0,40::numeric,0::numeric),
  (3,'[DEMO] Kullanıcı geri bildirimini topla','Kullanım sorunlarını ve iyileştirme önerilerini kaydet.','TODO','NORMAL','editor',DATE '2026-11-20',DATE '2026-12-05',0,20::numeric,0::numeric),
  (4,'[DEMO] Sonuç ve kapanış raporunu hazırla','Hedef, süre ve maliyet sapmalarını özetle.','TODO','NORMAL','manager',DATE '2026-12-05',DATE '2026-12-20',0,24::numeric,0::numeric)
 ) AS x(phase_order,title,description,status,priority,owner,started,due,progress,estimated,actual)
 JOIN public.moc_project_phases p ON p.project_id=v_project AND p.sort_order=x.phase_order;

 SELECT id INTO v_plan FROM public.moc_project_tasks WHERE project_id=v_project AND title='[DEMO] İş takvimini ve bağımlılıkları kesinleştir';
 SELECT id INTO v_design FROM public.moc_project_tasks WHERE project_id=v_project AND title='[DEMO] Gösterge panelini geliştir';
 SELECT id INTO v_install FROM public.moc_project_tasks WHERE project_id=v_project AND title='[DEMO] Pilot istasyonu kur';
 SELECT id INTO v_validate FROM public.moc_project_tasks WHERE project_id=v_project AND title='[DEMO] Canlı veriyi doğrula';
 PERFORM public.moc_project_set_predecessor(v_design,v_plan);
 PERFORM public.moc_project_set_predecessor(v_validate,v_install);

 INSERT INTO public.moc_project_milestones
  (tenant_id,project_id,name,milestone_type,target_date,completed_at,completed_by,evidence_required)
 VALUES
  (v_tenant,v_project,'[DEMO] Kapsam onayı','CUSTOM',DATE '2026-09-08',TIMESTAMPTZ '2026-09-08 10:00:00+03',v_manager,false),
  (v_tenant,v_project,'[DEMO] Tasarım gözden geçirme','CUSTOM',DATE '2026-10-10',NULL,NULL,false),
  (v_tenant,v_project,'[DEMO] Pilot devreye alma','CUSTOM',DATE '2026-11-01',NULL,NULL,false),
  (v_tenant,v_project,'[DEMO] Sonuç değerlendirme','CUSTOM',DATE '2026-12-20',NULL,NULL,false);

 INSERT INTO public.moc_project_costs
  (tenant_id,project_id,task_id,cost_type,description,planned,actual,currency,planned_on,incurred_on,created_by)
 VALUES
  (v_tenant,v_project,v_install,'PURCHASE','[DEMO] Pilot ekipman',210000,160000,'TRY',DATE '2026-09-20',DATE '2026-09-20',v_manager),
  (v_tenant,v_project,v_design,'EXTERNAL_SERVICE','[DEMO] Yazılım entegrasyonu',185000,55000,'TRY',DATE '2026-10-05',DATE '2026-09-22',v_manager),
  (v_tenant,v_project,NULL,'LABOR','[DEMO] Proje ekibi emeği',140000,42000,'TRY',DATE '2026-11-15',DATE '2026-09-23',v_manager),
  (v_tenant,v_project,NULL,'OTHER','[DEMO] Eğitim materyali',45000,0,'TRY',DATE '2026-11-05',NULL,v_manager),
  (v_tenant,v_project,v_validate,'EXTERNAL_SERVICE','[DEMO] Ölçüm doğrulama hizmeti',85000,0,'TRY',DATE '2026-11-20',NULL,v_manager),
  (v_tenant,v_project,NULL,'OTHER','[DEMO] Beklenmeyen gider payı',55000,0,'TRY',DATE '2026-12-15',NULL,v_manager);

 SELECT jsonb_build_object('captured_at',now(),'project',jsonb_build_object(
  'name',v_title,'planned_start',DATE '2026-09-01','planned_end',DATE '2026-12-20',
  'budget_planned',760000,'currency','TRY'),
  'tasks',(SELECT jsonb_agg(jsonb_build_object('id',id,'title',title,'phase_id',phase_id,
   'planned_start',planned_start,'due_date',due_date,'assignee_id',assignee_id,
   'estimated_hours',estimated_hours,'required',required) ORDER BY id)
   FROM public.moc_project_tasks WHERE project_id=v_project)) INTO v_snapshot;
 INSERT INTO public.moc_project_baselines(tenant_id,project_id,version_no,snapshot,snapshot_hash)
 VALUES(v_tenant,v_project,1,v_snapshot,encode(extensions.digest(v_snapshot::text,'sha256'),'hex'));
 RAISE NOTICE 'STANDALONE_DEMO_READY project_id=%',v_project;
END $$;
COMMIT;
