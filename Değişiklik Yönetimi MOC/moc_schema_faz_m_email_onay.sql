-- FAZ M (2026-09-12) — E-POSTA İLE TEK-TIKLA ONAY/RED (PİLOT: MOC)
--
-- AMAÇ: MOC onay adımı bekleyen bir onaylayıcıya, giriş yapmadan Onayla/Reddet
-- kararı verebileceği güvenli, tek kullanımlık bir link e-posta ile gönderme.
-- Bu tablo/fonksiyonlar PLATFORM-GENEL paylaşımlı şemada yaşar (qdl_ ön eki),
-- ileride diğer 10 modül de aynı altyapıyı kullanacak — MOC'a özel değildir.
--
-- ÖNEMLİ — UYGULAMADAN ÖNCE:
--   Bu dosya, live Supabase (bbltvuxxtacrpgrqnfoh) üzerinde Management API
--   token'ı bulunamadığı için OTOMATİK ÇALIŞTIRILMADI. SQL Editor'den elle
--   uygulanmalı, sonra aşağıdaki "DOĞRULAMA" sorguları ile teyit edilmelidir.
--
-- Gerçek canlı şema doğrulaması (moc_requests/moc_approvals kolonları) bu
-- .sql dosyalarından (moc_schema_faz_a.sql, moc_schema_faz_h_kurallar.sql)
-- okunarak yapıldı; ancak live DB'ye bağlanıp information_schema ile TEYİT
-- EDİLEMEDİ (token yok). Uygulamadan hemen önce mutlaka:
--   select column_name, data_type from information_schema.columns
--    where table_schema='public' and table_name in ('moc_requests','moc_approvals','moc_audit_log');
-- ile bu dosyadaki varsayımları (id BIGINT, status TEXT, decision TEXT vb.) teyit edin.

-- ---------------------------------------------------------------------------
-- 1) Paylaşımlı token tablosu
-- ---------------------------------------------------------------------------
create table if not exists public.qdl_approval_tokens (
  id                uuid primary key default gen_random_uuid(),
  token_hash        text not null unique,          -- sha256(raw_token) hex
  action            text not null default 'moc_change_decision',
  record_table      text not null,                 -- ör. 'moc_approvals'
  record_id         text not null,                 -- ör. moc_approvals.id::text
  recipient_email   text not null,
  expected_status   text not null,                 -- gönderim anındaki moc_requests.status
  status            text not null default 'pending'
                    check (status in ('pending','used','expired','invalidated')),
  created_at        timestamptz not null default now(),
  expires_at        timestamptz not null default (now() + interval '72 hours'),
  used_at           timestamptz,
  used_from_ip      text,
  used_user_agent   text,
  used_decision     text
);
create index if not exists idx_qdl_approval_tokens_hash on public.qdl_approval_tokens (token_hash);
create index if not exists idx_qdl_approval_tokens_record on public.qdl_approval_tokens (record_table, record_id);

alter table public.qdl_approval_tokens enable row level security;
-- Kasıtlı olarak HİÇBİR select/insert/update policy'si yok: tüm erişim
-- SECURITY DEFINER fonksiyonlar üzerinden. anon/authenticated'a raw tablo
-- erişimi verilmiyor.
revoke all on public.qdl_approval_tokens from public, anon, authenticated;

