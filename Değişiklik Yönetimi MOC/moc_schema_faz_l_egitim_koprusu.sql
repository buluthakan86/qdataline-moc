-- ============================================================================
-- Faz L (2026-09-08) — TRAINING adımı Eğitim Platformu'na (qdataline-egitim,
-- şema `egitim`, AYNI Supabase projesi bbltvuxxtacrpgrqnfoh — ayrı proje/backend
-- DEĞİL) bağlanıyor. Model DOC_UPDATE ile birebir aynı: "MOC doğrular, Eğitim
-- Platformu uygular" — MOC içine ikinci bir eğitim sistemi yazılmadı.
--
-- ⚠️ UYGULAMADAN ÖNCE CANLIDA DOĞRULANDI (memory kuralı):
--   - egitim.enrollment.user_id / egitim.user_account.id, MOC'un kendi
--     auth.users(id) ile AYNI paylaşımlı kimlik havuzu (test: 52/52 email eşleşti,
--     id doğrudan eşleşiyor) — kişi eşleştirmesi user_id ile yapılabilir.
--   - egitim.tenant.id İLE public.tenants.id AYNI DEĞER UZAYINDA DEĞİL (0/3 eşleşme)
--     — bu yüzden tenant izolasyonu egitim.tenant_id() JWT claim'ine değil,
--     public.profiles üzerinden (aynı tenant'taki kişi mi?) yapılıyor.
--   - egitim şeması zaten PostgREST'e açık (db_schema config'i doğrulandı) ama
--     egitim.enrollment RLS'i (egitim.tenant_id() claim'i) MOC oturumları için
--     güvenilir biçimde dolu olmayabilir — bu yüzden ham `sb.schema('egitim')...`
--     yerine, tenant sızıntısını public.profiles ile kendi kontrol eden
--     SECURITY DEFINER fonksiyonlar tercih edildi (ggd_sablonlar'daki gibi çıplak
--     cross-schema RLS politikası DEĞİL — egitim tarafında birden fazla tabloya
--     (enrollment/course_version/course) yeni politika eklemek yerine tek,
--     denetlenebilir bir API yüzeyi).
--
-- ⚠️ AYRICA BULUNUP BU MİGRASYONLA DÜZELTİLEN GERÇEK BİR BUG (ilgisiz ama aynı
--   tabloda): moc_trainings.training_type CHECK (IN ('INFO','CLASSROOM','ON_JOB'))
--   idi ama MOC.html'deki openAddTraining() serbest metin ("Konu" kutusu)
--   gönderiyordu — yani 07.09.2026'dan beri bu özellik boş olmayan bir konu
--   girildiğinde HER ZAMAN constraint ihlaliyle başarısız oluyordu (boş
--   bırakılırsa da NOT NULL ihlali). Kısıtlama gerçek kullanımla hiç
--   örtüşmüyordu, kaldırıldı.
-- ============================================================================

do $$
begin
  if to_regclass('public.moc_trainings') is null then raise exception 'public.moc_trainings YOK — yanlış proje?'; end if;
  if to_regclass('egitim.enrollment') is null then raise exception 'egitim.enrollment YOK — qdataline-egitim şeması bu projede değil mi?'; end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1) moc_trainings.training_type serbest metne açıldı (gerçek bug düzeltmesi)
-- ---------------------------------------------------------------------------
alter table public.moc_trainings drop constraint if exists moc_trainings_training_type_check;
alter table public.moc_trainings alter column training_type set default '';
alter table public.moc_trainings alter column training_type drop not null;
update public.moc_trainings set training_type='' where training_type is null;

-- ---------------------------------------------------------------------------
-- 2) Eğitim Platformu bağlantı sütunu — nullable, opsiyonel. Doldurulmazsa
--    (hedef kişinin Eğitim Platformu hesabı yoksa ya da manuel bilgilendirme
--    ise) davranış BİREBİR ESKİSİ GİBİDİR: elle "Tamamlandı İşaretle".
-- ---------------------------------------------------------------------------
alter table public.moc_trainings
  add column if not exists egitim_enrollment_id text references egitim.enrollment(id);
