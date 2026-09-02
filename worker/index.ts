// The back end: /api/* for the iOS app. Everything else is a 404.
//
// Two ways in, for now. Signed-in users reach their homes under
// /api/v2/homes/:home/…; the old shared-key path under /api/v2/storage/… still
// serves the one house from wrangler.toml until the app has moved over.

import Anthropic from '@anthropic-ai/sdk';
import { Hono } from 'hono';
import { createMiddleware } from 'hono/factory';
import { Accounts, type User } from './accounts';
import { askAssistant, cleanPayload, NOTHING } from './assistant';
import {
  ACCESS_TTL_SECONDS,
  AuthError,
  bearer,
  hashToken,
  isProvider,
  issueAccessToken,
  newRefreshToken,
  readAccessToken,
  refreshExpiry,
  verifyIdToken,
} from './auth';
import { dateOr } from './dates';
import type { House } from './house';
import { isRoutine } from './types';
import type { Content } from './types';

export { House } from './house';

const MAX_KEY = 200;
const MAX_NAME = 80;
const MAX_CONTENT_BYTES = 512 * 1024;

type App = {
  Bindings: Env;
  Variables: {
    userId: string;
    house: DurableObjectStub<House>;
  };
};

const app = new Hono<App>();

async function body(c: { req: { json: () => Promise<unknown> } }): Promise<Record<string, unknown>> {
  try {
    const raw = await c.req.json();
    return raw && typeof raw === 'object' && !Array.isArray(raw) ? (raw as Record<string, unknown>) : {};
  } catch {
    return {};
  }
}

const text = (value: unknown, max: number) => (typeof value === 'string' ? value.trim().slice(0, max) : '');

function houseNamed(env: Env, name: string): DurableObjectStub<House> {
  return env.HOUSE.get(env.HOUSE.idFromName(name));
}

// ---- who is asking -------------------------------------------------------

/** A valid access token, or 401. */
const requireUser = createMiddleware<App>(async (c, next) => {
  const token = bearer(c.req.header('Authorization'));
  const userId = token ? await readAccessToken(token, c.env) : null;
  if (!userId) return c.json({ error: 'Sign in first.' }, 401);
  c.set('userId', userId);
  await next();
});

/** The shared key from before there were accounts. Open when none is set. */
const requireLegacyKey = createMiddleware<App>(async (c, next) => {
  const wanted = c.env.SLEUTEL;
  if (wanted && c.req.header('X-Routine-Key') !== wanted) {
    return c.json({ error: 'Wrong or missing key.' }, 401);
  }
  await next();
});

/** Either a signed-in user or the shared key. */
const requireAnyone = createMiddleware<App>(async (c, next) => {
  const token = bearer(c.req.header('Authorization'));
  const userId = token ? await readAccessToken(token, c.env) : null;
  if (userId) {
    c.set('userId', userId);
    return await next();
  }
  return await requireLegacyKey(c, next);
});

// ---- signing in ----------------------------------------------------------

async function session(user: User, accounts: Accounts, env: Env) {
  const refreshToken = newRefreshToken();
  await accounts.storeRefresh(await hashToken(refreshToken), user.id, refreshExpiry());
  return {
    accessToken: await issueAccessToken(user.id, env),
    expiresIn: ACCESS_TTL_SECONDS,
    refreshToken,
  };
}

app.post('/api/v2/auth/sign-in', async (c) => {
  const { provider, idToken, name } = await body(c);
  if (!isProvider(provider)) return c.json({ error: 'Provider must be apple or google.' }, 400);
  if (typeof idToken !== 'string' || !idToken) return c.json({ error: 'No id token.' }, 400);

  const identity = await verifyIdToken(provider, idToken, c.env);
  const accounts = new Accounts(c.env.DB);
  const known = { email: identity.email, name: text(name, MAX_NAME) || null };
  const found = await accounts.byIdentity(provider, identity.subject);
  const user = found
    ? await accounts.complete(found, known)
    : await accounts.signUp({ ...identity, ...known });

  return c.json({
    ...(await session(user, accounts, c.env)),
    user,
    homes: await accounts.homesOf(user.id),
  });
});

app.post('/api/v2/auth/refresh', async (c) => {
  const { refreshToken } = await body(c);
  if (typeof refreshToken !== 'string' || !refreshToken) return c.json({ error: 'No refresh token.' }, 400);

  const accounts = new Accounts(c.env.DB);
  const taken = await accounts.takeRefresh(await hashToken(refreshToken));
  const user = taken && (await accounts.user(taken.userId));
  if (!user) return c.json({ error: 'That refresh token is no longer valid. Sign in again.' }, 401);

  return c.json(await session(user, accounts, c.env));
});

