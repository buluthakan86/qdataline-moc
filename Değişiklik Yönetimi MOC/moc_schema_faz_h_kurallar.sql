-- FAZ H (2026-09-05) — İŞ KURALLARINI VERİTABANINA İNDİR
--
-- NEDEN: Denetimde çıkan en ağır bulgu. 17 MOC tablosunun tamamında tek bir RLS politikası
-- vardı ve o da yalnız firma ayrımı yapıyordu (`tenant_id = current_tenant_id()`). Rol,
-- durum geçişi, onay sırası ve "kendi talebini onaylayamama" kuralının veritabanında hiçbir
-- karşılığı yoktu. Sonuç: yalnız görüntüleme yetkisi olan bir kullanıcı, arayüzde hiçbir
-- düğme görmese bile doğrudan istekle bir değişikliği CLOSED yapabiliyor; talep sahibi kendi
-- talebinin bütün onay adımlarını tek istekte onaylayabiliyordu.
--
-- Bu modülün varlık sebebi denetlenebilir onay ve görev ayrılığı kanıtı üretmek. O kanıt
-- arayüzün dışından geçersiz kılınabiliyorsa modülün değeri yoktur.
--
-- TASARIM KARARLARI
-- 1) Politikalar CHECK değil TRIGGER + RLS karışımı: yazma yetkisi RLS'te rol bazında
--    daraltılır, akış kuralları (durum geçişi, onay sırası, çift onay) trigger'da denetlenir.
--    Trigger tercih edildi çünkü kural "eski satır → yeni satır" karşılaştırması istiyor.
-- 2) Kurallar YALNIZ GEÇİŞTE işler; bu tarihten önceki kayıtlar düzenlenebilir kalır
--    (platformdaki yerleşik desen — bkz. Gıda ve Q-Kalite modülleri).
-- 3) Rol kaynağı ortak `profiles.role` (ADMIN/EDITOR/MEMBER/VIEWER) + `is_admin()`/`is_editor()`
--    yardımcıları; MOC kendi rol tablosunu icat etmez.
--
-- ÖN KONTROL (uygulamadan önce çalıştır; satır dönerse önce veri düzeltilmeli):
--   select id, moc_no, status from public.moc_requests
--    where status = 'APPROVAL'
--      and not exists (select 1 from public.moc_approvals a where a.moc_id = moc_requests.id);
--   select moc_id, count(*) from public.moc_pssr_checklists
--    where is_template = false group by 1 having count(*) > 1;

-- ---------------------------------------------------------------------------
-- (A) KALICI KİLİT 3'ün kesin engeli: talep başına tek güvenlik incelemesi checklist'i
-- ---------------------------------------------------------------------------
create unique index if not exists moc_pssr_checklists_moc_uniq
  on public.moc_pssr_checklists (moc_id)
  where is_template = false;

-- ---------------------------------------------------------------------------
-- (B) Onay zinciri kuralları: kendi talebini onaylama + aynı kişinin ikinci kararı
-- ---------------------------------------------------------------------------
create or replace function public.moc_onay_kontrol()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sahip uuid;
  v_onceki int;
begin
  -- Yalnız karar VERİLDİĞİ anda denetle; adım eklemek/düzenlemek serbest.
  if new.decision is null
     or (tg_op = 'UPDATE' and old.decision is not distinct from new.decision) then
    return new;
  end if;

  select initiator_id into v_sahip from public.moc_requests where id = new.moc_id;

  -- 1) Kaydı açan kişi kendi talebini onaylayamaz.
  if new.approver_id is not null and new.approver_id = v_sahip then
    raise exception 'MOC_KENDI_ONAYI'
      using hint = 'Kendi actiginiz talebi onaylayamazsiniz.';
  end if;

  -- 2) Görevler ayrılığı: aynı kişi zincirde ikinci bir adımda karar veremez.
  --    (Denetimde bulunan açık: üç kademeli onay tek imzaya indirgenebiliyordu.)
  if new.approver_id is not null then
    select count(*) into v_onceki
      from public.moc_approvals
     where moc_id = new.moc_id
       and id <> new.id
       and approver_id = new.approver_id
       and decision is not null;
    if v_onceki > 0 then
      raise exception 'MOC_MUKERRER_ONAY'
        using hint = 'Bu zincirde daha once karar verdiniz.';
    end if;
  end if;

  return new;
end
$$;

drop trigger if exists moc_approvals_kural_trg on public.moc_approvals;
create trigger moc_approvals_kural_trg
  before insert or update on public.moc_approvals
  for each row execute function public.moc_onay_kontrol();

-- ---------------------------------------------------------------------------
-- (C) Durum geçişi kuralları: yalnız tanımlı geçişler, yalnız yetkili roller
-- ---------------------------------------------------------------------------
create or replace function public.moc_durum_kontrol()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_gecerli text[];
  v_onay_sayisi int;
  v_acik_onay int;
