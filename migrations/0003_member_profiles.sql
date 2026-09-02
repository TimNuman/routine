-- How the children know this person: "papa", a face, a colour. Per home, so
-- the same person can be "opa" in one home and "papa" in another.
ALTER TABLE memberships ADD COLUMN nickname TEXT;
ALTER TABLE memberships ADD COLUMN emoji TEXT;
ALTER TABLE memberships ADD COLUMN color TEXT;
