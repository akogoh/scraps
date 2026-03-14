alter table public.scrap_submissions
  add column if not exists is_selling boolean not null default true;

-- Optional: index if you plan to filter frequently by this flag
create index if not exists idx_scrap_submissions_is_selling
  on public.scrap_submissions (is_selling);

