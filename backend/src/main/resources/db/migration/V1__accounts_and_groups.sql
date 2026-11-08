-- Phase 3: accounts, family groups (Messenger-style), invites, device sessions.
-- See docs/SKILL_AN_TAM.md §5–6. Timestamps are UTC (timestamptz).

CREATE TABLE users (
    id             BIGSERIAL PRIMARY KEY,
    account_type   VARCHAR(16)  NOT NULL CHECK (account_type IN ('CAREGIVER', 'ELDER', 'SYSTEM_ADMIN')),
    email          VARCHAR(254) UNIQUE,
    password_hash  VARCHAR(100),
    display_name   VARCHAR(100) NOT NULL,
    phone          VARCHAR(20),
    disabled       BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    -- Caregivers and admins sign in with email + password; elders only through device pairing.
    CONSTRAINT users_credentials_by_type CHECK (
        (account_type = 'ELDER' AND email IS NULL AND password_hash IS NULL)
        OR (account_type <> 'ELDER' AND email IS NOT NULL AND password_hash IS NOT NULL)
    )
);

CREATE TABLE family_groups (
    id                BIGSERIAL PRIMARY KEY,
    name              VARCHAR(100) NOT NULL,
    schedule_version  BIGINT       NOT NULL DEFAULT 0,
    created_by        BIGINT       NOT NULL REFERENCES users (id),
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at        TIMESTAMPTZ
);

CREATE TABLE group_members (
    id         BIGSERIAL PRIMARY KEY,
    group_id   BIGINT      NOT NULL REFERENCES family_groups (id),
    user_id    BIGINT      NOT NULL REFERENCES users (id),
    role       VARCHAR(8)  NOT NULL CHECK (role IN ('OWNER', 'MEMBER', 'ELDER')),
    joined_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    left_at    TIMESTAMPTZ
);

-- One active membership per person per group.
CREATE UNIQUE INDEX group_members_active_user_in_group
    ON group_members (group_id, user_id) WHERE left_at IS NULL;
-- Exactly one active owner per group (the "at least one" half is enforced by the service).
CREATE UNIQUE INDEX group_members_one_owner
    ON group_members (group_id) WHERE role = 'OWNER' AND left_at IS NULL;
-- An elder belongs to exactly one active group.
CREATE UNIQUE INDEX group_members_elder_one_group
    ON group_members (user_id) WHERE role = 'ELDER' AND left_at IS NULL;
CREATE INDEX group_members_by_user ON group_members (user_id) WHERE left_at IS NULL;

CREATE TABLE elder_profiles (
    user_id      BIGINT PRIMARY KEY REFERENCES users (id),
    group_id     BIGINT       NOT NULL REFERENCES family_groups (id),
    call_name    VARCHAR(60)  NOT NULL,
    birth_year   SMALLINT CHECK (birth_year BETWEEN 1900 AND 2100),
    phone        VARCHAR(20),
    health_note  VARCHAR(500),
    timezone     VARCHAR(40)  NOT NULL DEFAULT 'Asia/Ho_Chi_Minh'
);

-- Pairing codes (6 digits, elder device) and member invites. Only an HMAC of the code is stored.
CREATE TABLE invites (
    id             BIGSERIAL PRIMARY KEY,
    kind           VARCHAR(16) NOT NULL CHECK (kind IN ('ELDER_DEVICE', 'MEMBER')),
    code_hash      VARCHAR(64) NOT NULL,
    group_id       BIGINT      NOT NULL REFERENCES family_groups (id),
    elder_user_id  BIGINT REFERENCES users (id),
    created_by     BIGINT      NOT NULL REFERENCES users (id),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at     TIMESTAMPTZ NOT NULL,
    used_at        TIMESTAMPTZ,
    used_by        BIGINT REFERENCES users (id),
    CONSTRAINT invites_elder_code_has_elder CHECK ((kind = 'ELDER_DEVICE') = (elder_user_id IS NOT NULL))
);
CREATE INDEX invites_by_code ON invites (code_hash) WHERE used_at IS NULL;

CREATE TABLE refresh_tokens (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT      NOT NULL REFERENCES users (id),
    token_hash  VARCHAR(64) NOT NULL UNIQUE,
    device_name VARCHAR(100),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at  TIMESTAMPTZ NOT NULL,
    revoked_at  TIMESTAMPTZ,
    -- Set when the token was exchanged for a new one. Presenting a rotated token again means replay
    -- (stolen token), unlike a token revoked by logout or by pairing a new phone.
    rotated_at  TIMESTAMPTZ
);
CREATE INDEX refresh_tokens_by_user ON refresh_tokens (user_id) WHERE revoked_at IS NULL;
