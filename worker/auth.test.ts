import { createExecutionContext, env, waitOnExecutionContext } from 'cloudflare:test';
import { exportJWK, generateKeyPair, SignJWT } from 'jose';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import app from './index';

// A pretend Apple and Google: one key pair, served as a JWKS where the real
// ones live, so the worker's verification runs the real code path.
const keys = await generateKeyPair('RS256', { extractable: true });
const jwk = { ...(await exportJWK(keys.publicKey)), kid: 'test-key', alg: 'RS256', use: 'sig' };

const JWKS_URLS = new Set([
  'https://appleid.apple.com/auth/keys',
  'https://www.googleapis.com/oauth2/v3/certs',
]);

beforeAll(() => {
  vi.stubGlobal('fetch', async (input: RequestInfo | URL) => {
    const url = String(input instanceof Request ? input.url : input);
    if (!JWKS_URLS.has(url)) throw new Error('unexpected fetch: ' + url);
    return new Response(JSON.stringify({ keys: [jwk] }), { headers: { 'Content-Type': 'application/json' } });
  });
});
afterAll(() => vi.unstubAllGlobals());

interface TokenOptions {
  issuer?: string;
  audience?: string;
  expiresIn?: string;
  email?: string;
  emailVerified?: boolean | string;
  kid?: string;
}

async function idToken(provider: 'apple' | 'google', subject: string, options: TokenOptions = {}) {
  const issuer =
    options.issuer ?? (provider === 'apple' ? 'https://appleid.apple.com' : 'https://accounts.google.com');
  const audience = options.audience ?? (provider === 'apple' ? env.APPLE_BUNDLE_ID : env.GOOGLE_CLIENT_ID);
  return await new SignJWT({ email: options.email, email_verified: options.emailVerified ?? true })
    .setProtectedHeader({ alg: 'RS256', kid: options.kid ?? 'test-key' })
    .setIssuer(issuer)
    .setAudience(audience)
    .setSubject(subject)
    .setIssuedAt()
    .setExpirationTime(options.expiresIn ?? '1h')
    .sign(keys.privateKey);
}

async function call(path: string, init: RequestInit = {}, extra: Partial<Env> = {}) {
  const ctx = createExecutionContext();
  const res = await app.fetch(new Request('https://house' + path, init), { ...env, ...extra }, ctx);
  await waitOnExecutionContext(ctx);
  return res;
}

const post = (path: string, body: unknown, token?: string) =>
  call(path, {
    method: 'POST',
    body: JSON.stringify(body),
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) },
  });

const withToken = (token: string, init: RequestInit = {}): RequestInit => ({
  ...init,
  headers: { ...(init.headers as Record<string, string>), Authorization: 'Bearer ' + token },
});

interface Session {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  user: { id: string; email: string | null; name: string | null };
  homes: { id: string; name: string; role: string }[];
}

async function signIn(provider: 'apple' | 'google', subject: string, extra: Record<string, unknown> = {}) {
  const res = await post('/api/v2/auth/sign-in', {
    provider,
    idToken: await idToken(provider, subject, extra),
    ...extra,
  });
  expect(res.status).toBe(200);
  return (await res.json()) as Session;
}

