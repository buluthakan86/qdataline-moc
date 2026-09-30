-- 30.09.2026 E2E P0: e-posta onayı talebi ilerletmiyordu
CREATE OR REPLACE FUNCTION public.moc_onay_uygula(p_record_id text, p_expected_status text, p_recipient_email text, p_decision text, p_ip text, p_ua text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare v_appr public.moc_approvals; v_moc public.moc_requests; v_next text; v_rej int; v_tot int; v_onay int;
begin
  select a.* into v_appr from public.moc_approvals a where a.id = p_record_id::bigint;
  if v_appr.id is null then return jsonb_build_object('ok', false, 'reason', 'not_found'); end if;
  select r.* into v_moc from public.moc_requests r where r.id = v_appr.moc_id;
  if v_moc.status is distinct from p_expected_status then
    return jsonb_build_object('ok', false, 'reason', 'state_changed'); end if;
  if v_appr.decision is not null then
    return jsonb_build_object('ok', false, 'reason', 'already_decided'); end if;

  update public.moc_approvals
     set decision = p_decision, decided_at = now(),
         comment = coalesce(comment,'') ||
           case when p_decision='APPROVED' then '[E-posta linki ile onaylandı]'
                else '[E-posta linki ile reddedildi]' end
   where id = v_appr.id;

  insert into public.moc_audit_log
    (tenant_id, table_name, record_id, action, changed_by, old_data, new_data)
  values
    (v_appr.tenant_id, 'moc_approvals', v_appr.id,
     case when p_decision='APPROVED' then 'EMAIL_APPROVE' else 'EMAIL_REJECT' end,
     null, to_jsonb(v_appr),
     jsonb_build_object('decision', p_decision, 'ip', p_ip, 'user_agent', p_ua, 'via', 'email_link', 'at', now()));

  -- 30.09.2026 E2E P0: e-posta ile verilen onay talebi ilerletmiyordu; uygulama içi moc_decide_approval ile aynı geçiş mantığı
  select count(*) filter (where decision = 'REJECTED'), count(*), count(*) filter (where decision = 'APPROVED')
    into v_rej, v_tot, v_onay from public.moc_approvals where moc_id = v_moc.id;
  if v_moc.status = 'APPROVAL' then
    if v_rej > 0 then v_next := 'REJECTED';
    elsif v_tot > 0 and v_onay = v_tot then v_next := 'IMPLEMENTATION';
    else v_next := null; end if;
    if v_next is not null then update public.moc_requests set status = v_next where id = v_moc.id; end if;
  end if;

  return jsonb_build_object('ok', true, 'moc_no', v_moc.moc_no, 'decision', p_decision, 'next_status', v_next);
end $function$
;
