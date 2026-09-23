-- Yalnız staging: onay yetkisi ve sıralama testi; tüm kayıtlar geri alınır.
BEGIN;
INSERT INTO auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) VALUES
 ('cccccccc-cccc-4ccc-8ccc-ccccccccccc1','00000000-0000-0000-0000-000000000000','authenticated','authenticated','moc-q-initiator@example.invalid','',now(),now(),now()),
 ('cccccccc-cccc-4ccc-8ccc-ccccccccccc2','00000000-0000-0000-0000-000000000000','authenticated','authenticated','moc-q-approver@example.invalid','',now(),now(),now()),
 ('cccccccc-cccc-4ccc-8ccc-ccccccccccc3','00000000-0000-0000-0000-000000000000','authenticated','authenticated','moc-q-second@example.invalid','',now(),now(),now()),
 ('cccccccc-cccc-4ccc-8ccc-ccccccccccc4','00000000-0000-0000-0000-000000000000','authenticated','authenticated','moc-q-outsider@example.invalid','',now(),now(),now());
INSERT INTO public.tenants(id,name) VALUES
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','MOC Q test tenant'),
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','MOC Q other tenant');
INSERT INTO public.profiles(id,tenant_id,full_name,role) VALUES
 ('cccccccc-cccc-4ccc-8ccc-ccccccccccc1','dddddddd-dddd-4ddd-8ddd-dddddddddddd','Initiator','EDITOR'),
 ('cccccccc-cccc-4ccc-8ccc-ccccccccccc2','dddddddd-dddd-4ddd-8ddd-dddddddddddd','Approver','ADMIN'),
 ('cccccccc-cccc-4ccc-8ccc-ccccccccccc3','dddddddd-dddd-4ddd-8ddd-dddddddddddd','Second','EDITOR'),
 ('cccccccc-cccc-4ccc-8ccc-ccccccccccc4','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','Outsider','ADMIN');
INSERT INTO public.modul_yetki(user_id,modul) VALUES
 ('cccccccc-cccc-4ccc-8ccc-ccccccccccc1','moc'),('cccccccc-cccc-4ccc-8ccc-ccccccccccc2','moc'),
 ('cccccccc-cccc-4ccc-8ccc-ccccccccccc3','moc'),('cccccccc-cccc-4ccc-8ccc-ccccccccccc4','moc');
SELECT set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-ccccccccccc2',true);
INSERT INTO public.moc_change_categories(id,tenant_id,code,name_tr,name_en) OVERRIDING SYSTEM VALUE
 VALUES(9000000002,'dddddddd-dddd-4ddd-8ddd-dddddddddddd','QTEST','Test','Test');
INSERT INTO public.moc_types(id,tenant_id,code,name_tr,name_en) OVERRIDING SYSTEM VALUE
 VALUES(9000000002,'dddddddd-dddd-4ddd-8ddd-dddddddddddd','QTEST','Test','Test');
INSERT INTO public.moc_requests(tenant_id,moc_no,title,category_id,type_id,initiator_id)
 VALUES('dddddddd-dddd-4ddd-8ddd-dddddddddddd','Q-STAGE-MOC','Q test',9000000002,9000000002,'cccccccc-cccc-4ccc-8ccc-ccccccccccc1');
UPDATE public.moc_requests SET status='SCREENING' WHERE moc_no='Q-STAGE-MOC';
UPDATE public.moc_requests SET status='RISK_ASSESSMENT' WHERE moc_no='Q-STAGE-MOC';
UPDATE public.moc_requests SET status='TECHNICAL_REVIEW' WHERE moc_no='Q-STAGE-MOC';
INSERT INTO public.moc_approvals(tenant_id,moc_id,step_order,role_code,approver_id)
 SELECT tenant_id,id,1,'MANAGER','cccccccc-cccc-4ccc-8ccc-ccccccccccc2' FROM public.moc_requests WHERE moc_no='Q-STAGE-MOC';
INSERT INTO public.moc_approvals(tenant_id,moc_id,step_order,role_code,approver_id)
 SELECT tenant_id,id,2,'QUALITY','cccccccc-cccc-4ccc-8ccc-ccccccccccc3' FROM public.moc_requests WHERE moc_no='Q-STAGE-MOC';
UPDATE public.moc_requests SET status='APPROVAL' WHERE moc_no='Q-STAGE-MOC';
DO $$ DECLARE first_id bigint; second_id bigint; v_moc bigint; BEGIN
 SELECT id INTO v_moc FROM public.moc_requests WHERE moc_no='Q-STAGE-MOC';
 SELECT id INTO first_id FROM public.moc_approvals WHERE moc_id=v_moc AND step_order=1;
 SELECT id INTO second_id FROM public.moc_approvals WHERE moc_id=v_moc AND step_order=2;
 PERFORM set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-ccccccccccc3',true);
 BEGIN PERFORM public.moc_decide_approval(second_id,'APPROVED'); RAISE EXCEPTION 'TEST FAILED: out-of-order approval';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'MOC_GECERSIZ_GECIS' THEN RAISE; END IF; END;
 PERFORM set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-ccccccccccc1',true);
 BEGIN PERFORM public.moc_decide_approval(first_id,'APPROVED'); RAISE EXCEPTION 'TEST FAILED: self approval';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'MOC_KENDI_ONAYI' THEN RAISE; END IF; END;
 PERFORM set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-ccccccccccc4',true);
 BEGIN PERFORM public.moc_decide_approval(first_id,'APPROVED'); RAISE EXCEPTION 'TEST FAILED: cross-tenant approval';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'MOC_YETKI_YOK' THEN RAISE; END IF; END;
 PERFORM set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-ccccccccccc2',true);
 PERFORM public.moc_decide_approval(first_id,'APPROVED');
 IF (SELECT status FROM public.moc_requests WHERE id=v_moc)<>'APPROVAL' THEN RAISE EXCEPTION 'TEST FAILED: first step advanced early'; END IF;
 PERFORM set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-ccccccccccc3',true);
 PERFORM public.moc_decide_approval(second_id,'APPROVED');
 IF (SELECT status FROM public.moc_requests WHERE id=v_moc)<>'IMPLEMENTATION' THEN RAISE EXCEPTION 'TEST FAILED: approval chain did not advance'; END IF;
 IF EXISTS(SELECT 1 FROM public.moc_approvals WHERE moc_id=v_moc AND length(evidence_hash)<>64)
  THEN RAISE EXCEPTION 'TEST FAILED: evidence hash'; END IF;
END $$;
SELECT 'PASS: tenant, owner, order and approval chain' AS result;
ROLLBACK;
