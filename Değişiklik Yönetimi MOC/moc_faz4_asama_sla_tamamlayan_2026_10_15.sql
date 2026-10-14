-- 15.10.2026 — MOC Faz 4: aşama giriş zamanı, tenant SLA ayarı, tamamlayan kişi, günlük özette SLA bölümü
-- Geri alma: drop trigger moc_stage_entered_trg on moc_requests; drop trigger moc_completed_by_trg on moc_action_items / moc_project_tasks;
--            drop function moc_stage_entered(), moc_completed_by_stamp(); drop table moc_ayarlar; (sütunlar zararsız); moc_daily_notify için eski tanım git geçmişinde.

-- 1) Aşama giriş zamanı
alter table public.moc_requests add column if not exists stage_entered_at timestamptz;
create or replace function public.moc_stage_entered()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.stage_entered_at := coalesce(new.stage_entered_at, now());
  elsif new.status is distinct from old.status then
    new.stage_entered_at := now();
  end if;
  return new;
end $$;
drop trigger if exists moc_stage_entered_trg on public.moc_requests;
create trigger moc_stage_entered_trg before insert or update of status on public.moc_requests
  for each row execute function public.moc_stage_entered();

-- açık talepler için geriye dönük doldurma (denetim izi/updated_at gürültüsü yaratmasın diye tetikleyiciler kısa süre kapatılır)
alter table public.moc_requests disable trigger trg_audit_moc_requests;
alter table public.moc_requests disable trigger trg_moc_requests_updated;
update public.moc_requests r set stage_entered_at = coalesce(
    (select max(g.created_at) from public.moc_audit_log g
      where g.table_name = 'moc_requests' and g.record_id = r.id
        and g.new_data->>'status' = r.status and coalesce(g.old_data->>'status','') <> r.status),
    r.created_at)
 where r.stage_entered_at is null and r.status not in ('CLOSED','REJECTED','CANCELLED') and r.deleted_at is null;
alter table public.moc_requests enable trigger trg_audit_moc_requests;
alter table public.moc_requests enable trigger trg_moc_requests_updated;

-- 2) Tenant bazlı aşama bekleme süresi (SLA)
create table if not exists public.moc_ayarlar (
  tenant_id      uuid primary key default public.current_tenant_id() references public.tenants(id),
  stage_sla_days integer not null default 14 check (stage_sla_days between 1 and 365),
  updated_by     uuid,
  updated_at     timestamptz not null default now()
);
alter table public.moc_ayarlar enable row level security;
drop policy if exists "moc_ayarlar read" on public.moc_ayarlar;
create policy "moc_ayarlar read" on public.moc_ayarlar for select to authenticated
  using (tenant_id = current_tenant_id() and has_modul('moc'));
drop policy if exists "moc_ayarlar insert" on public.moc_ayarlar;
create policy "moc_ayarlar insert" on public.moc_ayarlar for insert to authenticated
  with check (tenant_id = current_tenant_id() and has_modul('moc') and is_admin());
drop policy if exists "moc_ayarlar update" on public.moc_ayarlar;
create policy "moc_ayarlar update" on public.moc_ayarlar for update to authenticated
  using (tenant_id = current_tenant_id() and has_modul('moc') and is_admin())
  with check (tenant_id = current_tenant_id());
revoke all on public.moc_ayarlar from anon;
grant select, insert, update on public.moc_ayarlar to authenticated;

-- 3) Tamamlayan kişi
alter table public.moc_action_items add column if not exists completed_by uuid;
alter table public.moc_project_tasks add column if not exists completed_by uuid;
create or replace function public.moc_completed_by_stamp()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'DONE' and old.status is distinct from 'DONE' then
    new.completed_by := coalesce(auth.uid(), new.completed_by);
    new.completed_at := coalesce(new.completed_at, now());
  elsif new.status is distinct from 'DONE' and old.status = 'DONE' then
    new.completed_by := null;
  end if;
  return new;
end $$;
drop trigger if exists moc_completed_by_trg on public.moc_action_items;
create trigger moc_completed_by_trg before update of status on public.moc_action_items
  for each row execute function public.moc_completed_by_stamp();
drop trigger if exists moc_completed_by_trg on public.moc_project_tasks;
create trigger moc_completed_by_trg before update of status on public.moc_project_tasks
  for each row execute function public.moc_completed_by_stamp();
