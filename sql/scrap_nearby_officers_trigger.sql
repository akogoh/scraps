-- Nearby officers for scrap submissions: table + triggers.
-- Run after postgis_location_setup.sql. Uses PostGIS for distance/within.
-- Web app can query scrap_assignment_suggestions to show officers near each submission.

-- 1. Table: suggested nearby officers per submission (for unassigned jobs)
CREATE TABLE IF NOT EXISTS public.scrap_assignment_suggestions (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  submission_id UUID NOT NULL REFERENCES scrap_submissions(id) ON DELETE CASCADE,
  officer_id UUID NOT NULL REFERENCES field_officers(id) ON DELETE CASCADE,
  distance_km NUMERIC NOT NULL,
  suggested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT scrap_assignment_suggestions_pkey PRIMARY KEY (id),
  CONSTRAINT scrap_assignment_suggestions_sub_officer_key UNIQUE (submission_id, officer_id)
);

CREATE INDEX IF NOT EXISTS idx_suggestions_submission
  ON scrap_assignment_suggestions (submission_id);
CREATE INDEX IF NOT EXISTS idx_suggestions_officer
  ON scrap_assignment_suggestions (officer_id);
CREATE INDEX IF NOT EXISTS idx_suggestions_suggested_at
  ON scrap_assignment_suggestions (suggested_at);

COMMENT ON TABLE scrap_assignment_suggestions IS 'Officers within coverage_radius of each (unassigned) submission; kept in sync by triggers. Query by submission_id for web app.';

-- 2. Populate nearby officers for one submission (unassigned, with location)
CREATE OR REPLACE FUNCTION populate_nearby_officers_for_submission(p_submission_id UUID)
RETURNS void AS $$
BEGIN
  DELETE FROM scrap_assignment_suggestions WHERE submission_id = p_submission_id;

  INSERT INTO scrap_assignment_suggestions (submission_id, officer_id, distance_km, suggested_at)
  SELECT
    s.id,
    f.id,
    ROUND((ST_Distance(f.location::geography, s.location::geography) / 1000)::numeric, 2),
    now()
  FROM scrap_submissions s
  JOIN field_officers f
    ON f.is_active = true
   AND f.location IS NOT NULL
   AND ST_DWithin(f.location::geography, s.location::geography, (COALESCE(f.coverage_radius_km, 25) * 1000)::double precision)
  WHERE s.id = p_submission_id
    AND s.assigned_officer_id IS NULL
    AND s.location IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- 3. Repopulate nearby officers for all unassigned submissions (e.g. after officer moves)
CREATE OR REPLACE FUNCTION populate_nearby_officers_all()
RETURNS void AS $$
BEGIN
  DELETE FROM scrap_assignment_suggestions
  WHERE submission_id IN (
    SELECT id FROM scrap_submissions WHERE assigned_officer_id IS NULL
  );

  INSERT INTO scrap_assignment_suggestions (submission_id, officer_id, distance_km, suggested_at)
  SELECT
    s.id,
    f.id,
    ROUND((ST_Distance(f.location::geography, s.location::geography) / 1000)::numeric, 2),
    now()
  FROM scrap_submissions s
  JOIN field_officers f
    ON f.is_active = true
   AND f.location IS NOT NULL
   AND ST_DWithin(f.location::geography, s.location::geography, (COALESCE(f.coverage_radius_km, 25) * 1000)::double precision)
  WHERE s.assigned_officer_id IS NULL
    AND s.location IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- 4. Trigger: new/updated submission → refresh nearby officers for that submission
CREATE OR REPLACE FUNCTION trigger_nearby_on_submission()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.assigned_officer_id IS NULL AND NEW.location IS NOT NULL THEN
      PERFORM populate_nearby_officers_for_submission(NEW.id);
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.assigned_officer_id IS NOT NULL THEN
      DELETE FROM scrap_assignment_suggestions WHERE submission_id = NEW.id;
    ELSIF NEW.location IS NOT NULL AND (OLD.location IS DISTINCT FROM NEW.location OR OLD.assigned_officer_id IS DISTINCT FROM NEW.assigned_officer_id) THEN
      PERFORM populate_nearby_officers_for_submission(NEW.id);
    END IF;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_nearby_on_submission ON scrap_submissions;
CREATE TRIGGER trigger_nearby_on_submission
  AFTER INSERT OR UPDATE OF location, assigned_officer_id ON scrap_submissions
  FOR EACH ROW
  EXECUTE FUNCTION trigger_nearby_on_submission();

-- 5. Trigger: officer location updated → refresh nearby for all unassigned submissions
CREATE OR REPLACE FUNCTION trigger_nearby_on_officer_location()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.location IS DISTINCT FROM OLD.location AND NEW.location IS NOT NULL THEN
    PERFORM populate_nearby_officers_all();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_nearby_on_officer_location ON field_officers;
CREATE TRIGGER trigger_nearby_on_officer_location
  AFTER UPDATE OF latitude, longitude ON field_officers
  FOR EACH ROW
  EXECUTE FUNCTION trigger_nearby_on_officer_location();

-- 6. One-time backfill: compute suggestions for all current unassigned submissions
SELECT populate_nearby_officers_all();
