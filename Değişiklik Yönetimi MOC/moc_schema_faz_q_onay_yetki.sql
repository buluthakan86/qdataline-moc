-- Onay RPC yetki siniri: tenant, rol, atama ve sirali adim denetimi.
BEGIN;
create or replace function public.moc_decide_approval(p_approval_id bigint, p_decision text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
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
     set decision = p_decision, decided_at = now(), approver_id = auth.uid(), evidence_hash = v_hash
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
      update public.moc_requests set status = v_next where id = v_req.id;
    end if;
  elsif v_next is not null and v_req.status = 'APPROVAL' then
    update public.moc_requests set status = v_next where id = v_req.id;
  end if;

  return jsonb_build_object('ok', true, 'approval_id', p_approval_id, 'evidence_hash', v_hash, 'next_status', v_next);
end
$$;

revoke all on function public.moc_decide_approval(bigint, text) from public, anon;
grant execute on function public.moc_decide_approval(bigint, text) to authenticated;
COMMIT;
