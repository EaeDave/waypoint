ALTER TABLE sync_entities DROP CONSTRAINT sync_entities_entity_type_check;
ALTER TABLE sync_entities ADD CONSTRAINT sync_entities_entity_type_check
    CHECK (entity_type IN ('task', 'occurrence', 'habit', 'habit-entry', 'category'));

ALTER TABLE changes DROP CONSTRAINT changes_entity_type_check;
ALTER TABLE changes ADD CONSTRAINT changes_entity_type_check
    CHECK (entity_type IN ('task', 'occurrence', 'habit', 'habit-entry', 'category'));

CREATE UNIQUE INDEX sync_entities_active_category_name_idx
    ON sync_entities (lower(payload->>'name'))
    WHERE entity_type = 'category' AND deleted = FALSE;
