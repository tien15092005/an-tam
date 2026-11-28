-- Forgotten passwords are reset with a one-time code that another child in the family creates (no e-mail).
CREATE TABLE password_resets (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users (id),
    code_hash  VARCHAR(64) NOT NULL,
    created_by BIGINT      NOT NULL REFERENCES users (id),
    created_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at    TIMESTAMPTZ
);
CREATE INDEX password_resets_open ON password_resets (user_id) WHERE used_at IS NULL;

-- Same columns as dose_logs_by_elder_date (V2): one index is enough.
DROP INDEX IF EXISTS dose_logs_by_elder_day;

-- Photo files already removed from disk are not deleted again every 12 hours.
ALTER TABLE medication_images ADD COLUMN file_purged_at TIMESTAMPTZ;
