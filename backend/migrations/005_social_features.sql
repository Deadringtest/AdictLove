ALTER TABLE users ADD COLUMN verification_status TEXT NOT NULL DEFAULT 'none'
  CHECK (verification_status IN ('none', 'pending', 'approved', 'rejected'));
ALTER TABLE users ADD COLUMN verification_photo TEXT;
ALTER TABLE users ADD COLUMN ticket_streak INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN last_ticket_claim DATE;
ALTER TABLE users ADD COLUMN last_mega_like_at DATE;

CREATE TABLE blocks (
  blocker_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id)
);

CREATE TABLE reports (
  id SERIAL PRIMARY KEY,
  reporter_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reported_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE messages ADD COLUMN read_at TIMESTAMPTZ;
ALTER TABLE jackpot_draws ADD COLUMN mega_like BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE matches ADD COLUMN mega_match BOOLEAN NOT NULL DEFAULT false;
