CREATE TABLE sync_devices (
    device_id TEXT PRIMARY KEY,
    platform TEXT NOT NULL CHECK (platform IN ('android')),
    push_token TEXT NOT NULL UNIQUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX sync_devices_updated_at_idx ON sync_devices(updated_at);
