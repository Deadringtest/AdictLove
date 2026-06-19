CREATE TABLE prompts (
  id SERIAL PRIMARY KEY,
  text TEXT NOT NULL
);

INSERT INTO prompts (text) VALUES
  ('A weekend looks perfect when...'),
  ('My most useless skill is...'),
  ('I will fall for you if...'),
  ('Two truths and a lie...'),
  ('My ideal first date is...'),
  ('Unpopular opinion:...');

CREATE TABLE user_prompts (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  prompt_id INTEGER NOT NULL REFERENCES prompts(id),
  answer TEXT NOT NULL,
  position INTEGER NOT NULL DEFAULT 0,
  UNIQUE (user_id, prompt_id)
);

ALTER TABLE users ADD COLUMN last_streak_milestone INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN verification_pose TEXT;

-- Premium tier groundwork only -- not sold or enforced anywhere yet.
ALTER TABLE users ADD COLUMN premium_until TIMESTAMPTZ;
