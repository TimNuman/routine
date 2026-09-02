-- Who there is, and which house they belong to. The houses themselves (the
-- content, the checks, the phones) live in Durable Objects; this is only the
-- directory.

CREATE TABLE users (
  id TEXT PRIMARY KEY,
  email TEXT,
  name TEXT,
  created_at TEXT NOT NULL
);

-- One user may sign in through more than one provider. The subject is what the
-- provider calls this person; it never changes.
CREATE TABLE identities (
  provider TEXT NOT NULL,
  subject TEXT NOT NULL,
  user_id TEXT NOT NULL REFERENCES users(id),
  PRIMARY KEY (provider, subject)
);
CREATE INDEX identities_user ON identities(user_id);

CREATE TABLE homes (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE memberships (
  home_id TEXT NOT NULL REFERENCES homes(id),
  user_id TEXT NOT NULL REFERENCES users(id),
  role TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (home_id, user_id)
);
CREATE INDEX memberships_user ON memberships(user_id);

-- Only a hash is kept; the token itself is on the phone. A row is deleted the
-- moment it is used, so every refresh hands out a fresh one.
CREATE TABLE refresh_tokens (
  hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX refresh_tokens_user ON refresh_tokens(user_id);
