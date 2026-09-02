UPDATE changes
SET payload = jsonb_set(
    payload,
    '{deletedAt}',
    to_jsonb(to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'))
)
WHERE operation = 'delete'
  AND entity_type IN ('task', 'habit', 'habit-entry')
  AND COALESCE(payload->>'deletedAt', '') = '';

UPDATE sync_entities
SET payload = jsonb_set(
    payload,
    '{deletedAt}',
    to_jsonb(to_char(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'))
)
WHERE deleted
  AND entity_type IN ('task', 'habit', 'habit-entry')
  AND COALESCE(payload->>'deletedAt', '') = '';
