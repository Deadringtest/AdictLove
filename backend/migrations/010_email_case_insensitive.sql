-- Normalize existing emails to lowercase, then enforce case-insensitive
-- uniqueness at the DB level so the app-level check can't be raced.
UPDATE users SET email = lower(email);
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_email_key;
CREATE UNIQUE INDEX IF NOT EXISTS users_email_lower_key ON users (lower(email));
