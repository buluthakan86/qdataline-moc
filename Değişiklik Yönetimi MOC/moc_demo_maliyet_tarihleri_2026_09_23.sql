-- Yalnız açıkça DEMO olarak işaretli projedeki sentetik maliyet satırları.
UPDATE public.moc_project_costs c
SET planned_on = CASE c.cost_type
    WHEN 'PURCHASE' THEN date '2026-09-30'
    WHEN 'LABOR' THEN date '2026-10-07'
    WHEN 'EXTERNAL_SERVICE' THEN date '2026-10-21'
    ELSE c.planned_on END,
    incurred_on = CASE WHEN c.cost_type = 'LABOR' AND c.actual > 0
      THEN date '2026-09-22' ELSE c.incurred_on END
FROM public.moc_projects p
WHERE c.project_id=p.id
  AND c.tenant_id='675ac400-7f2a-4f82-a5d4-a7d7fb3c11a4'::uuid
  AND p.tenant_id=c.tenant_id
  AND p.name='[DEMO] Paketleme hattı sensör yenilemesi'
  AND c.description LIKE '[DEMO] %';
