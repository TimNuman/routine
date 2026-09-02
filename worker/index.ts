// The back end: /api/* for the iOS app. Everything else is a 404.

import Anthropic from '@anthropic-ai/sdk';
import { Hono } from 'hono';
import { askAssistant, cleanPayload, NOTHING } from './assistant';
import { dateOr } from './dates';
import type { House } from './house';
import { isRoutine } from './types';
import type { Content } from './types';

export { House } from './house';

const MAX_KEY = 200;
const MAX_CONTENT_BYTES = 512 * 1024;

const app = new Hono<{ Bindings: Env }>();

// Until there are accounts, one shared key guards everything. Set SLEUTEL as a
// secret and every request must carry it in X-Routine-Key.
app.use('/api/*', async (c, next) => {
  const wanted = c.env.SLEUTEL;
  if (wanted && c.req.header('X-Routine-Key') !== wanted) {
    return c.json({ error: 'Wrong or missing key.' }, 401);
  }
  await next();
});

function house(env: Env): DurableObjectStub<House> {
  if (!env.HOUSEHOLD) throw new Error('HOUSEHOLD is not set; refusing to guess a household name.');
  return env.HOUSE.get(env.HOUSE.idFromName(env.HOUSEHOLD));
}

async function body(c: { req: { json: () => Promise<unknown> } }): Promise<Record<string, unknown>> {
  try {
    const raw = await c.req.json();
    return raw && typeof raw === 'object' && !Array.isArray(raw) ? (raw as Record<string, unknown>) : {};
  } catch {
    return {};
  }
}

const storage = new Hono<{ Bindings: Env }>();

storage.get('/content', async (c) => c.json({ content: await house(c.env).getContent() }));

storage.put('/content', async (c) => {
  const length = Number(c.req.header('Content-Length') ?? 0);
  if (length > MAX_CONTENT_BYTES) return c.json({ error: 'Content too large.' }, 413);
  const raw = await body(c);
  if (!Object.keys(raw).length) return c.json({ error: 'Content must be a JSON object.' }, 400);
  await house(c.env).putContent(raw as unknown as Content);
  return c.json({ ok: true });
});

storage.get('/day', async (c) => {
  const date = dateOr(c.req.query('date'));
  return c.json({ date, checks: await house(c.env).getChecks(date) });
});

storage.put('/check', async (c) => {
  const { date, key, on } = await body(c);
  const clean = String(key ?? '').slice(0, MAX_KEY);
  if (!clean) return c.json({ error: 'No key.' }, 400);
  await house(c.env).setCheck(dateOr(date), clean, Boolean(on));
  return c.json({ ok: true });
});

storage.delete('/routine', async (c) => {
  const { date, routine } = await body(c);
  if (!isRoutine(routine)) return c.json({ error: 'Routine must be day or night.' }, 400);
  await house(c.env).clearRoutine(dateOr(date), routine);
  return c.json({ ok: true });
});

storage.get('/stream', (c) => house(c.env).fetch(c.req.raw));

app.route('/api/v2/storage', storage);

app.post('/api/v2/read', async (c) => {
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

app.notFound((c) => c.json({ error: 'Unknown address.' }, 404));

app.onError((err, c) => {
  console.error(err);
  return c.json({ error: 'The worker hit an error.' }, 500);
});

export default app;
