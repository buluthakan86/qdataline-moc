-- ============================================================================
-- MOC — FAZ N (2026-09-17) — Denetimde bulunan 4 gerçek açığın kapatılması
--
-- 1) PSSR sonucu immutable değildi: `moc_pssr_checklists.result` düz UPDATE ile
--    her yönde değiştirilebiliyordu. KALICI KİLİT 2 (2026-09-05) ile eklenen
--    "NOT_RELEASED -> yeniden dene" döngüsü MEŞRU bir akış, ona dokunulmadı.
--    Ama RELEASED/CONDITIONAL bir kez verildikten sonra hiçbir yoldan
--    değiştirilemez hale getirildi — düzeltme gerekiyorsa yalnız ADMIN,
--    gerekçe girerek moc_admin_reopen_pssr() RPC'sini çağırabilir; bu olay
--    ayrıca moc_audit_log'a PSSR_REOPEN olarak düşer.
--
-- 2) Uygulama-içi onay kararının evidence_hash'i istemcide btoa() ile
--    üretiliyordu (kriptografik değil, herkes taklit edebilir). Artık
--    moc_decide_approval() RPC'si içinde sunucuda pgcrypto digest() ile
--    gerçek SHA-256 üretilip yazılıyor.
--
-- 3) Onay kararı -> sıradaki adım kontrolü -> moc_requests.status güncellemesi
--    istemciden ayrı ayrı bağımsız isteklerle yapılıyordu (decideApproval +
--    checkApprovalAuto, MOC.html). Tek bir SECURITY DEFINER RPC'ye
--    (moc_decide_approval) taşındı; plpgsql fonksiyon gövdesi tek transaction'dır.
--    Var olan iş kuralları (moc_onay_kontrol / moc_durum_kontrol trigger'ları,
--    kendi-talebini-onaylama ve mükerrer-onay engelleri) DOKUNULMADAN, aynen
--    tetiklenmeye devam eder — RPC yalnız aynı UPDATE'leri tek gövdede sıralar.
--
-- 4) Dosya yükleme iki bağımsız adımdı (storage.upload + moc_documents.insert);
--    bu SQL dosyasında DB tarafında bir şey değişmiyor, JS tarafında insert
--    başarısız olursa yüklenen storage nesnesi geri siliniyor (MOC.html).
--
-- GÜVENLİK: Idempotent (CREATE OR REPLACE / DROP...IF EXISTS + CREATE),
-- DESTRUCTIVE değil, mevcut hiçbir tabloyu/politikayı silmez.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- GÖREV 1 — PSSR sonucu kilidi
-- ----------------------------------------------------------------------------
create or replace function public.moc_pssr_kilit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Sonuç henüz hiç girilmemişse (OLD.result NULL) her şey serbest.
  if old.result is null then
    return new;
  end if;

  -- Sonuç değişmiyorsa (başka alanlar güncelleniyor) konu dışı.
  if new.result is not distinct from old.result then
    return new;
  end if;

  -- MEŞRU İSTİSNA 1: NOT_RELEASED -> NULL (KALICI KİLİT 2 döngüsü,
  -- resetPssrResult() ile PSSR->IMPLEMENTATION geçişinde otomatik yapılır).
  if old.result = 'NOT_RELEASED' and new.result is null then
    return new;
  end if;

  -- MEŞRU İSTİSNA 2: admin yeniden-açma RPC'si (moc_admin_reopen_pssr)
  -- transaction-local bayrak set eder.
  if coalesce(current_setting('moc.pssr_reopen_bypass', true), 'off') = 'on' then
    return new;
  end if;

  raise exception 'MOC_PSSR_KILITLI'
    using hint = 'PSSR sonucu zaten kayitli, degistirilemez. Duzeltme gerekiyorsa yonetici PSSR''i yeniden acmali.';
end
$$;

drop trigger if exists moc_pssr_kilit_trg on public.moc_pssr_checklists;
create trigger moc_pssr_kilit_trg
  before update on public.moc_pssr_checklists
  for each row execute function public.moc_pssr_kilit();

-- Admin-only "yeniden aç" RPC'si + audit kaydı
create or replace function public.moc_admin_reopen_pssr(p_pssr_id bigint, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.moc_pssr_checklists;
begin
  if not is_admin() then
    raise exception 'MOC_YETKI_YOK' using hint = 'Yalniz yonetici PSSR sonucunu yeniden acabilir.';
  end if;

  if p_reason is null or length(trim(p_reason)) < 5 then
    raise exception 'MOC_GEREKCE_ZORUNLU' using hint = 'Yeniden acma gerekcesi zorunlu (en az 5 karakter).';
  end if;

  select * into v_row from public.moc_pssr_checklists where id = p_pssr_id;
  if v_row.id is null then
    raise exception 'MOC_KAYIT_YOK' using hint = 'PSSR kaydi bulunamadi.';
  end if;
  if v_row.result is null then
    raise exception 'MOC_ZATEN_ACIK' using hint = 'Bu PSSR zaten sonuclanmamis.';
  end if;

  perform set_config('moc.pssr_reopen_bypass', 'on', true);

  update public.moc_pssr_checklists
     set result = null, performed_by = null, performed_at = null
   where id = p_pssr_id;

  perform set_config('moc.pssr_reopen_bypass', 'off', true);

  insert into public.moc_audit_log (tenant_id, table_name, record_id, action, changed_by, old_data, new_data)
  values (v_row.tenant_id, 'moc_pssr_checklists', v_row.id, 'PSSR_REOPEN', auth.uid(),
          to_jsonb(v_row), jsonb_build_object('reason', p_reason, 'reopened_at', now()));

  return jsonb_build_object('ok', true, 'pssr_id', p_pssr_id);
end
$$;

revoke all on function public.moc_admin_reopen_pssr(bigint, text) from public, anon;
grant execute on function public.moc_admin_reopen_pssr(bigint, text) to authenticated;

-- ----------------------------------------------------------------------------
-- GÖREV 2 + 3 — Onay kararı: sunucu-taraflı gerçek SHA-256 + tek transaction'lı RPC
-- ----------------------------------------------------------------------------
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

-- ============================================================================
-- GERİ ALMA (gerekirse, elle):
--   drop trigger if exists moc_pssr_kilit_trg on public.moc_pssr_checklists;
--   drop function if exists public.moc_pssr_kilit();
--   drop function if exists public.moc_admin_reopen_pssr(bigint, text);
--   drop function if exists public.moc_decide_approval(bigint, text);
-- ============================================================================
