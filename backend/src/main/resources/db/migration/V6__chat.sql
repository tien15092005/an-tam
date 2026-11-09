-- Phase 9: group chat for caregivers (plan §10). Text only; system lines report alerts and schedule changes.

CREATE TABLE chat_messages (
    id                BIGSERIAL PRIMARY KEY,
    group_id          BIGINT        NOT NULL REFERENCES family_groups (id),
    -- NULL for system messages.
    sender_id         BIGINT        REFERENCES users (id),
    type              VARCHAR(10)   NOT NULL CHECK (type IN ('TEXT', 'SYSTEM')),
    body              VARCHAR(1000) NOT NULL,
    alert_id          BIGINT        REFERENCES alerts (id),
    -- The phone's id for the message, so a resend after a dropped connection is not posted twice.
    client_message_id UUID,
    created_at        TIMESTAMPTZ   NOT NULL,
    deleted_at        TIMESTAMPTZ,
    CONSTRAINT chat_messages_once UNIQUE (sender_id, client_message_id),
    CHECK ((type = 'SYSTEM') = (sender_id IS NULL))
);
CREATE INDEX chat_messages_by_group ON chat_messages (group_id, id DESC);

CREATE TABLE chat_read_states (
    group_id             BIGINT NOT NULL REFERENCES family_groups (id),
    user_id              BIGINT NOT NULL REFERENCES users (id),
    last_read_message_id BIGINT NOT NULL,
    PRIMARY KEY (group_id, user_id)
);