describe('signing in', () => {
  it('creates an account from an Apple id token', async () => {
    const s = await signIn('apple', 'apple-1', { email: 'emma@example.com', name: 'Emma' });
    expect(s.user).toEqual({ id: expect.any(String), email: 'emma@example.com', name: 'Emma' });
    expect(s.homes).toEqual([{ id: expect.any(String), name: 'Thuis', role: 'owner' }]);
    expect(s.expiresIn).toBe(3600);
    expect(s.accessToken.split('.')).toHaveLength(3);
    expect(s.refreshToken.length).toBeGreaterThan(30);
  });

  it('finds the same account again, and fills in a name it learns later', async () => {
    const first = await signIn('google', 'google-1');
    expect(first.user.name).toBeNull();
    const again = await signIn('google', 'google-1', { name: 'Mads' });
    expect(again.user.id).toBe(first.user.id);
    expect(again.user.name).toBe('Mads');
    expect(again.homes).toEqual(first.homes);
  });

  it('ignores an unverified email', async () => {
    const s = await signIn('apple', 'apple-2', { email: 'nope@example.com', emailVerified: false });
    expect(s.user.email).toBeNull();
  });

  it('refuses a token for another app', async () => {
    const res = await post('/api/v2/auth/sign-in', {
      provider: 'apple',
      idToken: await idToken('apple', 'x', { audience: 'com.other.app' }),
    });
    expect(res.status).toBe(401);
    expect(((await res.json()) as { error: string }).error).toMatch(/not valid/);
  });

  it('refuses an expired token, a wrong issuer, and an unknown key', async () => {
    const bad: TokenOptions[] = [{ expiresIn: '-1s' }, { issuer: 'https://evil.example' }, { kid: 'other' }];
    const results = await Promise.all(
      bad.map(async (options) =>
        post('/api/v2/auth/sign-in', { provider: 'google', idToken: await idToken('google', 'x', options) }),
      ),
    );
    expect(results.map((res) => res.status)).toEqual([401, 401, 401]);
  });

  it('refuses junk', async () => {
    expect((await post('/api/v2/auth/sign-in', { provider: 'facebook', idToken: 'x' })).status).toBe(400);
    expect((await post('/api/v2/auth/sign-in', { provider: 'apple' })).status).toBe(400);
    expect((await post('/api/v2/auth/sign-in', { provider: 'apple', idToken: 'not.a.jwt' })).status).toBe(
      401,
    );
  });

  it('says so when a provider is not configured', async () => {
    const ctx = createExecutionContext();
    const res = await app.fetch(
      new Request('https://house/api/v2/auth/sign-in', {
        method: 'POST',
        body: JSON.stringify({ provider: 'google', idToken: await idToken('google', 'x') }),
      }),
      { ...env, GOOGLE_CLIENT_ID: '' },
      ctx,
    );
    expect(res.status).toBe(500);
    expect(await res.json()).toEqual({ error: 'Sign-in with google is not configured.' });
  });

  it('is off without a proper AUTH_SECRET', async () => {
    const res = await call(
      '/api/v2/auth/sign-in',
      { method: 'POST', body: JSON.stringify({ provider: 'apple', idToken: await idToken('apple', 'x') }) },
      { AUTH_SECRET: 'short' },
    );
    expect(res.status).toBe(500);
  });
});

describe('the access token', () => {
  it('opens /me', async () => {
    const s = await signIn('apple', 'apple-me', { name: 'Emma' });
    const res = await call('/api/v2/me', withToken(s.accessToken));
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ user: s.user, homes: s.homes });
  });

  it('is required, and checked', async () => {
    expect((await call('/api/v2/me')).status).toBe(401);
    expect((await call('/api/v2/me', withToken('garbage'))).status).toBe(401);
    const s = await signIn('apple', 'apple-other-secret');
    const other = await call('/api/v2/me', withToken(s.accessToken), {
      AUTH_SECRET: 'a-different-secret-of-enough-length',
    });
    expect(other.status).toBe(401);
  });
});

describe('the refresh token', () => {
  it('trades for a new pair, once', async () => {
    const s = await signIn('google', 'google-refresh');
    const res = await post('/api/v2/auth/refresh', { refreshToken: s.refreshToken });
    expect(res.status).toBe(200);
    const next = (await res.json()) as Session;
    expect(next.refreshToken).not.toBe(s.refreshToken);
    expect((await call('/api/v2/me', withToken(next.accessToken))).status).toBe(200);

    const reuse = await post('/api/v2/auth/refresh', { refreshToken: s.refreshToken });
    expect(reuse.status).toBe(401);
  });

  it('dies on sign-out', async () => {
    const s = await signIn('google', 'google-out');
    expect((await post('/api/v2/auth/sign-out', { refreshToken: s.refreshToken })).status).toBe(200);
    expect((await post('/api/v2/auth/refresh', { refreshToken: s.refreshToken })).status).toBe(401);
  });

  it('refuses nonsense', async () => {
    expect((await post('/api/v2/auth/refresh', {})).status).toBe(400);
    expect((await post('/api/v2/auth/refresh', { refreshToken: 'never-issued' })).status).toBe(401);
  });
});

