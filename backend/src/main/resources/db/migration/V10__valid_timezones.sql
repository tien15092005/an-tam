-- Time zones are now validated on input. Repair rows saved before that with a name nobody knows,
-- so they get the app's default instead of breaking schedules and alerts.
UPDATE elder_profiles SET timezone = 'Asia/Ho_Chi_Minh'
WHERE timezone IS NULL OR timezone NOT IN (SELECT name FROM pg_timezone_names);
