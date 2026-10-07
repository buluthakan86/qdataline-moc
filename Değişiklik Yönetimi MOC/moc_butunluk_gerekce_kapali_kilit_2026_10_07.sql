-- Proje&MOC bütünlük sertleştirmesi (07.10.2026): red/iade gerekçesi zorunlu + kapalı talebe kayıt eklenemez
-- Geri dönüş: eski moc_decide_approval(bigint,text) gövdesi sql/moc_schema_faz_n_guvenlik_sertlestirme.sql; tetikleyicileri drop et.

drop function if exists public.moc_decide_approval(bigint, text);

CREATE OR REPLACE FUNCTION public.moc_decide_approval(p_approval_id bigint, p_decision text, p_comment text DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$

declare

  v_appr public.moc_approvals;

  v_req  public.moc_requests;

  v_hash text;

  v_next text;

  v_rejected_count int;

  v_returned_count int;

  v_total_count int;

  v_approved_count int;

begin

  if p_decision not in ('APPROVED','REJECTED','RETURNED') then

    raise exception 'MOC_GECERSIZ_KARAR' using hint = 'Gecersiz karar degeri.';

  end if;



  -- 07.10.2026: red ve iade kararlarında gerekçe zorunlu (denetim izi)
  if p_decision in ('REJECTED','RETURNED') and length(trim(coalesce(p_comment,''))) < 5 then
    raise exception 'MOC_GEREKCE_GEREKLI' using hint = 'Red veya iade icin en az 5 karakterlik gerekce yazilmalidir.';
  end if;

  select * into v_appr from public.moc_approvals where id = p_approval_id;

  if v_appr.id is null then

    raise exception 'MOC_KAYIT_YOK' using hint = 'Onay adimi bulunamadi.';

  end if;

  if v_appr.decision is not null then

    raise exception 'MOC_ZATEN_KARARLI' using hint = 'Bu adim icin zaten karar verilmis.';

  end if;



  select * into v_req from public.moc_requests where id = v_appr.moc_id for update;

  if v_req.id is null then

    raise exception 'MOC_KAYIT_YOK' using hint = 'Talep bulunamadi.';

  end if;

  -- SECURITY DEFINER kullanicinin RLS'ini asar; kimlik ve sirali onay burada zorlanir.

  if auth.uid() is null

     or v_req.tenant_id is distinct from public.current_tenant_id()

     or not public.is_editor()

     or not exists(select 1 from public.modul_yetki

                   where user_id=auth.uid() and modul='moc') then

    raise exception 'MOC_YETKI_YOK';

  end if;

  if v_req.status <> 'APPROVAL' then raise exception 'MOC_GECERSIZ_GECIS'; end if;

  if v_req.initiator_id = auth.uid() then raise exception 'MOC_KENDI_ONAYI'; end if;

  if v_appr.approver_id is not null and v_appr.approver_id <> auth.uid() then

    raise exception 'MOC_YETKI_YOK';

  end if;

  if v_appr.id is distinct from (

    select a.id from public.moc_approvals a

     where a.moc_id=v_req.id and a.decision is null

     order by a.step_order,a.id limit 1

  ) then raise exception 'MOC_GECERSIZ_GECIS'; end if;



  -- Sunucu tarafinda hesaplanan gercek SHA-256 kanit ozeti — istemciden gelen

  -- deger asla kullanilmaz (eski kod istemci Base64'unu evidence_hash'e yaziyordu).

  v_hash := encode(

    digest(

      coalesce(v_req.id::text,'') || '|' || coalesce(v_appr.id::text,'') || '|' ||

      coalesce(auth.uid()::text,'') || '|' || coalesce(p_decision,'') || '|' || now()::text,

      'sha256'

    ), 'hex');



  -- Karari yaz. moc_onay_kontrol trigger'i (kendi-talebi / mukerrer-onay engeli)

  -- burada aynen calisir, dokunulmadi.

  update public.moc_approvals

     set decision = p_decision, decided_at = now(), approver_id = auth.uid(), evidence_hash = v_hash, comment = coalesce(nullif(trim(coalesce(p_comment,'')),''), comment)

   where id = p_approval_id;



  -- Siradaki durumu hesapla — MOC.html checkApprovalAuto() ile birebir ayni mantik.

  select count(*) filter (where decision = 'REJECTED'),

         count(*) filter (where decision = 'RETURNED'),

         count(*),

         count(*) filter (where decision = 'APPROVED')

    into v_rejected_count, v_returned_count, v_total_count, v_approved_count

    from public.moc_approvals where moc_id = v_req.id;



  if v_rejected_count > 0 then

    v_next := 'REJECTED';

  elsif v_returned_count > 0 then

    v_next := 'TECHNICAL_REVIEW';

  elsif v_total_count > 0 and v_approved_count = v_total_count then

    v_next := 'IMPLEMENTATION';

  else

    v_next := null;

  end if;



  if v_next = 'TECHNICAL_REVIEW' then

    -- İade edilen adımın kararı sıfırlanmazsa zincir kalıcı kilitlenir (bkz. MOC.html yorumu).

    update public.moc_approvals

       set decision = null, decided_at = null, approver_id = null

     where moc_id = v_req.id and decision = 'RETURNED';

    if v_req.status = 'APPROVAL' then

      update public.moc_requests set status = v_next, reason = case when v_next = 'REJECTED' then coalesce(nullif(trim(coalesce(reason,'')),''), nullif(trim(coalesce(p_comment,'')),'')) else reason end where id = v_req.id;

    end if;

  elsif v_next is not null and v_req.status = 'APPROVAL' then

    update public.moc_requests set status = v_next, reason = case when v_next = 'REJECTED' then coalesce(nullif(trim(coalesce(reason,'')),''), nullif(trim(coalesce(p_comment,'')),'')) else reason end where id = v_req.id;

  end if;



  return jsonb_build_object('ok', true, 'approval_id', p_approval_id, 'evidence_hash', v_hash, 'next_status', v_next);

end

$function$
;

revoke execute on function public.moc_decide_approval(bigint, text, text) from public, anon;
grant execute on function public.moc_decide_approval(bigint, text, text) to authenticated;

CREATE OR REPLACE FUNCTION public.moc_durum_kontrol()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_gecerli text[];
  v_onay_sayisi int;
  v_acik_onay int;
  v_eksik_doc int;
  v_eksik_egitim int;
begin
  if tg_op = 'INSERT' then
    if new.status is distinct from 'DRAFT' then
      raise exception 'MOC_GECERSIZ_GECIS'
        using hint = 'Yeni talep yalnizca taslak olarak acilabilir.';
    end if;
    return new;
  end if;

  if old.status is not distinct from new.status then
    return new;
  end if;

  if auth.uid() is not null and not is_editor() then
    raise exception 'MOC_YETKI_YOK'
      using hint = 'Durum degistirmek icin yetkiniz yok.';
  end if;

  v_gecerli := case old.status
    when 'DRAFT'            then array['SCREENING','CANCELLED']
    when 'SCREENING'        then array['RISK_ASSESSMENT','CLOSED','REJECTED']
    when 'RISK_ASSESSMENT'  then array['TECHNICAL_REVIEW']
    when 'TECHNICAL_REVIEW' then array['APPROVAL','RISK_ASSESSMENT']
    when 'APPROVAL'         then array['IMPLEMENTATION','REJECTED','TECHNICAL_REVIEW']
    when 'IMPLEMENTATION'   then array['DOC_UPDATE']
    when 'DOC_UPDATE'       then array['TRAINING']
    when 'TRAINING'         then array['PSSR','STARTUP']
    when 'PSSR'             then array['STARTUP','IMPLEMENTATION']
    when 'STARTUP'          then array['CLOSED']
    else array[]::text[] end;

  if not (new.status = any(v_gecerli)) then
    raise exception 'MOC_GECERSIZ_GECIS'
      using hint = format('%s durumundan %s durumuna gecilemez.', old.status, new.status);
  end if;

  -- 07.10.2026: REJECTED'a her geçişte gerekçe şart. Onay zincirinden gelen redde, reddeden adımın yorumu gerekçe olarak yazılır.
  if new.status = 'REJECTED' then
    if coalesce(trim(new.reason),'') = '' then
      new.reason := (select a.comment from public.moc_approvals a
                      where a.moc_id = new.id and a.decision = 'REJECTED' and coalesce(trim(a.comment),'') <> ''
                      order by a.decided_at desc nulls last limit 1);
    end if;
    if coalesce(trim(new.reason),'') = '' then
      raise exception 'MOC_GEREKCE_GEREKLI' using hint = 'Reddedilen talep icin gerekce yazilmalidir.';
    end if;
  end if;

  if new.status = 'APPROVAL' then
    select count(*) into v_onay_sayisi
      from public.moc_approvals where moc_id = new.id;
    if v_onay_sayisi = 0 then
      raise exception 'MOC_GECERSIZ_GECIS'
        using hint = 'Onay adimi tanimlanmadan onaya gecilemez.';
    end if;
  end if;

  if new.status = 'IMPLEMENTATION' and old.status = 'APPROVAL' then
    select count(*) into v_acik_onay
      from public.moc_approvals
     where moc_id = new.id and decision is distinct from 'APPROVED';
    if v_acik_onay > 0 then
      raise exception 'MOC_GECERSIZ_GECIS'
        using hint = 'Tum onay adimlari tamamlanmadan devreye alinamaz.';
    end if;
  end if;

  -- Faz K (1): DOC_UPDATE -> TRAINING, etkilenen dokümanların hepsi Yürürlükte olmalı.
  if new.status = 'TRAINING' and old.status = 'DOC_UPDATE' then
    select count(*) into v_eksik_doc
      from public.moc_documents d
      left join public.ggd_sablonlar s on s.id::text = d.doc_ref
     where d.moc_id = new.id and d.doc_kind = 'AFFECTED_DOC'
       and not (
         s.id is not null
         and s.versiyon_no > coalesce(nullif(d.old_version,'')::int, 0)
         and s.durum = 'Yürürlükte'
       );
    if v_eksik_doc > 0 then
      raise exception 'MOC_GECERSIZ_GECIS'
        using hint = 'Etkilenen dokumanlarin tamami yururluge girmeden egitime gecilemez.';
    end if;
  end if;

  -- Faz L: TRAINING -> PSSR/STARTUP. Linksiz kayıtlarda acknowledged=true yeterli
  -- (eskisi gibi); Eğitim Platformu'na linkli kayıtlarda CANLI status='completed' şart.
  if new.status in ('PSSR','STARTUP') and old.status = 'TRAINING' then
    select count(*) into v_eksik_egitim
      from public.moc_trainings tr
      left join egitim.enrollment e on e.id = tr.egitim_enrollment_id
     where tr.moc_id = new.id
       and not (
         (tr.egitim_enrollment_id is null and tr.acknowledged is true)
         or (tr.egitim_enrollment_id is not null and e.status = 'completed')
       );
    if v_eksik_egitim > 0 then
      raise exception 'MOC_GECERSIZ_GECIS'
        using hint = 'Atanan egitimlerin tamami tamamlanmadan bir sonraki asamaya gecilemez.';
    end if;
  end if;

  return new;
end
$function$
;


-- Kapalı / reddedilmiş / iptal talebe risk veya aksiyon eklenemez, değiştirilemez, silinemez (servis rolü hariç)
create or replace function public.moc_kapali_talep_kilidi() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_moc bigint; v_st text;
begin
  if auth.uid() is null then return coalesce(new, old); end if;
  v_moc := coalesce(new.moc_id, old.moc_id);
  select status into v_st from public.moc_requests where id = v_moc;
  if v_st in ('CLOSED','REJECTED','CANCELLED') then
    raise exception 'MOC_KAPALI_TALEP' using hint = 'Kapanmis, reddedilmis veya iptal edilmis talebe kayit eklenemez/degistirilemez.';
  end if;
  return coalesce(new, old);
end $$;
revoke execute on function public.moc_kapali_talep_kilidi() from public, anon, authenticated;
drop trigger if exists moc_action_items_kapali_kilit_trg on public.moc_action_items;
create trigger moc_action_items_kapali_kilit_trg before insert or update or delete on public.moc_action_items for each row execute function public.moc_kapali_talep_kilidi();
drop trigger if exists moc_risk_assessments_kapali_kilit_trg on public.moc_risk_assessments;
create trigger moc_risk_assessments_kapali_kilit_trg before insert or update or delete on public.moc_risk_assessments for each row execute function public.moc_kapali_talep_kilidi();
