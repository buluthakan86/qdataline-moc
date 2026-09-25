-- Proje ve görev ilk plan tarihleri sonraki revizyonlarda değiştirilemez.
-- Eski kayıtlar için en eski baz çizgi varsa o; yoksa mevcut tarih kullanılır.
BEGIN;

ALTER TABLE public.moc_projects
  ADD COLUMN IF NOT EXISTS initial_planned_start date,
  ADD COLUMN IF NOT EXISTS initial_planned_end date,
  ADD COLUMN IF NOT EXISTS date_change_reason text;
ALTER TABLE public.moc_project_tasks
  ADD COLUMN IF NOT EXISTS initial_planned_start date,
  ADD COLUMN IF NOT EXISTS initial_due_date date,
  ADD COLUMN IF NOT EXISTS date_change_reason text;

UPDATE public.moc_projects p
SET initial_planned_start = coalesce(
      (SELECT (b.snapshot->'project'->>'planned_start')::date FROM public.moc_project_baselines b
       WHERE b.project_id=p.id ORDER BY b.version_no ASC LIMIT 1),p.planned_start),
    initial_planned_end = coalesce(
      (SELECT (b.snapshot->'project'->>'planned_end')::date FROM public.moc_project_baselines b
       WHERE b.project_id=p.id ORDER BY b.version_no ASC LIMIT 1),p.planned_end)
WHERE p.initial_planned_start IS NULL AND p.initial_planned_end IS NULL;
UPDATE public.moc_projects
SET initial_planned_start=coalesce(initial_planned_start,planned_start),
    initial_planned_end=coalesce(initial_planned_end,planned_end)
WHERE initial_planned_start IS NULL OR initial_planned_end IS NULL;

UPDATE public.moc_project_tasks t
SET initial_planned_start=coalesce(
      (SELECT (item->>'planned_start')::date FROM public.moc_project_baselines mb,
       LATERAL jsonb_array_elements(coalesce(mb.snapshot->'tasks','[]'::jsonb)) item
       WHERE mb.project_id=t.project_id AND (item->>'id')::bigint=t.id
       ORDER BY mb.version_no ASC LIMIT 1),t.planned_start),
    initial_due_date=coalesce(
      (SELECT (item->>'due_date')::date FROM public.moc_project_baselines mb,
       LATERAL jsonb_array_elements(coalesce(mb.snapshot->'tasks','[]'::jsonb)) item
       WHERE mb.project_id=t.project_id AND (item->>'id')::bigint=t.id
       ORDER BY mb.version_no ASC LIMIT 1),t.due_date)
WHERE t.initial_planned_start IS NULL AND t.initial_due_date IS NULL;
UPDATE public.moc_project_tasks
SET initial_planned_start=coalesce(initial_planned_start,planned_start),
    initial_due_date=coalesce(initial_due_date,due_date)
WHERE initial_planned_start IS NULL OR initial_due_date IS NULL;

CREATE OR REPLACE FUNCTION public.moc_preserve_first_plan_dates()
RETURNS trigger LANGUAGE plpgsql SET search_path=public AS $$
BEGIN
  IF TG_TABLE_NAME='moc_projects' THEN
    IF TG_OP='INSERT' THEN
      NEW.initial_planned_start:=NEW.planned_start;
      NEW.initial_planned_end:=NEW.planned_end;
    ELSE
      NEW.initial_planned_start:=OLD.initial_planned_start;
      NEW.initial_planned_end:=OLD.initial_planned_end;
    END IF;
  ELSE
    IF TG_OP='INSERT' THEN
      NEW.initial_planned_start:=NEW.planned_start;
      NEW.initial_due_date:=NEW.due_date;
    ELSE
      NEW.initial_planned_start:=OLD.initial_planned_start;
      NEW.initial_due_date:=OLD.initial_due_date;
    END IF;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS moc_projects_first_plan_guard ON public.moc_projects;
CREATE TRIGGER moc_projects_first_plan_guard BEFORE INSERT OR UPDATE ON public.moc_projects
FOR EACH ROW EXECUTE FUNCTION public.moc_preserve_first_plan_dates();
DROP TRIGGER IF EXISTS moc_project_tasks_first_plan_guard ON public.moc_project_tasks;
CREATE TRIGGER moc_project_tasks_first_plan_guard BEFORE INSERT OR UPDATE ON public.moc_project_tasks
FOR EACH ROW EXECUTE FUNCTION public.moc_preserve_first_plan_dates();
COMMIT;
