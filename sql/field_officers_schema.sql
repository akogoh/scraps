-- field_officers table - full schema (reference / create from scratch)
-- Run in Supabase SQL Editor only if the table does not exist.

CREATE TABLE IF NOT EXISTS public.field_officers (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  phone TEXT NULL,
  is_active BOOLEAN NULL DEFAULT true,
  password TEXT NULL,
  phone_number TEXT NULL,
  email TEXT NULL,
  created_at TIMESTAMPTZ NULL DEFAULT now(),
  last_login TIMESTAMPTZ NULL,
  photo_url TEXT NULL,
  latitude DOUBLE PRECISION NULL,
  longitude DOUBLE PRECISION NULL,
  last_location_update TIMESTAMPTZ NULL,
  coverage_radius_km NUMERIC NULL DEFAULT 25,
  image_url TEXT NULL,
  CONSTRAINT field_officers_pkey PRIMARY KEY (id),
  CONSTRAINT field_officers_name_key UNIQUE (name)
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_field_officers_name
  ON public.field_officers USING btree (name) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_field_officers_is_active
  ON public.field_officers USING btree (is_active) TABLESPACE pg_default;
