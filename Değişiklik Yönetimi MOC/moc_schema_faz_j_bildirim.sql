-- FAZ J (2026-09-05) — OTOMATİK BİLDİRİM VE HATIRLATMA
--
-- NEDEN: Denetimde modülün "en gerçek darboğazı" olarak çıktı. Sistem kimseye haber vermiyor;
-- onay bekleyen kişi ekrana girmedikçe sırasının geldiğini bilmiyor. Rakiplerin (Enablon,
-- VisiumKMS, Sphera) tam olarak "manuel onay kovalamacasını bitirir" diye pazarladığı nokta bu.
-- Üstelik bildirim zili de yok, yani gecikme uyarısı hiçbir kanaldan gitmiyordu.
--
-- ALTYAPI TEKRARLANMIYOR: platformun ortak Resend altyapısı zaten kurulu
-- (`public.qdl_send_email(to, subject, html)` → Vault'taki `resend_api_key`). Burada YALNIZ
-- MOC'a özel özet fonksiyonu + pg_cron işi var; Tedarikçi (`qty_daily_notify`) ve Q-Kalite
-- (`kalite_daily_notify`) ile birebir aynı desen.
--
-- TASARIM KARARLARI
-- 1) TEK günlük özet — kayıt başına ayrı mail değil. Kimse 40 mail okumaz.
-- 2) Açık iş yoksa mail ATILMAZ. Her gün gelen "her şey yolunda" maili birkaç günde
--    görmezden gelinir ve gerçek uyarıyı da beraberinde götürür.
-- 3) Mail KİŞİYE ÖZEL: herkese aynı liste değil, o kişinin gerçekten yapabileceği işler.
--    Onay adımı için "zincirde sıradaki adımı kararlaştırma yetkisi olanlar" hesaplanır —
--    arayüzdeki `activeApprovalStep` + `canDecideApproval` mantığının SQL karşılığı, talep
--    sahibi hariç (kendi talebini onaylayamaz, Faz H kuralı).
-- 4) `moc_notifications` tablosuna da satır yazılır (kanal IN_APP) — ileride bir zil
--    eklenirse veri hazır olsun; mail gönderimi ayrıca EMAIL satırı olarak işaretlenir.
-- 5) Mail içeriğinde MOC numarası ve tarih var, iç detay (tablo/kolon adı) YOK.

create or replace function public.moc_daily_notify()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  k            record;
  bekleyen     text;
  geciken      text;
  suresi_dolan text;
  n_bekleyen int; n_geciken int; n_suresi int;
  govde text;
  konu  text;
