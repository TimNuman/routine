-- A code to hand to the other parent. One use, one week.
CREATE TABLE invites (
  code TEXT PRIMARY KEY,
  home_id TEXT NOT NULL REFERENCES homes(id),
  created_by TEXT NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  used_by TEXT REFERENCES users(id),
  used_at TEXT
);
CREATE INDEX invites_home ON invites(home_id);