create index if not exists idx_moc_trainings_egitim_enrollment on public.moc_trainings(egitim_enrollment_id);

-- ---------------------------------------------------------------------------
-- 3) Kişinin Eğitim Platformu'ndaki kayıtlarını listeleyen API (kişi atarken
--    "+ Kişi Ata" formunda kullanılacak). Tenant sızıntısı burada engellenir:
--    hedef kişi çağıranla AYNI public.profiles.tenant_id'de olmalı.
-- ---------------------------------------------------------------------------
create or replace function public.moc_egitim_kayitlari(p_user_id uuid)
returns table(
  enrollment_id text,
  kurs_kodu text,
  kurs_baslik text,
  durum text,
  atanma_tarihi timestamptz,
  tamamlanma_tarihi timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and not (is_editor() and has_modul('moc')) then
    raise exception 'MOC_YETKI_YOK' using hint = 'Bu bilgiyi görüntülemek için yetkiniz yok.';
  end if;
  if auth.uid() is not null and not exists (
    select 1 from public.profiles me join public.profiles hedef on hedef.tenant_id = me.tenant_id
     where me.id = auth.uid() and hedef.id = p_user_id
  ) then
    raise exception 'MOC_YETKI_YOK' using hint = 'Bu kullanıcı sizin firmanızda değil.';
  end if;

  return query
    select e.id, c.code, c.title, e.status, e.assigned_at, e.completed_at
      from egitim.enrollment e
      join egitim.course_version cv on cv.id = e.course_version_id
      join egitim.course c on c.id = cv.course_id
     where e.user_id = p_user_id
     order by e.assigned_at desc nulls last;
end
$$;
grant execute on function public.moc_egitim_kayitlari(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4) Bir MOC talebine bağlı, Eğitim Platformu'na linkli tüm atamaların CANLI
--    durumunu getirir (detay ekranı açılırken toplu çekilir — computeAffectedDocStatus
--    ile aynı "fotoğrafla, canlıyla kıyasla" deseni). Erişim kendi
--    moc_trainings satırı üzerinden doğrulanır (tenant_id = current_tenant_id()),
--    ayrıca egitim tarafında rastgele id denemesini anlamsız kılar.
-- ---------------------------------------------------------------------------
create or replace function public.moc_egitim_durumlari(p_moc_id bigint)
returns table(egitim_enrollment_id text, durum text, tamamlanma_tarihi timestamptz)
language sql
security definer
set search_path = public
stable
as $$
  select tr.egitim_enrollment_id, e.status, e.completed_at
    from public.moc_trainings tr
    join egitim.enrollment e on e.id = tr.egitim_enrollment_id
   where tr.moc_id = p_moc_id
     and tr.tenant_id = public.current_tenant_id()
     and tr.egitim_enrollment_id is not null
$$;
grant execute on function public.moc_egitim_durumlari(bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- 5) DB-seviyesi kilit güncellendi (Faz K'nın devamı) — TRAINING -> PSSR/STARTUP
--    artık linkli kayıtlarda `acknowledged` yerine Eğitim Platformu'ndaki CANLI
--    `status='completed'`i şart koşuyor; linksiz (manuel) kayıtlarda davranış
--    DEĞİŞMEDİ (`acknowledged=true` yeterli).
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
$$;

drop trigger if exists moc_requests_durum_trg on public.moc_requests;
create trigger moc_requests_durum_trg
  before insert or update on public.moc_requests
  for each row execute function public.moc_durum_kontrol();

-- ============================================================================
-- BİTTİ. Eklenen: moc_trainings.egitim_enrollment_id (nullable, egitim.enrollment
-- FK), moc_egitim_kayitlari(uuid), moc_egitim_durumlari(bigint). Güncellenen:
-- moc_durum_kontrol() (TRAINING geçiş kuralı linkli/linksiz ayrımı eklendi),
-- moc_trainings.training_type (serbest metne açıldı — gerçek bug düzeltmesi).
-- DEĞİŞTİRİLEN/SİLİNEN başka nesne YOKTUR. egitim şemasındaki hiçbir tabloya/
-- RLS politikasına dokunulmadı (yalnızca SECURITY DEFINER fonksiyonlarla okundu).
-- ============================================================================
