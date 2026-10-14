CREATE OR REPLACE FUNCTION public.moc_daily_notify()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  k            record;
  bekleyen     text;
  geciken      text;
  suresi_dolan text;
  n_bekleyen int; n_geciken int; n_suresi int; n_asama int; asama text;
  govde text;
  konu  text;
begin
  -- MOC yetkisi olan her kullanÄ±cÄ± iÃ§in ayrÄ± ayrÄ± hesapla.
  for k in
    select p.id, p.tenant_id, p.full_name, u.email
      from public.profiles p
      join public.modul_yetki m on m.user_id = p.id and m.modul = 'moc'
      join auth.users u on u.id = p.id
     where coalesce(p.is_active, true)
       and p.role in ('ADMIN','EDITOR')      -- VIEWER karar veremez, hatÄ±rlatma da almaz
       and coalesce(u.email,'') <> ''
  loop
    -- â”€â”€ 1) Bu kiÅŸinin kararÄ±nÄ± bekleyen onay adÄ±mlarÄ± â”€â”€
    -- Aktif adÄ±m: sÄ±rasÄ± en kÃ¼Ã§Ã¼k olan, kararÄ± verilmemiÅŸ ve kendinden Ã¶ncekilerin tamamÄ±
    -- onaylanmÄ±ÅŸ adÄ±m. Talep sahibi kendi talebini onaylayamaz.
    select count(*), string_agg(
             '<li><b>' || coalesce(r.moc_no,'â€”') || '</b> â€” ' || left(coalesce(r.title,''),110) ||
             ' Â· ' || coalesce(a.role_code,'â€”') || ' adÄ±mÄ±</li>', '' order by r.created_at)
      into n_bekleyen, bekleyen
      from public.moc_approvals a
      join public.moc_requests r on r.id = a.moc_id
     where r.tenant_id = k.tenant_id
       and r.status = 'APPROVAL'
       and r.deleted_at is null
       and a.decision is null
       and r.initiator_id is distinct from k.id
       and (a.approver_id is null or a.approver_id = k.id)
       -- kendinden Ã¶nceki tÃ¼m adÄ±mlar onaylanmÄ±ÅŸ olmalÄ± (sÄ±ralÄ± zincir)
       and not exists (
             select 1 from public.moc_approvals a2
              where a2.moc_id = a.moc_id
                and a2.step_order < a.step_order
                and a2.decision is distinct from 'APPROVED')
       -- bu kiÅŸi zincirde daha Ã¶nce karar vermiÅŸse ikinci kez karar veremez (gÃ¶rev ayrÄ±lÄ±ÄŸÄ±)
       and not exists (
             select 1 from public.moc_approvals a3
              where a3.moc_id = a.moc_id
                and a3.approver_id = k.id
                and a3.decision is not null);

    -- â”€â”€ 2) Termini geÃ§miÅŸ, kapanmamÄ±ÅŸ aksiyonlar â”€â”€
    select count(*), string_agg(
             '<li><b>' || coalesce(r.moc_no,'â€”') || '</b> â€” ' || left(coalesce(ai.title, ai.description,''),110) ||
             ' Â· termin: ' || to_char(ai.due_date,'DD.MM.YYYY') || '</li>', '' order by ai.due_date)
      into n_geciken, geciken
      from public.moc_action_items ai
      join public.moc_requests r on r.id = ai.moc_id
     where ai.tenant_id = k.tenant_id
       and r.deleted_at is null
       and ai.status not in ('DONE','CANCELLED')
       and ai.due_date is not null
       and ai.due_date < current_date;

    -- â”€â”€ 3) SÃ¼resi dolan / dolmak Ã¼zere olan geÃ§ici deÄŸiÅŸiklikler â”€â”€
    -- Geri dÃ¶nÃ¼ÅŸ kaydÄ± girilmiÅŸse (restored_at) artÄ±k hatÄ±rlatma gitmez.
    select count(*), string_agg(
             '<li><b>' || coalesce(r.moc_no,'â€”') || '</b> â€” ' || left(coalesce(r.title,''),110) ||
             ' Â· bitiÅŸ: ' || to_char(coalesce(tt.expires_at, r.planned_end),'DD.MM.YYYY') || '</li>',
             '' order by coalesce(tt.expires_at, r.planned_end))
      into n_suresi, suresi_dolan
      from public.moc_requests r
      left join public.moc_temporary_tracking tt on tt.moc_id = r.id
     where r.tenant_id = k.tenant_id
       and r.deleted_at is null
       and r.status not in ('CLOSED','REJECTED','CANCELLED')
       and tt.restored_at is null
       and coalesce(tt.expires_at, r.planned_end) is not null
       and coalesce(tt.expires_at, r.planned_end) <= current_date + 7;

    -- ── 4) Aşamada bekleme süresi (SLA) aşılan değişiklikler — bu kişi koordinatörse ──
    select count(*), string_agg(
             '<li><b>' || coalesce(s.moc_no,'—') || '</b> — ' || left(coalesce(s.title,''),110) ||
             ' · ' || s.etiket || ' aşamasında ' || s.gun || ' gündür</li>', '' order by s.gun desc)
      into n_asama, asama
      from (
        select r.moc_no, r.title,
               floor(extract(epoch from (now() - coalesce(r.stage_entered_at, r.updated_at))) / 86400)::int as gun,
               case r.status when 'SCREENING' then 'Ön Tarama' when 'RISK_ASSESSMENT' then 'Risk Değerlendirme'
                 when 'TECHNICAL_REVIEW' then 'Teknik İnceleme' when 'APPROVAL' then 'Onay' when 'IMPLEMENTATION' then 'Uygulama'
                 when 'DOC_UPDATE' then 'Doküman Güncelleme' when 'TRAINING' then 'Eğitim' when 'PSSR' then 'PSSR'
                 when 'STARTUP' then 'Devreye Alma' else r.status end as etiket
          from public.moc_requests r
         where r.tenant_id = k.tenant_id
           and r.deleted_at is null
           and r.coordinator_id = k.id
           and r.status not in ('DRAFT','CLOSED','REJECTED','CANCELLED')
           and coalesce(r.stage_entered_at, r.updated_at) <
               now() - make_interval(days => coalesce((select a.stage_sla_days from public.moc_ayarlar a where a.tenant_id = r.tenant_id), 14))
      ) s;

    if coalesce(n_bekleyen,0) + coalesce(n_geciken,0) + coalesce(n_suresi,0) + coalesce(n_asama,0) = 0 then
      continue;   -- bu kiÅŸi iÃ§in yapacak iÅŸ yok, mail atma
    end if;

    govde := '<div style="font-family:Arial,Helvetica,sans-serif;font-size:14px;color:#1b2620">'
          || '<p>Merhaba ' || coalesce(nullif(k.full_name,''),'') || ',</p>'
          || '<p>DeÄŸiÅŸiklik yÃ¶netiminde bugÃ¼n ilgilenmeniz gereken maddeler:</p>';

    if coalesce(n_bekleyen,0) > 0 then
      govde := govde || '<h3>KararÄ±nÄ±zÄ± bekleyen onaylar (' || n_bekleyen || ')</h3><ul>' || bekleyen || '</ul>';
    end if;
    if coalesce(n_geciken,0) > 0 then
      govde := govde || '<h3>Termini geÃ§miÅŸ aksiyonlar (' || n_geciken || ')</h3><ul>' || geciken || '</ul>';
    end if;
    if coalesce(n_suresi,0) > 0 then
      govde := govde || '<h3>SÃ¼resi dolan geÃ§ici deÄŸiÅŸiklikler (' || n_suresi || ')</h3><ul>' || suresi_dolan || '</ul>'
            || '<p style="color:#8a5a06">GeÃ§ici bir deÄŸiÅŸikliÄŸin sÃ¼resi dolduÄŸunda ya eski duruma '
            || 'dÃ¶nÃ¼lmeli ya da gerekÃ§esiyle uzatÄ±lmalÄ±dÄ±r.</p>';
    end if;

    if coalesce(n_asama,0) > 0 then
      govde := govde || '<h3>Aşamada uzun süredir bekleyen değişiklikler (' || n_asama || ')</h3><ul>' || asama || '</ul>';
    end if;

    govde := govde
          || '<p style="margin-top:18px"><a href="https://moc.qdataline.com">DeÄŸiÅŸiklik yÃ¶netimini aÃ§</a></p>'
          || '<p style="color:#7c8c81;font-size:12px">Bu e-posta Qdataline tarafÄ±ndan otomatik '
          || 'gÃ¶nderilmiÅŸtir.</p></div>';

    konu := 'DeÄŸiÅŸiklik yÃ¶netimi â€” gÃ¼nlÃ¼k Ã¶zet ' || to_char(current_date,'DD.MM.YYYY');

    perform public.qdl_send_email(k.email, konu, govde);

    insert into public.moc_notifications (tenant_id, user_id, moc_id, channel, subject, body, is_read)
    values (k.tenant_id, k.id, null, 'EMAIL', konu, govde, false);
  end loop;
end
$function$
;