begin
  if tg_op = 'INSERT' then
    -- Yeni kayıt yalnız DRAFT olarak açılabilir; doğrudan CLOSED kayıt uydurulamaz.
    if new.status is distinct from 'DRAFT' then
      raise exception 'MOC_GECERSIZ_GECIS'
        using hint = 'Yeni talep yalnizca taslak olarak acilabilir.';
    end if;
    return new;
  end if;

  if old.status is not distinct from new.status then
    return new;   -- durum değişmiyorsa bu kuralın konusu değil
  end if;

  -- Durum değiştirmek yazma yetkisi ister (VIEWER/MEMBER değiştiremez).
  -- NOT: kontrol YALNIZ gerçek bir oturum varken uygulanır. `auth.uid()` boşsa istek bir
  -- tarayıcıdan gelmiyordur (bakım betiği, zamanlanmış iş, geçiş SQL'i); orada zaten RLS
  -- devre dışıdır ve bu kontrolü uygulamak yalnız yönetim işlerini kilitler — testte tam
  -- bu oldu. Tarayıcıdan gelen her isteğin `auth.uid()`'si dolu olduğu için kural,
  -- korumak istediği yolda aynen yürürlüktedir.
  if auth.uid() is not null and not is_editor() then
    raise exception 'MOC_YETKI_YOK'
      using hint = 'Durum degistirmek icin yetkiniz yok.';
  end if;

  -- Tanımlı geçiş haritası — MOC.html'deki TRANSITIONS ile birebir aynı.
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

  -- KALICI KİLİT 1'in veritabanı tarafı: onay adımı tanımlanmadan onaya geçilemez.
  if new.status = 'APPROVAL' then
    select count(*) into v_onay_sayisi
      from public.moc_approvals where moc_id = new.id;
    if v_onay_sayisi = 0 then
      raise exception 'MOC_GECERSIZ_GECIS'
        using hint = 'Onay adimi tanimlanmadan onaya gecilemez.';
    end if;
  end if;

  -- Devreye alma, onay zinciri gerçekten tamamlanmadan başlayamaz.
  if new.status = 'IMPLEMENTATION' and old.status = 'APPROVAL' then
    select count(*) into v_acik_onay
      from public.moc_approvals
     where moc_id = new.id and decision is distinct from 'APPROVED';
    if v_acik_onay > 0 then
      raise exception 'MOC_GECERSIZ_GECIS'
        using hint = 'Tum onay adimlari tamamlanmadan devreye alinamaz.';
    end if;
  end if;

  return new;
end
$$;

drop trigger if exists moc_requests_durum_trg on public.moc_requests;
create trigger moc_requests_durum_trg
  before insert or update on public.moc_requests
  for each row execute function public.moc_durum_kontrol();

-- ---------------------------------------------------------------------------
-- (D) RLS: yazma yetkisini role bağla
-- ---------------------------------------------------------------------------
-- Mevcut tek politika ALL komutları kapsıyordu; okuma firma içinde açık kalır,
-- yazma ise EDITOR/ADMIN'e daralır. Silme yalnız ADMIN'de.
do $$
declare tbl text;
begin
  foreach tbl in array array[
    'moc_requests','moc_approvals','moc_risk_assessments','moc_action_items',
    'moc_pssr_checklists','moc_temporary_tracking','moc_etki_checklist_yanitlari']
  loop
    execute format('drop policy if exists %I on public.%I', 'tenant_isolation_'||tbl, tbl);
    execute format('drop policy if exists %I on public.%I', tbl||'_select', tbl);
    execute format('drop policy if exists %I on public.%I', tbl||'_insert', tbl);
    execute format('drop policy if exists %I on public.%I', tbl||'_update', tbl);
    execute format('drop policy if exists %I on public.%I', tbl||'_delete', tbl);

    execute format('create policy %I on public.%I for select using (tenant_id = current_tenant_id())',
                   tbl||'_select', tbl);
    execute format('create policy %I on public.%I for insert with check (tenant_id = current_tenant_id() and is_editor())',
                   tbl||'_insert', tbl);
    execute format('create policy %I on public.%I for update using (tenant_id = current_tenant_id() and is_editor()) with check (tenant_id = current_tenant_id())',
                   tbl||'_update', tbl);
    execute format('create policy %I on public.%I for delete using (tenant_id = current_tenant_id() and is_admin())',
                   tbl||'_delete', tbl);
  end loop;
end $$;

-- GERİ ALMA (gerekirse):
--   drop trigger if exists moc_requests_durum_trg on public.moc_requests;
--   drop trigger if exists moc_approvals_kural_trg on public.moc_approvals;
--   drop function if exists public.moc_durum_kontrol();
--   drop function if exists public.moc_onay_kontrol();
--   drop index if exists public.moc_pssr_checklists_moc_uniq;
--   ve her tablo için tek politikaya dönüş:
--     create policy tenant_isolation_<tbl> on public.<tbl>
--       using (tenant_id = current_tenant_id()) with check (tenant_id = current_tenant_id());
