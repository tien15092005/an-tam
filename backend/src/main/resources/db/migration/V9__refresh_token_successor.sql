-- Which token a refresh token was exchanged for. Lets the server tell a lost refresh reply on a bad
-- network (same token sent again within a short grace period, successor never used) from a stolen copy.
ALTER TABLE refresh_tokens ADD COLUMN replaced_by BIGINT REFERENCES refresh_tokens (id) ON DELETE SET NULL;
