-- PostGIS + geography columns for logistics-grade geo.
-- Run in Supabase SQL Editor (one-time).
--
-- For in-app notifications (job assignment, new messages), ensure Realtime
-- is enabled: Database → Publications → supabase_realtime → add tables
-- scrap_submissions and messages (if not already added).

-- 1. Enable PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Add geography column to field_officers (keep latitude/longitude for compatibility)
ALTER TABLE field_officers
  ADD COLUMN IF NOT EXISTS location geography(Point, 4326);

-- 3. Add geography column to scrap_submissions
ALTER TABLE scrap_submissions
  ADD COLUMN IF NOT EXISTS location geography(Point, 4326);

-- 4. Backfill and keep in sync: when latitude/longitude change, set location
-- Field officers: trigger on update
CREATE OR REPLACE FUNCTION sync_field_officer_location()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
    NEW.location := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_sync_field_officer_location ON field_officers;
CREATE TRIGGER trigger_sync_field_officer_location
  BEFORE INSERT OR UPDATE OF latitude, longitude ON field_officers
  FOR EACH ROW
  EXECUTE FUNCTION sync_field_officer_location();

-- Backfill existing rows
UPDATE field_officers
SET location = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
WHERE latitude IS NOT NULL AND longitude IS NOT NULL AND location IS NULL;

-- 5. Scrap submissions: sync when latitude/longitude change
CREATE OR REPLACE FUNCTION sync_scrap_submission_location()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
    NEW.location := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_sync_scrap_submission_location ON scrap_submissions;
CREATE TRIGGER trigger_sync_scrap_submission_location
  BEFORE INSERT OR UPDATE OF latitude, longitude ON scrap_submissions
  FOR EACH ROW
  EXECUTE FUNCTION sync_scrap_submission_location();

-- Backfill
UPDATE scrap_submissions
SET location = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
WHERE latitude IS NOT NULL AND longitude IS NOT NULL AND location IS NULL;

-- 6. Spatial indexes (critical for fast geo queries)
CREATE INDEX IF NOT EXISTS idx_field_officers_location
  ON field_officers USING gist (location);

CREATE INDEX IF NOT EXISTS idx_scrap_submissions_location
  ON scrap_submissions USING gist (location);

-- So Realtime sends old record on UPDATE (app can show "New job assigned" only when newly assigned)
ALTER TABLE scrap_submissions REPLICA IDENTITY FULL;
