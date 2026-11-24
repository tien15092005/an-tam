-- The teacher ruled group chat out of scope: alerts and reports stay on the "Hôm nay" tab and in push notifications.
-- V6 stays as history; this removes its tables and any queued chat pushes.

DELETE FROM notification_outbox WHERE kind = 'CHAT';
DROP TABLE chat_read_states;
DROP TABLE chat_messages;
