-- Proje durumunu elle COMPLETED yapan yol, MOC kapanışındaki kuralları atlayamaz.
-- Normal MOC STARTUP -> CLOSED tetikleyicisi aynı kontrollerden sonra projeyi tamamlar.
CREATE OR REPLACE FUNCTION public.moc_project_status_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF NEW.status='COMPLETED' AND OLD.status IS DISTINCT FROM NEW.status THEN
  IF EXISTS(SELECT 1 FROM public.moc_project_tasks t
    WHERE t.project_id=NEW.id AND t.required AND t.status<>'DONE')
   THEN RAISE EXCEPTION 'MOC_ZORUNLU_GOREV_ACIK'; END IF;
  IF EXISTS(SELECT 1 FROM public.moc_task_checklist_items c
    JOIN public.moc_project_tasks t ON t.id=c.task_id
    WHERE c.project_id=NEW.id AND t.required AND NOT c.done)
   THEN RAISE EXCEPTION 'MOC_KONTROL_LISTESI_EKSIK'; END IF;
  IF EXISTS(SELECT 1 FROM public.moc_project_tasks t
    WHERE t.project_id=NEW.id AND t.required AND t.evidence_required
      AND NOT EXISTS(SELECT 1 FROM public.moc_task_evidence e WHERE e.task_id=t.id))
   THEN RAISE EXCEPTION 'MOC_GOREV_KANITI_EKSIK'; END IF;
  IF EXISTS(SELECT 1 FROM public.moc_project_milestones m
    WHERE m.project_id=NEW.id
      AND m.milestone_type IN ('DOC_EFFECTIVE','TRAINING','PSSR','EFFECTIVENESS')
      AND m.completed_at IS NULL)
   THEN RAISE EXCEPTION 'MOC_KILOMETRE_TASI_EKSIK'; END IF;
 END IF;
 RETURN NEW;
END $$;
