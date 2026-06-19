ALTER TABLE users ADD COLUMN pronouns TEXT;
ALTER TABLE users ADD COLUMN email_verified BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE users ADD COLUMN is_admin BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE email_verifications (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE photos (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  file_path TEXT NOT NULL,
  position INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE categories (
  id SERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  status TEXT NOT NULL DEFAULT 'approved' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE user_categories (
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, category_id)
);

INSERT INTO categories (name, status) VALUES
  ('Bikers', 'approved'),
  ('Rock', 'approved'),
  ('Metal', 'approved'),
  ('Pop', 'approved'),
  ('Hip-Hop', 'approved'),
  ('Electronic', 'approved'),
  ('Jazz', 'approved'),
  ('Country', 'approved'),
  ('Gaming', 'approved'),
  ('Hiking', 'approved'),
  ('Travel', 'approved'),
  ('Foodie', 'approved'),
  ('Fitness', 'approved'),
  ('Yoga', 'approved'),
  ('Art', 'approved'),
  ('Photography', 'approved'),
  ('Movies', 'approved'),
  ('Anime', 'approved'),
  ('Books', 'approved'),
  ('Tattoos', 'approved'),
  ('Cars', 'approved'),
  ('Pets', 'approved'),
  ('Dancing', 'approved'),
  ('Tech', 'approved'),
  ('Outdoors', 'approved'),
  ('Festivals', 'approved'),
  ('Sports', 'approved'),
  ('Cooking', 'approved'),
  ('Spirituality', 'approved'),
  ('Nightlife', 'approved');