-- Basit IP bazlı hız sınırlama sayaç tablosu
create table if not exists public.qdl_approval_rate_limit (
  ip          text primary key,
  window_start timestamptz not null default now(),
  attempts    int not null default 0
);
revoke all on public.qdl_approval_rate_limit from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2) Token üretimi (sunucu tarafından / trigger'dan çağrılır)
-- ---------------------------------------------------------------------------
create or replace function public.qdl_create_approval_token(
  p_record_table    text,
  p_record_id       text,
  p_recipient_email text,
  p_expected_status text,
  p_action          text default 'moc_change_decision',
  p_ttl_hours       int  default 72
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_raw   text;
  v_hash  text;
begin
  -- 32 byte CSPRNG, base64url (pad'siz)
  v_raw := translate(encode(gen_random_bytes(32), 'base64'), '+/=', '-_ ');
  v_raw := replace(v_raw, ' ', '');
  v_hash := encode(digest(v_raw, 'sha256'), 'hex');

  insert into public.qdl_approval_tokens
    (token_hash, action, record_table, record_id, recipient_email, expected_status, expires_at)
  values
    (v_hash, coalesce(p_action,'moc_change_decision'), p_record_table, p_record_id,
     p_recipient_email, p_expected_status, now() + make_interval(hours => coalesce(p_ttl_hours,72)));

  return v_raw;  -- yalnız burada, tek sefer döner; kalıcı olarak SAKLANMAZ
end
$$;
revoke all on function public.qdl_create_approval_token(text,text,text,text,text,int) from public, anon, authenticated;
-- Yalnız diğer SECURITY DEFINER fonksiyonlar / trigger'lar (definer olarak) çağırır.

-- ---------------------------------------------------------------------------
-- 3) Salt-okunur önizleme (tüketmeden) — PostREST RPC ile anon çağırabilir
-- ---------------------------------------------------------------------------
create or replace function public.qdl_approval_token_preview(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hash text;
  v_row  public.qdl_approval_tokens;
  v_moc  record;
begin
  v_hash := encode(digest(coalesce(p_token,''), 'sha256'), 'hex');
  select * into v_row from public.qdl_approval_tokens where token_hash = v_hash;

  if v_row.id is null then
    return jsonb_build_object('ok', false, 'reason', 'invalid');
  end if;
  if v_row.status <> 'pending' then
    return jsonb_build_object('ok', false, 'reason', 'used');
  end if;
  if now() >= v_row.expires_at then
    return jsonb_build_object('ok', false, 'reason', 'expired');
  end if;

  if v_row.record_table = 'moc_approvals' then
    select r.moc_no, r.title, r.status into v_moc
      from public.moc_approvals a
      join public.moc_requests r on r.id = a.moc_id
     where a.id = v_row.record_id::bigint;
  end if;

  return jsonb_build_object(
    'ok', true,
    'moc_no', v_moc.moc_no,
    'title', v_moc.title,
    'current_status', v_moc.status,
    'expected_status', v_row.expected_status,
    'still_relevant', (v_moc.status is not distinct from v_row.expected_status)
  );
end
$$;
revoke all on function public.qdl_approval_token_preview(text) from public;
grant execute on function public.qdl_approval_token_preview(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4) Tüketim: atomik tek kullanımlık onay/red
-- ---------------------------------------------------------------------------
create or replace function public.qdl_consume_approval_token(
  p_token    text,
  p_decision text,   -- 'APPROVED' | 'REJECTED'
  p_ip       text,
  p_ua       text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hash text;
  v_row  public.qdl_approval_tokens;
  v_appr public.moc_approvals;
  v_moc  public.moc_requests;
  v_rl   public.qdl_approval_rate_limit;
begin
  -- 4.0) Basit hız sınırlama: IP başına saatte 20 deneme
  if p_ip is not null then
    select * into v_rl from public.qdl_approval_rate_limit where ip = p_ip for update;
    if v_rl.ip is null then
      insert into public.qdl_approval_rate_limit(ip, window_start, attempts) values (p_ip, now(), 1);
    elsif v_rl.window_start < now() - interval '1 hour' then
      update public.qdl_approval_rate_limit set window_start = now(), attempts = 1 where ip = p_ip;
    else
      if v_rl.attempts >= 20 then
        return jsonb_build_object('ok', false, 'reason', 'rate_limited');
      end if;
      update public.qdl_approval_rate_limit set attempts = attempts + 1 where ip = p_ip;
    end if;
  end if;

  if p_decision not in ('APPROVED','REJECTED') then
    return jsonb_build_object('ok', false, 'reason', 'invalid');
  end if;

  v_hash := encode(digest(coalesce(p_token,''), 'sha256'), 'hex');

  -- 4.1) Atomik tüketim: yalnızca pending + süresi geçmemişse 'used' yap
  update public.qdl_approval_tokens
     set status = 'used', used_at = now(), used_from_ip = p_ip,
         used_user_agent = p_ua, used_decision = p_decision
   where token_hash = v_hash
     and status = 'pending'
     and now() < expires_at
  returning * into v_row;

  if v_row.id is null then
    -- Ayırt et: bulunamadı / zaten kullanılmış / süresi geçmiş
    select * into v_row from public.qdl_approval_tokens where token_hash = v_hash;
    if v_row.id is null then
      return jsonb_build_object('ok', false, 'reason', 'invalid');
    elsif v_row.status = 'used' then
      return jsonb_build_object('ok', false, 'reason', 'already_used');
    elsif now() >= v_row.expires_at then
      return jsonb_build_object('ok', false, 'reason', 'expired');
    else
      return jsonb_build_object('ok', false, 'reason', 'invalid');
    end if;
  end if;

  -- 4.2) Kayıt hâlâ token'daki beklenen durumda mı? (token yine de 'used' kalır)
  if v_row.record_table = 'moc_approvals' then
    select a.* into v_appr from public.moc_approvals a where a.id = v_row.record_id::bigint;
    if v_appr.id is null then
      return jsonb_build_object('ok', false, 'reason', 'not_found');
    end if;
    select r.* into v_moc from public.moc_requests r where r.id = v_appr.moc_id;
    if v_moc.status is distinct from v_row.expected_status then
      return jsonb_build_object('ok', false, 'reason', 'state_changed');
    end if;
    if v_appr.decision is not null then
      return jsonb_build_object('ok', false, 'reason', 'already_decided');
    end if;

    -- 4.3) Mevcut durum makinesini/trigger'ları tetikleyerek gerçek geçişi uygula
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
       null,
       to_jsonb(v_appr),
       jsonb_build_object('decision', p_decision, 'ip', p_ip, 'user_agent', p_ua, 'via', 'email_link', 'at', now()));

    return jsonb_build_object('ok', true, 'moc_no', v_moc.moc_no, 'decision', p_decision);
  end if;

  return jsonb_build_object('ok', false, 'reason', 'unsupported_record');
