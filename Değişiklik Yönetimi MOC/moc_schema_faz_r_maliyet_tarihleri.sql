-- Proje maliyetinin planlanan ve gerçekleşen dönemi. Eski kayıtlar tarihsiz kalır;
-- arayüz bunları ayrı gösterir, tahmini bir gerçekleşme tarihi üretmez.
ALTER TABLE public.moc_project_costs
  ADD COLUMN IF NOT EXISTS planned_on date,
  ADD COLUMN IF NOT EXISTS incurred_on date;

CREATE INDEX IF NOT EXISTS moc_project_costs_project_incurred_on_idx
  ON public.moc_project_costs(project_id, incurred_on);
