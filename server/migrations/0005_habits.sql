ALTER TABLE sync_entities DROP CONSTRAINT sync_entities_entity_type_check;
ALTER TABLE sync_entities ADD CONSTRAINT sync_entities_entity_type_check
    CHECK (entity_type IN ('task', 'occurrence', 'habit', 'habit-entry'));

ALTER TABLE changes DROP CONSTRAINT changes_entity_type_check;
ALTER TABLE changes ADD CONSTRAINT changes_entity_type_check
    CHECK (entity_type IN ('task', 'occurrence', 'habit', 'habit-entry'));
