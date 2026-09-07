-- ============================================================================
-- Faz K (2026-09-07) — DOC_UPDATE/TRAINING geçişlerine DB-seviyesi kilit.
-- Kod tarafında (MOC.html: condAffectedDocsDone/condTrainingDone) bu kontroller
-- zaten var, ama yalnız istemcide — platformun daha önce birkaç kez ders çıkardığı
-- "istemci-tarafı kural tuzağı" (bkz. memory feedback_istemci_tarafi_kural_tuzagi)
-- burada da tekrarlanmasın diye moc_durum_kontrol() trigger'ına aynı iki kural
-- ekleniyor. Konsoldan/API'den doğrudan UPDATE ile durum değiştirmeyi de kapatır.
--
-- Mantık MOC.html'deki computeAffectedDocStatus()/condAffectedDocsDone() ve
-- condTrainingDone() ile BİREBİR aynı — iki yerde ayrı mantık icat edilmedi:
--   DOC_UPDATE -> TRAINING: moc_documents'taki her AFFECTED_DOC kaydı için
--     ggd_sablonlar.versiyon_no (doc_ref=ggd_sablonlar.id) old_version'dan büyük
--     VE durum='Yürürlükte' olmalı. Hiç AFFECTED_DOC kaydı yoksa engel yok
--     (geriye dönük uyumluluk, condActionsDone ile aynı desen).
--   TRAINING -> PSSR/STARTUP: moc_trainings'teki her kayıt acknowledged=true
--     olmalı. Hiç kayıt yoksa engel yok.
-- ============================================================================

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

  -- Faz K (2): TRAINING -> PSSR/STARTUP, atanan eğitimlerin hepsi tamamlanmış olmalı.
  if new.status in ('PSSR','STARTUP') and old.status = 'TRAINING' then
    select count(*) into v_eksik_egitim
      from public.moc_trainings tr
     where tr.moc_id = new.id and tr.acknowledged is not true;
    if v_eksik_egitim > 0 then
      raise exception 'MOC_GECERSIZ_GECIS'
        using hint = 'Atanan egitimlerin tamami onaylanmadan bir sonraki asamaya gecilemez.';
    end if;
  end if;

  return new;
end
$$;

-- Trigger tanımı değişmedi, fonksiyon CREATE OR REPLACE ile güncellendi;
-- yine de idempotentlik için aynen tekrarlanıyor.
drop trigger if exists moc_requests_durum_trg on public.moc_requests;
create trigger moc_requests_durum_trg
  before insert or update on public.moc_requests
  for each row execute function public.moc_durum_kontrol();
