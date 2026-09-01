CREATE TABLE IF NOT EXISTS tasks (
    id UUID PRIMARY KEY,
    payload JSONB NOT NULL,
    version BIGINT NOT NULL,
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS mutations (
    mutation_id UUID PRIMARY KEY,
    device_id TEXT NOT NULL,
    accepted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS changes (
    sequence BIGSERIAL PRIMARY KEY,
    mutation_id UUID NOT NULL REFERENCES mutations(mutation_id),
    operation TEXT NOT NULL CHECK (operation IN ('upsert', 'delete')),
    task JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS changes_sequence_idx ON changes(sequence);