end
$$;
revoke all on function public.qdl_consume_approval_token(text,text,text,text) from public;
grant execute on function public.qdl_consume_approval_token(text,text,text,text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5) Entegrasyon noktası: bir moc_approvals adımı "bekleyen" hale geldiğinde
--    (insert, decision IS NULL, approver_id atanmış) otomatik e-posta linki
--    gönder. moc_requests.status = 'APPROVAL' olduğu an tetiklenir.
-- ---------------------------------------------------------------------------
create or replace function public.moc_onay_eposta_gonder()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
  v_moc   public.moc_requests;
  v_token text;
  v_link  text;
begin
  if new.decision is not null or new.approver_id is null then
    return new;
  end if;
  -- Aynı adım için tekrar tetiklenmesin (UPDATE'lerde approver_id değişmediyse atla)
  if tg_op = 'UPDATE' and old.approver_id is not distinct from new.approver_id
     and old.decision is not distinct from new.decision then
    return new;
  end if;

  select * into v_moc from public.moc_requests where id = new.moc_id;
  if v_moc.id is null or v_moc.status <> 'APPROVAL' then
    return new;
  end if;

  select email into v_email from auth.users where id = new.approver_id;
  if v_email is null then
    return new;
  end if;

  v_token := public.qdl_create_approval_token(
    'moc_approvals', new.id::text, v_email, v_moc.status, 'moc_change_decision', 72
  );
  v_link := 'https://moc.qdataline.com/moc-onay.html?token=' || v_token;
  -- NOT: Gerçek yayın domaini için Cloudflare Pages MOC alan adını doğrulayın;
  -- farklıysa yalnız bu satırdaki base URL güncellenmeli.

  perform public.qdl_send_email(
    v_email,
    'MOC Onay Bekliyor: ' || coalesce(v_moc.moc_no,''),
    '<p>' || coalesce(v_moc.moc_no,'') || ' — ' || coalesce(v_moc.title,'') || ' başlıklı değişiklik talebi onayınızı bekliyor.</p>' ||
    '<p><a href="' || v_link || '">Talebi görüntüle ve karar ver</a></p>' ||
    '<p style="color:#888;font-size:12px">Bu link 72 saat geçerlidir ve yalnız bir kez kullanılabilir.</p>'
  );

  return new;
end
$$;

drop trigger if exists moc_onay_eposta_trg on public.moc_approvals;
create trigger moc_onay_eposta_trg
  after insert or update on public.moc_approvals
  for each row execute function public.moc_onay_eposta_gonder();

-- ---------------------------------------------------------------------------
-- DOĞRULAMA SORGULARI (uygulamadan sonra çalıştırın)
-- ---------------------------------------------------------------------------
-- select table_name from information_schema.tables where table_schema='public' and table_name like 'qdl_approval%';
-- select proname from pg_proc where pronamespace='public'::regnamespace and proname like 'qdl_%approval%';
-- select routine_name from information_schema.routines where routine_schema='public' and routine_name = 'moc_onay_eposta_gonder';

-- ---------------------------------------------------------------------------
-- TEST SIRASI (öneri, öneri kullanıcı e-postası buluthakan86@gmail.com)
-- ---------------------------------------------------------------------------
-- 1) select public.qdl_create_approval_token('moc_approvals','<pending approval id>','buluthakan86@gmail.com','APPROVAL');
--    -> dönen ham token'ı SADECE test sırasında geçici olarak kullanın, kaydetmeyin.
-- 2) select public.qdl_approval_token_preview('<ham token>');  -- ok:true beklenir
-- 3) select public.qdl_consume_approval_token('<ham token>','APPROVED','127.0.0.1','test-agent');
--    -> ok:true beklenir, moc_approvals.decision='APPROVED' olmalı
-- 4) Aynı token ile tekrar: select public.qdl_consume_approval_token('<ham token>','APPROVED','127.0.0.1','test-agent');
--    -> {"ok":false,"reason":"already_used"} beklenir
-- 5) select * from net._http_response order by created desc limit 3; -- Resend 200 teyidi