app.post('/api/v2/auth/sign-out', async (c) => {
  const { refreshToken } = await body(c);
  if (typeof refreshToken === 'string' && refreshToken) {
    await new Accounts(c.env.DB).revokeRefresh(await hashToken(refreshToken));
  }
  return c.json({ ok: true });
});

app.get('/api/v2/me', requireUser, async (c) => {
  const accounts = new Accounts(c.env.DB);
  const user = await accounts.user(c.get('userId'));
  if (!user) return c.json({ error: 'This account no longer exists.' }, 401);
  return c.json({ user, homes: await accounts.homesOf(user.id) });
});

// ---- homes ---------------------------------------------------------------

app.post('/api/v2/homes', requireUser, async (c) => {
  const name = text((await body(c)).name, MAX_NAME);
  if (!name) return c.json({ error: 'A home needs a name.' }, 400);
  const home = await new Accounts(c.env.DB).createHome(c.get('userId'), name);
  return c.json({ home }, 201);
});

/** Signed in, and a member of this home. Puts the home's house on the context. */
app.use('/api/v2/homes/:home/*', requireUser, async (c, next) => {
  const homeId = c.req.param('home') ?? '';
  const role = await new Accounts(c.env.DB).roleIn(homeId, c.get('userId'));
  if (!role) return c.json({ error: 'Not a member of this home.' }, 403);
  c.set('house', houseNamed(c.env, 'home:' + homeId));
  await next();
});

// ---- the house -----------------------------------------------------------

const storage = new Hono<App>();

storage.get('/content', async (c) => c.json({ content: await c.get('house').getContent() }));

storage.put('/content', async (c) => {
  const length = Number(c.req.header('Content-Length') ?? 0);
  if (length > MAX_CONTENT_BYTES) return c.json({ error: 'Content too large.' }, 413);
  const raw = await body(c);
  if (!Object.keys(raw).length) return c.json({ error: 'Content must be a JSON object.' }, 400);
  await c.get('house').putContent(raw as unknown as Content);
  return c.json({ ok: true });
});

storage.get('/day', async (c) => {
  const date = dateOr(c.req.query('date'));
  return c.json({ date, checks: await c.get('house').getChecks(date) });
});

storage.put('/check', async (c) => {
  const { date, key, on } = await body(c);
  const clean = String(key ?? '').slice(0, MAX_KEY);
  if (!clean) return c.json({ error: 'No key.' }, 400);
  await c.get('house').setCheck(dateOr(date), clean, Boolean(on));
  return c.json({ ok: true });
});

storage.delete('/routine', async (c) => {
  const { date, routine } = await body(c);
  if (!isRoutine(routine)) return c.json({ error: 'Routine must be day or night.' }, 400);
  await c.get('house').clearRoutine(dateOr(date), routine);
  return c.json({ ok: true });
});

storage.get('/stream', (c) => c.get('house').fetch(c.req.raw));

app.route('/api/v2/homes/:home/storage', storage);

// The one house from wrangler.toml, behind the shared key. Goes when the app
// has moved to /homes.
app.use('/api/v2/storage/*', requireLegacyKey, async (c, next) => {
  if (!c.env.HOUSEHOLD) return c.json({ error: 'There is no shared household any more.' }, 410);
  c.set('house', houseNamed(c.env, c.env.HOUSEHOLD));
  await next();
});
app.route('/api/v2/storage', storage);

// ---- the assistant -------------------------------------------------------

app.post('/api/v2/read', requireAnyone, async (c) => {
  if (!c.env.ANTHROPIC_API_KEY) return c.json({ error: 'The assistant has no API key yet.' }, 500);

  const payload = cleanPayload(await body(c));
  if (!payload.text) return c.json(NOTHING);

  try {
    return c.json(await askAssistant(payload, c.env));
  } catch (err) {
    if (err instanceof Anthropic.AuthenticationError) {
      console.error('bad api key:', err.message);
      return c.json({ error: "The assistant's API key is wrong." }, 500);
    }
    if (err instanceof Anthropic.RateLimitError) {
      return c.json({ error: 'Too busy right now, try again in a moment.' }, 429);
    }
    if (err instanceof Anthropic.APIError) {
      console.error('api returned', err.status, err.message);
      return c.json({ error: `The Claude API returned ${err.status}: ${err.message.slice(0, 400)}` }, 502);
    }
    console.error('unexpected:', err);
    return c.json({ error: 'Something went wrong in the assistant.' }, 500);
  }
});

// ---- the rest ------------------------------------------------------------

app.notFound((c) => c.json({ error: 'Unknown address.' }, 404));

app.onError((err, c) => {
  if (err instanceof AuthError) {
    if (err.status === 500) console.error(err.message);
    return c.json({ error: err.message }, err.status);
  }
  console.error(err);
  return c.json({ error: 'The worker hit an error.' }, 500);
});

export default app;
