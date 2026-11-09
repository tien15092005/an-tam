-- Phase 11: "Xóa tài khoản và dữ liệu" keeps an anonymous, disabled row (history and foreign keys stay valid)
-- with no email or password. Everyone else keeps the original rule.
ALTER TABLE users DROP CONSTRAINT users_credentials_by_type;
ALTER TABLE users ADD CONSTRAINT users_credentials_by_type CHECK (
    (account_type = 'ELDER' AND email IS NULL AND password_hash IS NULL)
    OR (account_type <> 'ELDER' AND email IS NOT NULL AND password_hash IS NOT NULL)
    OR (account_type <> 'ELDER' AND disabled AND email IS NULL AND password_hash IS NULL)
);
