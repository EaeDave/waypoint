-- Old completedAt values describe registration, not the actual completion day.
UPDATE sync_entities
SET payload = (payload - 'completedAt') || jsonb_build_object(
    'registeredAt', COALESCE(payload->'registeredAt', payload->'completedAt', '""'::jsonb),
    'completedDate', COALESCE(payload->'completedDate', '""'::jsonb)
)
WHERE entity_type IN ('task', 'occurrence') AND NOT deleted;

UPDATE changes
SET payload = (payload - 'completedAt') || jsonb_build_object(
    'registeredAt', COALESCE(payload->'registeredAt', payload->'completedAt', '""'::jsonb),
    'completedDate', COALESCE(payload->'completedDate', '""'::jsonb)
)
WHERE entity_type IN ('task', 'occurrence') AND operation = 'upsert';
