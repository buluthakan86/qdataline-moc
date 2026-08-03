-- ============================================================================
-- MOC — Faz B düzeltme: moc_no otomatik üretimi
-- Hata: moc_requests.moc_no NOT NULL ama hiçbir yerde üretilmiyordu
-- (moc_schema_faz_a.sql'in sonundaki "SONRAKİ ADIMLAR" notu hiç
-- uygulanmamıştı). Talep formu INSERT'te moc_no göndermiyor, bu yüzden
-- "null value in column moc_no violates not-null constraint" hatası
-- alınıyordu.
--
-- Çözüm: BEFORE INSERT trigger — NEW.moc_no boşsa, tenant+yıl bazlı
-- atomik sayaçtan "MOC-YYYY-NNNN" üretir. Uygulama kodunda DEĞİŞİKLİK
-- GEREKMEZ: MOC.html zaten insert().select().single() kullanıyor,
-- trigger INSERT'ten önce NEW'i doldurduğu için RETURNING üretilen
-- moc_no'yu döner.
--
-- Güvenlik:
--   * Idempotent: CREATE TABLE IF NOT EXISTS, CREATE OR REPLACE FUNCTION,
--     DROP TRIGGER IF EXISTS + yeniden CREATE. DROP TABLE yok.
--   * moc_no_counters tablosu RLS açık ama HİÇBİR policy tanımlanmadı ve
--     authenticated rolüne GRANT verilmedi → istemci bu tabloya doğrudan
--     erişemez, yalnız SECURITY DEFINER trigger fonksiyonu (moc_audit_
--     trigger ile aynı desen) dokunur.
--   * Yeni fonksiyon (moc_generate_no) bir TRIGGER fonksiyonu — PostgREST
--     üzerinden RPC olarak çağrılamaz, bu yüzden GRANT EXECUTE TO
--     authenticated / Dashboard "Exposed Functions" listesi GEREKMEZ.
--     (moc_audit_trigger ve moc_set_updated_at ile aynı kategori.)
--     Emin olmak için: trigger fonksiyonları information_schema.routines'te
--     görünür ama Data API yalnız "Exposed Functions" listesine eklenmiş
--     fonksiyonları PostgREST'e açar; trigger'lar oraya elle eklenmediği
--     sürece dışarıdan çağrılamaz — burada hiç eklemiyoruz.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- Sayaç tablosu — tenant + yıl bazlı atomik artış
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.moc_no_counters (
  tenant_id   UUID NOT NULL,
  year        INT  NOT NULL,
  last_seq    INT  NOT NULL DEFAULT 0,
  PRIMARY KEY (tenant_id, year)
);

ALTER TABLE public.moc_no_counters ENABLE ROW LEVEL SECURITY;
-- Kasıtlı olarak HİÇBİR policy yok: authenticated rolüne bu tabloya
-- SELECT/INSERT/UPDATE GRANT verilmedi, RLS zaten varsayılan DENY.
-- Yalnız SECURITY DEFINER trigger fonksiyonu erişir.

-- ----------------------------------------------------------------------------
-- Üretici fonksiyon
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.moc_generate_no()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  yr  INT;
  seq INT;
BEGIN
  IF NEW.moc_no IS NOT NULL AND NEW.moc_no <> '' THEN
    RETURN NEW;
  END IF;

  yr := EXTRACT(YEAR FROM now())::INT;

  INSERT INTO public.moc_no_counters (tenant_id, year, last_seq)
    VALUES (NEW.tenant_id, yr, 1)
  ON CONFLICT (tenant_id, year)
    DO UPDATE SET last_seq = public.moc_no_counters.last_seq + 1
  RETURNING last_seq INTO seq;

  NEW.moc_no := 'MOC-' || yr || '-' || lpad(seq::text, 4, '0');
  RETURN NEW;
END;
$$;

-- ----------------------------------------------------------------------------
-- Trigger bağlama (idempotent)
-- ----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_moc_generate_no ON public.moc_requests;
CREATE TRIGGER trg_moc_generate_no
  BEFORE INSERT ON public.moc_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.moc_generate_no();

COMMIT;

-- ============================================================================
-- GERİ ALMA (yalnız elle, gerekirse — bu script bunu ÇALIŞTIRMAZ)
-- ============================================================================
-- BEGIN;
-- DROP TRIGGER IF EXISTS trg_moc_generate_no ON public.moc_requests;
-- DROP FUNCTION IF EXISTS public.moc_generate_no();
-- DROP TABLE IF EXISTS public.moc_no_counters;
-- COMMIT;
-- ============================================================================
