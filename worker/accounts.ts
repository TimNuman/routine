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
         WHERE m.user_id = ? ORDER BY m.created_at`,
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
