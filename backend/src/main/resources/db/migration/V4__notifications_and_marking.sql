-- Phase 6: phones that receive pushes, the notification outbox, and one NOT_CONFIRMED alert per dose time.

CREATE TABLE devices (
    id           BIGSERIAL PRIMARY KEY,
    user_id      BIGINT       NOT NULL REFERENCES users (id),
    -- An FCM registration token belongs to one app install; it moves to whoever signs in there last.
    fcm_token    VARCHAR(512) NOT NULL UNIQUE,
    platform     VARCHAR(10)  NOT NULL CHECK (platform IN ('ANDROID', 'IOS')),
    created_at   TIMESTAMPTZ  NOT NULL,
    last_seen_at TIMESTAMPTZ  NOT NULL
);
CREATE INDEX devices_by_user ON devices (user_id);

-- Written in the same transaction as the event it reports, sent afterwards by a background job.
-- dedupe_key makes a retried event (or a sweep run twice) produce one notification per person.
CREATE TABLE notification_outbox (
    id         BIGSERIAL PRIMARY KEY,
    dedupe_key VARCHAR(200) NOT NULL UNIQUE,
    user_id    BIGINT       NOT NULL REFERENCES users (id),
    kind       VARCHAR(30)  NOT NULL,
    group_id   BIGINT       REFERENCES family_groups (id),
    ref_id     BIGINT,
    title      VARCHAR(200),
    body       VARCHAR(500),
    urgent     BOOLEAN      NOT NULL DEFAULT false,
    status     VARCHAR(12)  NOT NULL DEFAULT 'PENDING'
               CHECK (status IN ('PENDING', 'SENT', 'NO_DEVICE', 'DISABLED', 'FAILED')),
    attempts   INT          NOT NULL DEFAULT 0,
    last_error VARCHAR(200),
    created_at TIMESTAMPTZ  NOT NULL,
    sent_at    TIMESTAMPTZ
);
CREATE INDEX notification_outbox_pending ON notification_outbox (created_at) WHERE status = 'PENDING';

-- The sweep runs every minute (and catches up after the laptop was off); this keeps it to one alert per dose time.
CREATE UNIQUE INDEX alerts_one_not_confirmed ON alerts (elder_user_id, scheduled_date, scheduled_time)
    WHERE kind = 'NOT_CONFIRMED';
