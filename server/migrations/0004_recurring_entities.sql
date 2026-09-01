CREATE TABLE sync_entities (
    entity_type TEXT NOT NULL CHECK (entity_type IN ('task', 'occurrence')),
    entity_id TEXT NOT NULL,
    payload JSONB NOT NULL,
    version BIGINT NOT NULL,
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (entity_type, entity_id)
);

INSERT INTO sync_entities(entity_type, entity_id, payload, version, deleted, updated_at)
SELECT 'task', id::text, payload, version, deleted, updated_at
FROM tasks;

ALTER TABLE changes ADD COLUMN entity_type TEXT;
ALTER TABLE changes ADD COLUMN entity_id TEXT;
ALTER TABLE changes ADD COLUMN payload JSONB;

UPDATE changes
SET entity_type = 'task',
    entity_id = task->>'id',
    payload = task;

ALTER TABLE changes ALTER COLUMN entity_type SET NOT NULL;
ALTER TABLE changes ALTER COLUMN entity_id SET NOT NULL;
ALTER TABLE changes ALTER COLUMN payload SET NOT NULL;
ALTER TABLE changes ADD CONSTRAINT changes_entity_type_check
    CHECK (entity_type IN ('task', 'occurrence'));
ALTER TABLE changes DROP COLUMN task;

DROP TABLE tasks;
