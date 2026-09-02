// The directory in D1: users, the identities they sign in with, homes, and who
// belongs where. Every query lives here, so the routes never see SQL.

export type Provider = 'apple' | 'google';
export type Role = 'owner' | 'member';

export interface User {
  id: string;
  email: string | null;
  name: string | null;
}

export interface Home {
  id: string;
  name: string;
  role: Role;
}

export interface Member {
  id: string;
  name: string | null;
  email: string | null;
  role: Role;
  nickname: string | null;
  emoji: string | null;
  color: string | null;
}

export interface Profile {
  nickname: string | null;
  emoji: string | null;
  color: string | null;
}

export interface Invite {
  code: string;
  homeId: string;
  expiresAt: string;
  usedAt: string | null;
}

export interface NewIdentity {
  provider: Provider;
  subject: string;
  email: string | null;
  name: string | null;
}

const now = () => new Date().toISOString();

export class Accounts {
  constructor(private readonly db: D1Database) {}

  async user(id: string): Promise<User | null> {
    return await this.db.prepare('SELECT id, email, name FROM users WHERE id = ?').bind(id).first<User>();
  }

  async byIdentity(provider: Provider, subject: string): Promise<User | null> {
    return await this.db
      .prepare(
        `SELECT u.id, u.email, u.name FROM users u
         JOIN identities i ON i.user_id = u.id
         WHERE i.provider = ? AND i.subject = ?`,
      )
      .bind(provider, subject)
      .first<User>();
  }

  /** Signs someone in for the first time: a user plus the identity they came with. */
  async signUp(identity: NewIdentity): Promise<User> {
    const user: User = { id: crypto.randomUUID(), email: identity.email, name: identity.name };
    await this.db.batch([
      this.db
        .prepare('INSERT INTO users (id, email, name, created_at) VALUES (?, ?, ?, ?)')
        .bind(user.id, user.email, user.name, now()),
      this.db
        .prepare('INSERT INTO identities (provider, subject, user_id) VALUES (?, ?, ?)')
        .bind(identity.provider, identity.subject, user.id),
    ]);
    return user;
  }

  /** Fills in what we did not know yet. Apple only sends the name once. */
  async complete(user: User, known: { email: string | null; name: string | null }): Promise<User> {
    const email = user.email ?? known.email;
    const name = user.name ?? known.name;
    if (email === user.email && name === user.name) return user;
    await this.db
      .prepare('UPDATE users SET email = ?, name = ? WHERE id = ?')
      .bind(email, name, user.id)
      .run();
    return { ...user, email, name };
  }

  async homesOf(userId: string): Promise<Home[]> {
    const { results } = await this.db
      .prepare(
        `SELECT h.id, h.name, m.role FROM homes h
         JOIN memberships m ON m.home_id = h.id
         WHERE m.user_id = ? ORDER BY m.created_at DESC`,
      )
      .bind(userId)
      .all<Home>();
    return results;
  }

  async createHome(userId: string, name: string): Promise<Home> {
    const home: Home = { id: crypto.randomUUID(), name, role: 'owner' };
    const at = now();
    await this.db.batch([
      this.db.prepare('INSERT INTO homes (id, name, created_at) VALUES (?, ?, ?)').bind(home.id, name, at),
      this.db
        .prepare('INSERT INTO memberships (home_id, user_id, role, created_at) VALUES (?, ?, ?, ?)')
        .bind(home.id, userId, home.role, at),
    ]);
    return home;
  }

  async members(homeId: string): Promise<Member[]> {
    const { results } = await this.db
      .prepare(
        `SELECT u.id, u.name, u.email, m.role, m.nickname, m.emoji, m.color FROM users u
         JOIN memberships m ON m.user_id = u.id
         WHERE m.home_id = ? ORDER BY m.created_at`,
      )
      .bind(homeId)
      .all<Member>();
    return results;
  }

  async updateMember(homeId: string, userId: string, profile: Profile): Promise<boolean> {
    const { meta } = await this.db
      .prepare('UPDATE memberships SET nickname = ?, emoji = ?, color = ? WHERE home_id = ? AND user_id = ?')
      .bind(profile.nickname, profile.emoji, profile.color, homeId, userId)
      .run();
    return meta.changes > 0;
  }

  async removeMember(homeId: string, userId: string): Promise<boolean> {
    const { meta } = await this.db
      .prepare('DELETE FROM memberships WHERE home_id = ? AND user_id = ?')
      .bind(homeId, userId)
      .run();
    return meta.changes > 0;
  }

  async createInvite(homeId: string, userId: string, code: string, expiresAt: string): Promise<Invite> {
    await this.db
      .prepare(
        'INSERT INTO invites (code, home_id, created_by, created_at, expires_at) VALUES (?, ?, ?, ?, ?)',
      )
      .bind(code, homeId, userId, now(), expiresAt)
      .run();
    return { code, homeId, expiresAt, usedAt: null };
  }

  async invite(code: string): Promise<Invite | null> {
    const row = await this.db
      .prepare('SELECT code, home_id, expires_at, used_at FROM invites WHERE code = ?')
      .bind(code)
      .first<{ code: string; home_id: string; expires_at: string; used_at: string | null }>();
    return row
      ? { code: row.code, homeId: row.home_id, expiresAt: row.expires_at, usedAt: row.used_at }
      : null;
  }

  /** Uses the code up and lets the user in. False when someone else got there first. */
  async join(code: string, userId: string): Promise<Home | null> {
    const at = now();
    const used = await this.db
      .prepare(
        `UPDATE invites SET used_by = ?, used_at = ?
         WHERE code = ? AND used_at IS NULL AND expires_at > ? RETURNING home_id`,
      )
      .bind(userId, at, code, at)
      .first<{ home_id: string }>();
    if (!used) return null;
    await this.db
      .prepare('INSERT OR IGNORE INTO memberships (home_id, user_id, role, created_at) VALUES (?, ?, ?, ?)')
      .bind(used.home_id, userId, 'member', at)
      .run();
    const home = await this.db
      .prepare('SELECT id, name FROM homes WHERE id = ?')
      .bind(used.home_id)
      .first<Home>();
    return home ? { ...home, role: 'member' } : null;
  }

  async roleIn(homeId: string, userId: string): Promise<Role | null> {
    const row = await this.db
      .prepare('SELECT role FROM memberships WHERE home_id = ? AND user_id = ?')
      .bind(homeId, userId)
      .first<{ role: Role }>();
    return row?.role ?? null;
  }

  async storeRefresh(hash: string, userId: string, expiresAt: string): Promise<void> {
    await this.db
      .prepare('INSERT INTO refresh_tokens (hash, user_id, expires_at, created_at) VALUES (?, ?, ?, ?)')
      .bind(hash, userId, expiresAt, now())
      .run();
  }

  /** Uses a refresh token up: gone after this, whoever asked. */
  async takeRefresh(hash: string): Promise<{ userId: string } | null> {
    const row = await this.db
      .prepare('DELETE FROM refresh_tokens WHERE hash = ? RETURNING user_id, expires_at')
      .bind(hash)
      .first<{ user_id: string; expires_at: string }>();
    if (!row || row.expires_at <= now()) return null;
    return { userId: row.user_id };
  }

  async revokeRefresh(hash: string): Promise<void> {
    await this.db.prepare('DELETE FROM refresh_tokens WHERE hash = ?').bind(hash).run();
  }
}
