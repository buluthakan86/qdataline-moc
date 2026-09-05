-- FAZ I (2026-09-05) — EK DOSYA DEPOLAMA + BİLDİRİM ALTYAPISI + EKSİK RLS
--
-- Denetimde çıkan "şemada var, uygulamada hiç kullanılmıyor" tablolarının önünü açar:
-- `moc_documents` (ek dosya), `moc_notifications` (bildirim), `moc_temporary_tracking`
-- (geçici değişikliğin geri dönüşü/uzatması). Tabloların kendisi Faz A'da kurulmuştu;
-- burada eksik olan depolama kovası, depolama politikaları ve daraltılmamış RLS tamamlanıyor.
--
-- TASARIM KARARLARI
-- 1) Kova adı `moc-belgeler`, PUBLIC DEĞİL. Diğer modüllerdeki (`qty-belgeler`,
--    `ggd-fotograflar`, `isg-belgeler`) desenle birebir aynı; yeni bir yöntem icat edilmedi.
-- 2) Dosya yolu HER ZAMAN `<tenant_id>/<moc_id>/<dosya>` ile başlar. Politikalar yolun ilk
--    klasörünü firma kimliğiyle karşılaştırır — böylece bir firmanın dosyası başka firmaya
--    asla görünmez, uygulama kodu hata yapsa bile.
-- 3) `has_modul('moc')` şartı eklendi: MOC yetkisi olmayan bir kullanıcı, aynı firmada olsa
--    bile bu kovaya erişemez. (Denetimde `modul_yetki`nin yalnız arayüzde kontrol edildiği,
--    veri katmanında karşılığı olmadığı bulunmuştu — bu, o boşluğun depolama tarafı.)
-- 4) Yazma EDITOR, silme ADMIN — Faz H'de tablolar için konan kuralla tutarlı.

-- ---------------------------------------------------------------------------
-- (A) Depolama kovası
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
select 'moc-belgeler', 'moc-belgeler', false
where not exists (select 1 from storage.buckets where id = 'moc-belgeler');

drop policy if exists "moc belgeler read"   on storage.objects;
drop policy if exists "moc belgeler insert" on storage.objects;
drop policy if exists "moc belgeler update" on storage.objects;
drop policy if exists "moc belgeler delete" on storage.objects;

create policy "moc belgeler read" on storage.objects for select using (
  bucket_id = 'moc-belgeler'
  and has_modul('moc')
  and (storage.foldername(name))[1] = (current_tenant_id())::text
);

create policy "moc belgeler insert" on storage.objects for insert with check (
  bucket_id = 'moc-belgeler'
  and has_modul('moc') and is_editor()
  and (storage.foldername(name))[1] = (current_tenant_id())::text
);

create policy "moc belgeler update" on storage.objects for update using (
  bucket_id = 'moc-belgeler'
  and has_modul('moc') and is_editor()
  and (storage.foldername(name))[1] = (current_tenant_id())::text
);

create policy "moc belgeler delete" on storage.objects for delete using (
  bucket_id = 'moc-belgeler'
  and has_modul('moc') and is_admin()
  and (storage.foldername(name))[1] = (current_tenant_id())::text
);

-- ---------------------------------------------------------------------------
-- (B) moc_documents ve moc_notifications: tek "ALL" politikası daraltılır
-- ---------------------------------------------------------------------------
-- İkisinde de yalnız firma ayrımı yapan tek bir ALL politikası vardı (Faz H'de bu iki tablo
-- kapsam dışı kalmıştı). Aynı desen uygulanır: okuma firma içinde, yazma EDITOR, silme ADMIN.
do $$
declare tbl text; pol text;
begin
  foreach tbl in array array['moc_documents','moc_notifications'] loop
    for pol in select policyname from pg_policies
                where schemaname='public' and tablename=tbl loop
      execute format('drop policy %I on public.%I', pol, tbl);
    end loop;

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

-- Bildirimin okundu işaretini kişinin KENDİSİ yapabilmeli (editör olmasa da).
drop policy if exists moc_notifications_kendi_update on public.moc_notifications;
create policy moc_notifications_kendi_update on public.moc_notifications
  for update using (tenant_id = current_tenant_id() and user_id = auth.uid())
  with check (tenant_id = current_tenant_id() and user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- (C) Geçici değişiklik: uzatma ve geri dönüş için eksik alan
-- ---------------------------------------------------------------------------
-- `restored_at` ve `extension_*` kolonları Faz A'da açılmış ama kim/neden bilgisi yok.
-- Geri dönüşün denetim değeri "ne zaman"dan çok "kim ve neye dönüldü"dedir.
alter table public.moc_temporary_tracking
  add column if not exists restored_by   uuid references public.profiles(id),
  add column if not exists restore_note  text;

-- GERİ ALMA (gerekirse):
--   drop policy if exists "moc belgeler read"   on storage.objects;  (+ insert/update/delete)
--   delete from storage.buckets where id='moc-belgeler';   -- yalnız kova BOŞSA
--   alter table public.moc_temporary_tracking
--     drop column if exists restored_by, drop column if exists restore_note;
