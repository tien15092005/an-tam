-- Phase 4: medications with times, identification photos, dose history, audit trail.
-- See docs/SKILL_AN_TAM.md §6, §8.

CREATE TABLE medications (
    id                BIGSERIAL PRIMARY KEY,
    group_id          BIGINT       NOT NULL REFERENCES family_groups (id),
    elder_user_id     BIGINT       NOT NULL REFERENCES users (id),
    -- Editing a medication that already has history closes the old row and starts a new one
    -- with the same series_id, so past doses keep the schedule they were taken under.
    series_id         UUID         NOT NULL,
    name              VARCHAR(120) NOT NULL,
    strength          VARCHAR(60),
    dosage            VARCHAR(60),
    note              VARCHAR(300),
    shape             VARCHAR(40),
    color             VARCHAR(40),
    imprint           VARCHAR(40),
    pill_description  VARCHAR(300),
    -- Bitmask of ISO weekdays: bit 0 = Monday ... bit 6 = Sunday. 127 = every day.
    days_of_week      SMALLINT     NOT NULL DEFAULT 127 CHECK (days_of_week BETWEEN 1 AND 127),
    start_date        DATE         NOT NULL,
    end_date          DATE,
    active            BOOLEAN      NOT NULL DEFAULT TRUE,
    source            VARCHAR(20)  NOT NULL DEFAULT 'MANUAL'
                      CHECK (source IN ('MANUAL', 'OCR_PRESCRIPTION', 'OCR_PACKAGE', 'OCR_INVOICE')),
    created_by        BIGINT       NOT NULL REFERENCES users (id),
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by        BIGINT REFERENCES users (id),
    updated_at        TIMESTAMPTZ,
    CONSTRAINT medications_dates CHECK (end_date IS NULL OR end_date >= start_date)
);
CREATE INDEX medications_by_elder ON medications (elder_user_id) WHERE active;
CREATE INDEX medications_by_series ON medications (series_id);

CREATE TABLE medication_times (
    id             BIGSERIAL PRIMARY KEY,
    medication_id  BIGINT NOT NULL REFERENCES medications (id) ON DELETE CASCADE,
    time_of_day    TIME   NOT NULL,
    CONSTRAINT medication_times_unique UNIQUE (medication_id, time_of_day)
);

CREATE TABLE medication_images (
    id             BIGSERIAL PRIMARY KEY,
    medication_id  BIGINT       NOT NULL REFERENCES medications (id),
    kind           VARCHAR(10)  NOT NULL CHECK (kind IN ('PILL', 'PACKAGE')),
    storage_key    VARCHAR(80)  NOT NULL UNIQUE,
    mime_type      VARCHAR(40)  NOT NULL,
    size_bytes     INT          NOT NULL,
    sha256         VARCHAR(64)  NOT NULL,
    sort_order     INT          NOT NULL DEFAULT 0,
    created_by     BIGINT       NOT NULL REFERENCES users (id),
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at     TIMESTAMPTZ
);
CREATE INDEX medication_images_by_medication ON medication_images (medication_id) WHERE deleted_at IS NULL;

-- One row per confirmed (or explicitly not taken) dose. No row + past due = "missed", computed, never stored.
CREATE TABLE dose_logs (
    id               BIGSERIAL PRIMARY KEY,
    medication_id    BIGINT       NOT NULL REFERENCES medications (id),
    elder_user_id    BIGINT       NOT NULL REFERENCES users (id),
    scheduled_date   DATE         NOT NULL,
    scheduled_time   TIME         NOT NULL,
    name_snapshot    VARCHAR(120) NOT NULL,
    dosage_snapshot  VARCHAR(60),
    status           VARCHAR(10)  NOT NULL CHECK (status IN ('TAKEN', 'NOT_TAKEN', 'SKIPPED')),
    source           VARCHAR(10)  NOT NULL CHECK (source IN ('BUTTON', 'VOICE', 'CAREGIVER')),
    check_result     VARCHAR(12)  CHECK (check_result IN ('NONE', 'ISSUE', 'NO_RESPONSE')),
    client_event_id  UUID         NOT NULL UNIQUE,
    logged_at        TIMESTAMPTZ  NOT NULL,
    logged_by        BIGINT       NOT NULL REFERENCES users (id),
    CONSTRAINT dose_logs_one_per_dose UNIQUE (medication_id, scheduled_date, scheduled_time)
);
CREATE INDEX dose_logs_by_elder_date ON dose_logs (elder_user_id, scheduled_date);

-- Who changed what in a group's schedule. "changes" is a JSON text snapshot.
CREATE TABLE audit_logs (
    id           BIGSERIAL PRIMARY KEY,
    group_id     BIGINT       NOT NULL REFERENCES family_groups (id),
    actor_id     BIGINT       NOT NULL REFERENCES users (id),
    action       VARCHAR(40)  NOT NULL,
    entity_type  VARCHAR(40)  NOT NULL,
    entity_id    BIGINT       NOT NULL,
    changes      TEXT,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX audit_logs_by_group ON audit_logs (group_id, created_at DESC);
