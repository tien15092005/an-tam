-- Phase 5: what the elder reports after an alarm, and the alerts it raises for the caregivers (plan §9).

CREATE TABLE alerts (
    id               BIGSERIAL PRIMARY KEY,
    group_id         BIGINT       NOT NULL REFERENCES family_groups (id),
    elder_user_id    BIGINT       NOT NULL REFERENCES users (id),
    kind             VARCHAR(20)  NOT NULL CHECK (kind IN ('UNWELL', 'LOST_MEDICINE', 'OUT_OF_MEDICINE', 'UNSURE_PILL',
                                                           'OTHER_ISSUE', 'NOT_CONFIRMED')),
    dose_log_id      BIGINT       REFERENCES dose_logs (id),
    medication_id    BIGINT       REFERENCES medications (id),
    -- Several medicines can share one alarm; their names are kept so the alert reads well after edits.
    medication_names VARCHAR(400),
    scheduled_date   DATE,
    scheduled_time   TIME,
    -- Resending from an offline queue must not raise the same alert twice.
    client_event_id  UUID         UNIQUE,
    created_at       TIMESTAMPTZ  NOT NULL,
    resolved_at      TIMESTAMPTZ,
    resolved_by      BIGINT       REFERENCES users (id),
    CHECK ((resolved_at IS NULL) = (resolved_by IS NULL))
);

CREATE INDEX alerts_open_by_group ON alerts (group_id, created_at DESC) WHERE resolved_at IS NULL;
CREATE INDEX alerts_by_group ON alerts (group_id, created_at DESC);
CREATE INDEX dose_logs_by_elder_day ON dose_logs (elder_user_id, scheduled_date);
