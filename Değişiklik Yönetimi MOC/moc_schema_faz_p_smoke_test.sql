-- Test ortamında çalışır; tüm veri ve trigger değişiklikleri ROLLBACK ile geri alınır.
BEGIN;
INSERT INTO auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','00000000-0000-0000-0000-000000000000','authenticated','authenticated','moc-stage-admin@example.invalid','',now(),now(),now()),
       ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2','00000000-0000-0000-0000-000000000000','authenticated','authenticated','moc-stage-editor@example.invalid','',now(),now(),now()),
       ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3','00000000-0000-0000-0000-000000000000','authenticated','authenticated','moc-stage-other@example.invalid','',now(),now(),now());
INSERT INTO public.tenants(id,name) VALUES ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','MOC test tenant');
INSERT INTO public.profiles(id,tenant_id,full_name,role) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Admin','ADMIN'),
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Owner','EDITOR'),
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Other','EDITOR');
INSERT INTO public.modul_yetki(user_id,modul) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','moc'),('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2','moc'),
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3','moc');
SELECT set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',true);
INSERT INTO public.moc_change_categories(id,tenant_id,code,name_tr,name_en) OVERRIDING SYSTEM VALUE
 VALUES (9000000001,'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','STAGE','Test','Test');
INSERT INTO public.moc_types(id,tenant_id,code,name_tr,name_en) OVERRIDING SYSTEM VALUE
 VALUES (9000000001,'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','STAGE','Test','Test');
INSERT INTO public.moc_requests(tenant_id,moc_no,title,category_id,type_id,initiator_id)
 VALUES ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','STAGE-MOC','Stage project',9000000001,9000000001,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1');
ALTER TABLE public.moc_requests DISABLE TRIGGER moc_requests_durum_trg;
UPDATE public.moc_requests SET status='STARTUP' WHERE tenant_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
ALTER TABLE public.moc_requests ENABLE TRIGGER moc_requests_durum_trg;
INSERT INTO public.moc_projects(tenant_id,moc_id,name,created_by)
 SELECT tenant_id,id,'Stage project','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
 FROM public.moc_requests WHERE tenant_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
INSERT INTO public.moc_project_tasks(tenant_id,project_id,title,assignee_id,required,evidence_required,created_by)
 SELECT tenant_id,id,'Stage task','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',true,true,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
 FROM public.moc_projects WHERE tenant_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
INSERT INTO public.moc_task_checklist_items(tenant_id,project_id,task_id,title)
 SELECT tenant_id,project_id,id,'Stage check' FROM public.moc_project_tasks
 WHERE tenant_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
SELECT set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',true);
UPDATE public.moc_project_tasks SET status='IN_PROGRESS' WHERE tenant_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
DO $$ BEGIN
 BEGIN UPDATE public.moc_project_tasks SET title='Unauthorized edit' WHERE tenant_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  RAISE EXCEPTION 'TEST FAILED: assignee changed task scope';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'MOC_GOREV_YETKI_YOK' THEN RAISE; END IF; END;
END $$;
SELECT set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3',true);
DO $$ BEGIN
 BEGIN UPDATE public.moc_project_tasks SET status='BLOCKED' WHERE tenant_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  RAISE EXCEPTION 'TEST FAILED: unrelated editor changed task';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'MOC_GOREV_YETKI_YOK' THEN RAISE; END IF; END;
END $$;
SELECT set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',true);
DO $$ DECLARE v_task bigint; v_moc bigint; BEGIN
 SELECT id INTO v_task FROM public.moc_project_tasks WHERE tenant_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
 SELECT id INTO v_moc FROM public.moc_requests WHERE tenant_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
 BEGIN UPDATE public.moc_project_tasks SET status='DONE' WHERE id=v_task;
  RAISE EXCEPTION 'TEST FAILED: unchecked task completed';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM <> 'MOC_KONTROL_LISTESI_EKSIK' THEN RAISE; END IF;
 END;
 BEGIN UPDATE public.moc_requests SET status='CLOSED' WHERE id=v_moc;
  RAISE EXCEPTION 'TEST FAILED: open task closed MOC';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM <> 'MOC_ZORUNLU_GOREV_ACIK' THEN RAISE; END IF;
 END;
END $$;
UPDATE public.moc_task_checklist_items SET done=true WHERE tenant_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
DO $$ DECLARE v_task bigint; BEGIN
 SELECT id INTO v_task FROM public.moc_project_tasks WHERE tenant_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
 BEGIN UPDATE public.moc_project_tasks SET status='DONE' WHERE id=v_task;
  RAISE EXCEPTION 'TEST FAILED: missing evidence completed task';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM <> 'MOC_GOREV_KANITI_EKSIK' THEN RAISE; END IF;
 END;
END $$;
DO $$ DECLARE v_task bigint; v_moc bigint; v_key text; BEGIN
 SELECT id INTO v_task FROM public.moc_project_tasks WHERE tenant_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
 SELECT id INTO v_moc FROM public.moc_requests WHERE tenant_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
 v_key:='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb/'||v_moc||'/stage-evidence.pdf';
 INSERT INTO storage.objects(bucket_id,name) VALUES('moc-belgeler',v_key);
 PERFORM set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',true);
 PERFORM public.moc_project_add_task_evidence(v_task,'Stage evidence',v_key,'application/pdf',1024);
 UPDATE public.moc_project_tasks SET status='DONE',progress=100 WHERE id=v_task;
 PERFORM set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',true);
 UPDATE public.moc_requests SET status='CLOSED' WHERE id=v_moc;
 IF NOT EXISTS(SELECT 1 FROM public.moc_projects WHERE moc_id=v_moc AND status='COMPLETED')
  THEN RAISE EXCEPTION 'TEST FAILED: project not completed on MOC closure'; END IF;
 BEGIN UPDATE public.moc_project_tasks SET title='Post-closure edit' WHERE id=v_task;
  RAISE EXCEPTION 'TEST FAILED: closed task changed';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'MOC_KAPALI_PROJE_DEGISTIRILEMEZ' THEN RAISE; END IF; END;
 BEGIN DELETE FROM public.moc_project_tasks WHERE id=v_task;
  RAISE EXCEPTION 'TEST FAILED: closed task deleted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'MOC_KAPALI_PROJE_DEGISTIRILEMEZ' THEN RAISE; END IF; END;
END $$;
SELECT 'PASS: owner permissions, checklist, upload, completion and closure' AS result;
ROLLBACK;
