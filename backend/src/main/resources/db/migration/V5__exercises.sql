-- Phase 7: exercise reminders (plan §6, §9). Same shape as medications: weekday mask, date range, soft delete.

CREATE TABLE exercises (
    id            BIGSERIAL PRIMARY KEY,
    group_id      BIGINT       NOT NULL REFERENCES family_groups (id),
    elder_user_id BIGINT       NOT NULL REFERENCES users (id),
    series_id     UUID         NOT NULL,
    title         VARCHAR(120) NOT NULL,
    time_of_day   TIME         NOT NULL,
    -- bit 0 = Monday ... bit 6 = Sunday, like medications.days_of_week
    days_of_week  SMALLINT     NOT NULL CHECK (days_of_week BETWEEN 1 AND 127),
    duration_min  SMALLINT     CHECK (duration_min BETWEEN 1 AND 240),
    note          VARCHAR(300),
    start_date    DATE         NOT NULL,
    end_date      DATE,
    active        BOOLEAN      NOT NULL DEFAULT true,
    created_by    BIGINT       NOT NULL REFERENCES users (id),
    created_at    TIMESTAMPTZ  NOT NULL,
    updated_by    BIGINT       REFERENCES users (id),
    updated_at    TIMESTAMPTZ,
    CHECK (end_date IS NULL OR end_date >= start_date)
);
CREATE INDEX exercises_by_elder ON exercises (elder_user_id) WHERE active;

-- "TÔI ĐI TẬP ĐÂY": one per exercise and day, resent safely from the offline queue.
CREATE TABLE exercise_logs (
    id              BIGSERIAL PRIMARY KEY,
    exercise_id     BIGINT       NOT NULL REFERENCES exercises (id),
    elder_user_id   BIGINT       NOT NULL REFERENCES users (id),
    scheduled_date  DATE         NOT NULL,
    title_snapshot  VARCHAR(120) NOT NULL,
    source          VARCHAR(10)  NOT NULL CHECK (source IN ('BUTTON', 'VOICE', 'CAREGIVER')),
    client_event_id UUID         NOT NULL UNIQUE,
    logged_at       TIMESTAMPTZ  NOT NULL,
    logged_by       BIGINT       NOT NULL REFERENCES users (id),
    CONSTRAINT exercise_logs_one_per_day UNIQUE (exercise_id, scheduled_date)
);
CREATE INDEX exercise_logs_by_elder_date ON exercise_logs (elder_user_id, scheduled_date);
