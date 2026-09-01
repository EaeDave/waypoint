CREATE TABLE holiday_entries (
    source TEXT NOT NULL,
    source_key TEXT NOT NULL,
    holiday_date DATE NOT NULL,
    holiday_year INTEGER NOT NULL CHECK (holiday_year >= 2000),
    name TEXT NOT NULL CHECK (length(trim(name)) > 0),
    description TEXT,
    kind TEXT NOT NULL CHECK (kind IN ('legal', 'commemorative', 'optional')),
    scope_level TEXT NOT NULL CHECK (scope_level IN ('national', 'state', 'municipal')),
    state_code CHAR(2),
    city_code TEXT,
    fetched_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (source, source_key),
    CHECK (scope_level <> 'state' OR state_code IS NOT NULL),
    CHECK (scope_level <> 'municipal' OR (state_code IS NOT NULL AND city_code IS NOT NULL))
);

CREATE INDEX holiday_entries_date_idx ON holiday_entries(holiday_date);
CREATE INDEX holiday_entries_year_scope_idx ON holiday_entries(holiday_year, scope_level);
CREATE INDEX holiday_entries_location_idx ON holiday_entries(state_code, city_code, holiday_year);

CREATE TABLE holiday_source_snapshots (
    source TEXT NOT NULL,
    holiday_year INTEGER NOT NULL CHECK (holiday_year >= 2000),
    status TEXT NOT NULL CHECK (status IN ('ready', 'stale', 'unavailable', 'error')),
    checksum TEXT,
    fetched_at TIMESTAMPTZ,
    last_error TEXT,
    PRIMARY KEY (source, holiday_year)
);

CREATE TABLE brazil_municipalities (
    city_code TEXT PRIMARY KEY,
    state_code CHAR(2) NOT NULL,
    name TEXT NOT NULL CHECK (length(trim(name)) > 0),
    fetched_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX brazil_municipalities_state_name_idx ON brazil_municipalities(state_code, name);

CREATE TABLE holiday_preferences (
    singleton BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (singleton),
    state_code CHAR(2),
    city_code TEXT,
    include_national BOOLEAN NOT NULL DEFAULT TRUE,
    include_state BOOLEAN NOT NULL DEFAULT TRUE,
    include_municipal BOOLEAN NOT NULL DEFAULT TRUE,
    include_commemorative BOOLEAN NOT NULL DEFAULT TRUE,
    revision BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (city_code IS NULL OR state_code IS NOT NULL)
);

INSERT INTO holiday_preferences(singleton) VALUES (TRUE) ON CONFLICT(singleton) DO NOTHING;
