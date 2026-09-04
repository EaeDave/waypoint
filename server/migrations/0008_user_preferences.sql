CREATE TABLE user_preferences (
    singleton BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (singleton),
    task_visibility TEXT NOT NULL DEFAULT 'all'
        CHECK (task_visibility IN ('all', 'pending')),
    revision BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE user_preference_mutations (
    mutation_id UUID PRIMARY KEY,
    device_id TEXT NOT NULL,
    accepted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO user_preferences(singleton)
VALUES (TRUE)
ON CONFLICT(singleton) DO NOTHING;