begin
  -- MOC yetkisi olan her kullanıcı için ayrı ayrı hesapla.
  for k in
    select p.id, p.tenant_id, p.full_name, u.email
      from public.profiles p
      join public.modul_yetki m on m.user_id = p.id and m.modul = 'moc'
      join auth.users u on u.id = p.id
     where coalesce(p.is_active, true)
       and p.role in ('ADMIN','EDITOR')      -- VIEWER karar veremez, hatırlatma da almaz
       and coalesce(u.email,'') <> ''
  loop
    -- ── 1) Bu kişinin kararını bekleyen onay adımları ──
    -- Aktif adım: sırası en küçük olan, kararı verilmemiş ve kendinden öncekilerin tamamı
    -- onaylanmış adım. Talep sahibi kendi talebini onaylayamaz.
    select count(*), string_agg(
             '<li><b>' || coalesce(r.moc_no,'—') || '</b> — ' || left(coalesce(r.title,''),110) ||
             ' · ' || coalesce(a.role_code,'—') || ' adımı</li>', '' order by r.created_at)
      into n_bekleyen, bekleyen
      from public.moc_approvals a
      join public.moc_requests r on r.id = a.moc_id
     where r.tenant_id = k.tenant_id
       and r.status = 'APPROVAL'
       and r.deleted_at is null
       and a.decision is null
       and r.initiator_id is distinct from k.id
       and (a.approver_id is null or a.approver_id = k.id)
       -- kendinden önceki tüm adımlar onaylanmış olmalı (sıralı zincir)
       and not exists (
             select 1 from public.moc_approvals a2
              where a2.moc_id = a.moc_id
                and a2.step_order < a.step_order
                and a2.decision is distinct from 'APPROVED')
       -- bu kişi zincirde daha önce karar vermişse ikinci kez karar veremez (görev ayrılığı)
       and not exists (
             select 1 from public.moc_approvals a3
              where a3.moc_id = a.moc_id
                and a3.approver_id = k.id
                and a3.decision is not null);

    -- ── 2) Termini geçmiş, kapanmamış aksiyonlar ──
    select count(*), string_agg(
             '<li><b>' || coalesce(r.moc_no,'—') || '</b> — ' || left(coalesce(ai.title, ai.description,''),110) ||
             ' · termin: ' || to_char(ai.due_date,'DD.MM.YYYY') || '</li>', '' order by ai.due_date)
      into n_geciken, geciken
      from public.moc_action_items ai
      join public.moc_requests r on r.id = ai.moc_id
     where ai.tenant_id = k.tenant_id
       and r.deleted_at is null
       and ai.status not in ('DONE','CANCELLED')
       and ai.due_date is not null
       and ai.due_date < current_date;

    -- ── 3) Süresi dolan / dolmak üzere olan geçici değişiklikler ──
    -- Geri dönüş kaydı girilmişse (restored_at) artık hatırlatma gitmez.
    select count(*), string_agg(
             '<li><b>' || coalesce(r.moc_no,'—') || '</b> — ' || left(coalesce(r.title,''),110) ||
             ' · bitiş: ' || to_char(coalesce(tt.expires_at, r.planned_end),'DD.MM.YYYY') || '</li>',
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

    if coalesce(n_bekleyen,0) + coalesce(n_geciken,0) + coalesce(n_suresi,0) = 0 then
      continue;   -- bu kişi için yapacak iş yok, mail atma
    end if;

    govde := '<div style="font-family:Arial,Helvetica,sans-serif;font-size:14px;color:#1b2620">'
          || '<p>Merhaba ' || coalesce(nullif(k.full_name,''),'') || ',</p>'
          || '<p>Değişiklik yönetiminde bugün ilgilenmeniz gereken maddeler:</p>';

    if coalesce(n_bekleyen,0) > 0 then
      govde := govde || '<h3>Kararınızı bekleyen onaylar (' || n_bekleyen || ')</h3><ul>' || bekleyen || '</ul>';
    end if;
    if coalesce(n_geciken,0) > 0 then
      govde := govde || '<h3>Termini geçmiş aksiyonlar (' || n_geciken || ')</h3><ul>' || geciken || '</ul>';
    end if;
    if coalesce(n_suresi,0) > 0 then
      govde := govde || '<h3>Süresi dolan geçici değişiklikler (' || n_suresi || ')</h3><ul>' || suresi_dolan || '</ul>'
            || '<p style="color:#8a5a06">Geçici bir değişikliğin süresi dolduğunda ya eski duruma '
            || 'dönülmeli ya da gerekçesiyle uzatılmalıdır.</p>';
    end if;

    govde := govde
          || '<p style="margin-top:18px"><a href="https://moc.qdataline.com">Değişiklik yönetimini aç</a></p>'
          || '<p style="color:#7c8c81;font-size:12px">Bu e-posta Qdataline tarafından otomatik '
          || 'gönderilmiştir.</p></div>';

    konu := 'Değişiklik yönetimi — günlük özet ' || to_char(current_date,'DD.MM.YYYY');

    perform public.qdl_send_email(k.email, konu, govde);

    insert into public.moc_notifications (tenant_id, user_id, moc_id, channel, subject, body, is_read)
    values (k.tenant_id, k.id, null, 'EMAIL', konu, govde, false);
  end loop;
end
$$;

-- ---------------------------------------------------------------------------
-- Günlük zamanlama — 06:20 UTC (~09:20 TR).
-- Tedarikçi 06:00, Q-Kalite 06:10; üç mailin aynı dakikaya düşmemesi için 20. dakika.
-- ---------------------------------------------------------------------------
select cron.unschedule('moc_daily_notify')
 where exists (select 1 from cron.job where jobname = 'moc_daily_notify');

select cron.schedule('moc_daily_notify', '20 6 * * *',
                     $$select public.moc_daily_notify();$$);

-- ELLE TEST:  select public.moc_daily_notify();
-- SONUÇ:      select status_code, content from net._http_response order by created desc limit 5;
-- GERİ ALMA:  select cron.unschedule('moc_daily_notify');
--             drop function if exists public.moc_daily_notify();