describe('homes', () => {
  it('can be created, and then show up', async () => {
    const s = await signIn('apple', 'apple-home');
    const res = await post('/api/v2/homes', { name: '  Ons huis  ' }, s.accessToken);
    expect(res.status).toBe(201);
    const { home } = (await res.json()) as { home: { id: string; name: string; role: string } };
    expect(home).toEqual({ id: expect.any(String), name: 'Ons huis', role: 'owner' });

    const me = (await (await call('/api/v2/me', withToken(s.accessToken))).json()) as Session;
    expect(me.homes).toEqual([home, ...s.homes]);
  });

  it('need a name and a user', async () => {
    const s = await signIn('apple', 'apple-home-2');
    expect((await post('/api/v2/homes', { name: '' }, s.accessToken)).status).toBe(400);
    expect((await post('/api/v2/homes', { name: 'x' })).status).toBe(401);
  });

  it('keep their house to their members', async () => {
    const owner = await signIn('apple', 'apple-owner');
    const stranger = await signIn('apple', 'apple-stranger');
    const { home } = (await (await post('/api/v2/homes', { name: 'Thuis' }, owner.accessToken)).json()) as {
      home: { id: string };
    };
    const path = `/api/v2/homes/${home.id}/storage`;

    const put = await call(
      path + '/content',
      withToken(owner.accessToken, { method: 'PUT', body: JSON.stringify({ version: 2, title: 'Thuis' }) }),
    );
    expect(put.status).toBe(200);
    const got = await (await call(path + '/content', withToken(owner.accessToken))).json();
    expect(got).toEqual({ content: { version: 2, title: 'Thuis' } });

    expect((await call(path + '/content', withToken(stranger.accessToken))).status).toBe(403);
    expect((await call(path + '/content')).status).toBe(401);
    expect(
      (await call('/api/v2/homes/no-such-home/storage/content', withToken(owner.accessToken))).status,
    ).toBe(403);
  });

  it('start as a copy of the shared household, for now', async () => {
    const legacy = { version: 2, title: 'Het oude huis', people: [{ id: 'emma' }] };
    await call('/api/v2/storage/content', { method: 'PUT', body: JSON.stringify(legacy) });

    const s = await signIn('apple', 'apple-seeded');
    const { home } = (await (await post('/api/v2/homes', { name: 'Nieuw' }, s.accessToken)).json()) as {
      home: { id: string };
    };
    const got = await (
      await call(`/api/v2/homes/${home.id}/storage/content`, withToken(s.accessToken))
    ).json();
    expect(got).toEqual({ content: legacy });

    const bare = await signIn('apple', 'apple-unseeded');
    const ctx = createExecutionContext();
    const created = await app.fetch(
      new Request('https://house/api/v2/homes', {
        method: 'POST',
        body: JSON.stringify({ name: 'Leeg' }),
        headers: { Authorization: 'Bearer ' + bare.accessToken },
      }),
      { ...env, HOUSEHOLD: '' },
      ctx,
    );
    const empty = ((await created.json()) as { home: { id: string } }).home;
    const nothing = await (
      await call(`/api/v2/homes/${empty.id}/storage/content`, withToken(bare.accessToken))
    ).json();
    expect(nothing).toEqual({ content: null });
  });

  it('each have their own house', async () => {
    const s = await signIn('apple', 'apple-two-homes');
    const a = (await (await post('/api/v2/homes', { name: 'A' }, s.accessToken)).json()) as {
      home: { id: string };
    };
    const b = (await (await post('/api/v2/homes', { name: 'B' }, s.accessToken)).json()) as {
      home: { id: string };
    };
    await call(
      `/api/v2/homes/${a.home.id}/storage/content`,
      withToken(s.accessToken, { method: 'PUT', body: JSON.stringify({ title: 'A' }) }),
    );
    const other = await (
      await call(`/api/v2/homes/${b.home.id}/storage/content`, withToken(s.accessToken))
    ).json();
    expect((other as { content: { title?: string } | null }).content?.title).not.toBe('A');
  });

  it('stream with the same token', async () => {
    const s = await signIn('apple', 'apple-stream');
    const { home } = (await (await post('/api/v2/homes', { name: 'S' }, s.accessToken)).json()) as {
      home: { id: string };
    };
    const res = await call(
      `/api/v2/homes/${home.id}/storage/stream`,
      withToken(s.accessToken, { headers: { Upgrade: 'websocket' } }),
    );
    expect(res.status).toBe(101);
    res.webSocket?.accept();
    res.webSocket?.close();
  });
});

