-- Retries wait longer each time instead of every 3 seconds, and urgent alerts are retried for hours.
ALTER TABLE notification_outbox ADD COLUMN next_attempt_at TIMESTAMPTZ;
CREATE INDEX notification_outbox_due ON notification_outbox (created_at)
    WHERE status = 'PENDING';
