# Nearby Officers for Scrap Submissions (Web App)

The database automatically maintains **nearby field officers** for each (unassigned) scrap submission using PostGIS. The web app can read this table to display "Officers near this scrap" without running geo queries.

## Table: `scrap_assignment_suggestions`

| Column          | Type      | Description                          |
|-----------------|-----------|--------------------------------------|
| `id`            | uuid      | Primary key                          |
| `submission_id` | uuid      | Scrap submission                     |
| `officer_id`    | uuid      | Field officer                        |
| `distance_km`   | numeric   | Distance in km (rounded to 2 decimals) |
| `suggested_at`  | timestamptz | When the suggestion was computed   |

- Only **unassigned** submissions appear (once `assigned_officer_id` is set, rows for that submission are removed).
- Officers are included only if they are **within their `coverage_radius_km`** of the submission and **active** (`is_active = true`).

## When it updates (automatic)

- **New submission** with location → nearby officers computed and inserted.
- **Submission location or assignment changes** → suggestions for that submission refreshed or cleared.
- **Officer location updated** (e.g. from the app every 30s) → all suggestions for unassigned submissions recomputed.

## Web app: query by submission

Get officers near a given submission, ordered by distance (closest first):

```sql
SELECT
  s.submission_id,
  s.officer_id,
  s.distance_km,
  s.suggested_at,
  f.name AS officer_name,
  f.phone_number AS officer_phone
FROM scrap_assignment_suggestions s
JOIN field_officers f ON f.id = s.officer_id
WHERE s.submission_id = :submission_id
ORDER BY s.distance_km ASC;
```

Or via Supabase client (e.g. JS):

```js
const { data } = await supabase
  .from('scrap_assignment_suggestions')
  .select(`
    officer_id,
    distance_km,
    suggested_at,
    field_officers ( name, phone_number )
  `)
  .eq('submission_id', submissionId)
  .order('distance_km', { ascending: true });
```

## Web app: list submissions with nearby officer counts

```sql
SELECT
  sub.id,
  sub.item_name,
  sub.status,
  sub.assigned_officer_id,
  COUNT(s.id) AS nearby_officer_count
FROM scrap_submissions sub
LEFT JOIN scrap_assignment_suggestions s ON s.submission_id = sub.id
WHERE sub.assigned_officer_id IS NULL
GROUP BY sub.id;
```

## Realtime (optional)

To show live updates when suggestions change, subscribe to `scrap_assignment_suggestions` in Supabase Realtime (add the table to the `supabase_realtime` publication if needed).