describe('invites', () => {
  async function ownerWithHome() {
    const owner = await signIn('apple', 'apple-inviter-' + crypto.randomUUID());
    const home = owner.homes[0]!;
    return { owner, home };
  }

  async function makeCode(owner: Session, homeId: string) {
    const res = await post(`/api/v2/homes/${homeId}/invites`, {}, owner.accessToken);
    expect(res.status).toBe(201);
    return (await res.json()) as { code: string; expiresAt: string };
  }

  it('let someone into the home, once', async () => {
    const { owner, home } = await ownerWithHome();
    const { code, expiresAt } = await makeCode(owner, home.id);
    expect(code).toMatch(/^[A-HJ-NP-Z2-9]{8}$/);
    expect(new Date(expiresAt).getTime()).toBeGreaterThan(Date.now() + 6 * 24 * 3600 * 1000);

    const guest = await signIn('google', 'google-guest-' + crypto.randomUUID());
    const typed = code.slice(0, 4).toLowerCase() + '-' + code.slice(4);
    const accepted = await post(`/api/v2/invites/${typed}/accept`, {}, guest.accessToken);
    expect(accepted.status).toBe(200);
    expect(await accepted.json()).toEqual({ home: { id: home.id, name: home.name, role: 'member' } });

    const content = await call(`/api/v2/homes/${home.id}/storage/content`, withToken(guest.accessToken));
    expect(content.status).toBe(200);

    // The joined home comes first, so the app shows it.
    const me = (await (await call('/api/v2/me', withToken(guest.accessToken))).json()) as Session;
    expect(me.homes[0]?.id).toBe(home.id);
    expect(me.homes).toHaveLength(2);

    const again = await post(`/api/v2/invites/${code}/accept`, {}, guest.accessToken);
    expect(((await again.json()) as { already?: boolean }).already).toBe(true);

    const other = await signIn('google', 'google-late-' + crypto.randomUUID());
    const late = await post(`/api/v2/invites/${code}/accept`, {}, other.accessToken);
    expect(late.status).toBe(410);
  });

  it('list the members', async () => {
    const { owner, home } = await ownerWithHome();
    const { code } = await makeCode(owner, home.id);
    const guest = await signIn('google', 'google-member-' + crypto.randomUUID(), { name: 'Mads' });
    await post(`/api/v2/invites/${code}/accept`, {}, guest.accessToken);

    const res = await call(`/api/v2/homes/${home.id}/members`, withToken(guest.accessToken));
    const { members } = (await res.json()) as {
      members: { id: string; role: string; name: string | null }[];
    };
    expect(members.map((m) => [m.id, m.role])).toEqual([
      [owner.user.id, 'owner'],
      [guest.user.id, 'member'],
    ]);
  });

  it('let everyone pick their own face and name, and the owner remove people', async () => {
    const { owner, home } = await ownerWithHome();
    const { code } = await makeCode(owner, home.id);
    const guest = await signIn('google', 'google-papa-' + crypto.randomUUID());
    await post(`/api/v2/invites/${code}/accept`, {}, guest.accessToken);

    const me = await call(`/api/v2/homes/${home.id}/members/me`, {
      method: 'PUT',
      body: JSON.stringify({ nickname: ' papa ', emoji: '🧔', color: '#7c6bd6', extra: 'x' }),
      headers: { Authorization: 'Bearer ' + guest.accessToken },
    });
    expect(me.status).toBe(200);
    const { members } = (await me.json()) as { members: Record<string, unknown>[] };
    expect(members[1]).toMatchObject({ id: guest.user.id, nickname: 'papa', emoji: '🧔', color: '#7C6BD6' });

    const badColor = await call(`/api/v2/homes/${home.id}/members/me`, {
      method: 'PUT',
      body: JSON.stringify({ nickname: 'papa', color: 'blue' }),
      headers: { Authorization: 'Bearer ' + guest.accessToken },
    });
    const cleaned = (await badColor.json()) as { members: Record<string, unknown>[] };
    expect(cleaned.members[1]?.color).toBeNull();

    const notMine = await call(`/api/v2/homes/${home.id}/members/${owner.user.id}`, {
      method: 'PUT',
      body: JSON.stringify({ nickname: 'hacked' }),
      headers: { Authorization: 'Bearer ' + guest.accessToken },
    });
    expect(notMine.status).toBe(403);

    const guestRemoves = await call(`/api/v2/homes/${home.id}/members/${owner.user.id}`, {
      method: 'DELETE',
      headers: { Authorization: 'Bearer ' + guest.accessToken },
    });
    expect(guestRemoves.status).toBe(403);

    const ownerLeaves = await call(`/api/v2/homes/${home.id}/members/${owner.user.id}`, {
      method: 'DELETE',
      headers: { Authorization: 'Bearer ' + owner.accessToken },
    });
    expect(ownerLeaves.status).toBe(400);

    const removed = await call(`/api/v2/homes/${home.id}/members/${guest.user.id}`, {
      method: 'DELETE',
      headers: { Authorization: 'Bearer ' + owner.accessToken },
    });
    expect(removed.status).toBe(200);
    expect(((await removed.json()) as { members: unknown[] }).members).toHaveLength(1);
    expect(
      (await call(`/api/v2/homes/${home.id}/storage/content`, withToken(guest.accessToken))).status,
    ).toBe(403);
  });

  it('refuse a wrong, expired, or unauthenticated code', async () => {
    const { owner, home } = await ownerWithHome();
    const guest = await signIn('google', 'google-refused-' + crypto.randomUUID());
    expect((await post('/api/v2/invites/NOPE1234/accept', {}, guest.accessToken)).status).toBe(404);
    expect((await post('/api/v2/invites/NOPE1234/accept', {})).status).toBe(401);

    const { code } = await makeCode(owner, home.id);
    await env.DB.prepare('UPDATE invites SET expires_at = ? WHERE code = ?')
      .bind('2020-01-01T00:00:00Z', code)
      .run();
    const expired = await post(`/api/v2/invites/${code}/accept`, {}, guest.accessToken);
    expect(expired.status).toBe(410);
    expect(await expired.json()).toEqual({ error: 'That code has expired.' });
  });

  it('can only be made by a member', async () => {
    const { home } = await ownerWithHome();
    const stranger = await signIn('google', 'google-stranger-' + crypto.randomUUID());
    expect((await post(`/api/v2/homes/${home.id}/invites`, {}, stranger.accessToken)).status).toBe(403);
  });
});

describe('the assistant', () => {
  it('lets a signed-in user in without the shared key', async () => {
    const s = await signIn('apple', 'apple-reader');
    const res = await post('/api/v2/read', { text: '' }, s.accessToken);
    expect(res.status).toBe(200);
    const locked = await call(
      '/api/v2/read',
      {
        method: 'POST',
        body: JSON.stringify({ text: '' }),
        headers: { Authorization: 'Bearer ' + s.accessToken },
      },
      { SLEUTEL: 's3cret' },
    );
    expect(locked.status).toBe(200);
  });
});

describe('the shared-key path', () => {
  it('is gone when no household is configured', async () => {
    expect((await call('/api/v2/storage/content', {}, { HOUSEHOLD: '' })).status).toBe(410);
  });
});
