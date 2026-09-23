-- Proje&MOC: görev bağımlılığı. Önce staging, sonra canlı veritabanına uygulanır.
-- Teknik modül kodu ve mevcut MOC akışı değişmez.

CREATE OR REPLACE FUNCTION public.moc_project_dependency_blocks(
  p_type text, p_predecessor_status text, p_successor_status text
) RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN p_type IN ('FINISH_TO_START','BLOCKS')
      THEN p_successor_status IN ('IN_PROGRESS','IN_REVIEW','DONE')
        AND p_predecessor_status <> 'DONE'
    WHEN p_type = 'START_TO_START'
      THEN p_successor_status IN ('IN_PROGRESS','IN_REVIEW','DONE')
        AND p_predecessor_status NOT IN ('IN_PROGRESS','IN_REVIEW','DONE')
    WHEN p_type = 'FINISH_TO_FINISH'
      THEN p_successor_status = 'DONE' AND p_predecessor_status <> 'DONE'
    ELSE false
  END
$$;
REVOKE ALL ON FUNCTION public.moc_project_dependency_blocks(text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.moc_project_dependency_blocks(text,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.moc_project_dependency_guard()
RETURNS trigger LANGUAGE plpgsql SET search_path=public AS $$
DECLARE
  v_predecessor_status text;
  v_successor_status text;
  v_cycle boolean;
BEGIN
  SELECT status INTO v_predecessor_status FROM public.moc_project_tasks
    WHERE id=NEW.predecessor_task_id AND project_id=NEW.project_id AND tenant_id=NEW.tenant_id FOR SHARE;
  SELECT status INTO v_successor_status FROM public.moc_project_tasks
    WHERE id=NEW.successor_task_id AND project_id=NEW.project_id AND tenant_id=NEW.tenant_id FOR SHARE;
  IF v_predecessor_status IS NULL OR v_successor_status IS NULL THEN
    RAISE EXCEPTION 'MOC_DEPENDENCY_TASK_MISSING';
  END IF;
  IF public.moc_project_dependency_blocks(NEW.dependency_type,v_predecessor_status,v_successor_status) THEN
    RAISE EXCEPTION 'MOC_DEPENDENCY_ACTIVE_TASK';
  END IF;

  -- Yeni öncül → ardıl kenarı bir çevrim oluşturamaz.
  WITH RECURSIVE walk(task_id,path) AS (
    SELECT NEW.successor_task_id,ARRAY[NEW.successor_task_id]
    UNION ALL
    SELECT d.successor_task_id,w.path||d.successor_task_id
      FROM walk w JOIN public.moc_task_dependencies d
        ON d.predecessor_task_id=w.task_id AND d.project_id=NEW.project_id
       AND d.tenant_id=NEW.tenant_id AND (TG_OP='INSERT' OR d.id<>NEW.id)
     WHERE NOT d.successor_task_id=ANY(w.path)
  ) SELECT EXISTS(SELECT 1 FROM walk WHERE task_id=NEW.predecessor_task_id) INTO v_cycle;
  IF v_cycle THEN RAISE EXCEPTION 'MOC_DEPENDENCY_CYCLE'; END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS moc_project_dependency_guard ON public.moc_task_dependencies;
CREATE TRIGGER moc_project_dependency_guard
  BEFORE INSERT OR UPDATE OF predecessor_task_id,successor_task_id,dependency_type,project_id,tenant_id
  ON public.moc_task_dependencies FOR EACH ROW
  EXECUTE FUNCTION public.moc_project_dependency_guard();

CREATE OR REPLACE FUNCTION public.moc_project_task_status_guard()
RETURNS trigger LANGUAGE plpgsql SET search_path=public AS $$
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN RETURN NEW; END IF;
  IF EXISTS(
    SELECT 1 FROM public.moc_task_dependencies d
    JOIN public.moc_project_tasks p ON p.id=d.predecessor_task_id
    WHERE d.successor_task_id=NEW.id AND d.project_id=NEW.project_id
      AND d.tenant_id=NEW.tenant_id
      AND public.moc_project_dependency_blocks(d.dependency_type,p.status,NEW.status)
    FOR SHARE OF p
  ) THEN RAISE EXCEPTION 'MOC_DEPENDENCY_PREDECESSOR_OPEN'; END IF;
  -- Tamamlanmış bir öncülü tekrar açmak, ilerlemiş ardılları geçersiz kılamaz.
  IF EXISTS(
    SELECT 1 FROM public.moc_task_dependencies d
    JOIN public.moc_project_tasks s ON s.id=d.successor_task_id
    WHERE d.predecessor_task_id=NEW.id AND d.project_id=NEW.project_id
      AND d.tenant_id=NEW.tenant_id
      AND public.moc_project_dependency_blocks(d.dependency_type,NEW.status,s.status)
    FOR SHARE OF s
  ) THEN RAISE EXCEPTION 'MOC_DEPENDENCY_SUCCESSOR_ACTIVE'; END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS moc_project_task_status_guard ON public.moc_project_tasks;
CREATE TRIGGER moc_project_task_status_guard BEFORE UPDATE OF status
  ON public.moc_project_tasks FOR EACH ROW
  EXECUTE FUNCTION public.moc_project_task_status_guard();

-- Tek öncüllü basit arayüz için atomik değiştirme işlemi. Çoklu veya farklı
-- türdeki mevcut bağlar bu işlevle silinmez.
CREATE OR REPLACE FUNCTION public.moc_project_set_predecessor(
  p_task_id bigint, p_predecessor_id bigint DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE
  v_tenant uuid;
  v_project bigint;
  v_other_project bigint;
  v_count int;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_editor() OR NOT EXISTS(
    SELECT 1 FROM public.modul_yetki WHERE user_id=auth.uid() AND modul='moc'
  ) THEN RAISE EXCEPTION 'MOC_PROJECT_FORBIDDEN'; END IF;
  SELECT tenant_id,project_id INTO v_tenant,v_project FROM public.moc_project_tasks
    WHERE id=p_task_id FOR UPDATE;
  IF NOT FOUND OR v_tenant IS DISTINCT FROM public.current_tenant_id() THEN
    RAISE EXCEPTION 'MOC_PROJECT_TASK_NOT_FOUND';
  END IF;
  IF p_predecessor_id=p_task_id THEN RAISE EXCEPTION 'MOC_DEPENDENCY_SELF'; END IF;
  IF p_predecessor_id IS NOT NULL THEN
    SELECT project_id INTO v_other_project FROM public.moc_project_tasks
      WHERE id=p_predecessor_id AND tenant_id=v_tenant FOR UPDATE;
    IF NOT FOUND OR v_other_project<>v_project THEN
      RAISE EXCEPTION 'MOC_DEPENDENCY_DIFFERENT_PROJECT';
    END IF;
  END IF;
  SELECT count(*) INTO v_count FROM public.moc_task_dependencies
    WHERE successor_task_id=p_task_id AND project_id=v_project
      AND tenant_id=v_tenant AND dependency_type='FINISH_TO_START';
  IF v_count>1 THEN RAISE EXCEPTION 'MOC_DEPENDENCY_MULTIPLE_NOT_SUPPORTED'; END IF;
  IF v_count=1 AND EXISTS(
    SELECT 1 FROM public.moc_task_dependencies
    WHERE successor_task_id=p_task_id AND project_id=v_project
      AND tenant_id=v_tenant AND dependency_type='FINISH_TO_START'
      AND predecessor_task_id IS NOT DISTINCT FROM p_predecessor_id
  ) THEN RETURN; END IF;
  DELETE FROM public.moc_task_dependencies
    WHERE successor_task_id=p_task_id AND project_id=v_project
      AND tenant_id=v_tenant AND dependency_type='FINISH_TO_START';
  IF p_predecessor_id IS NOT NULL THEN
    INSERT INTO public.moc_task_dependencies(
      tenant_id,project_id,predecessor_task_id,successor_task_id,
      dependency_type,created_by
    ) VALUES(v_tenant,v_project,p_predecessor_id,p_task_id,'FINISH_TO_START',auth.uid());
  END IF;
END $$;
REVOKE ALL ON FUNCTION public.moc_project_set_predecessor(bigint,bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.moc_project_set_predecessor(bigint,bigint) TO authenticated;
