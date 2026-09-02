import { createExecutionContext, env, waitOnExecutionContext } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import app from './index';
import type { Content } from './types';

const CONTENT: Content = {
  version: 2,
  title: 'Our day',
  people: [{ id: 'emma', name: 'Emma', emoji: '🦄', color: '#2FA37C', traits: {} }],
  day: [
    {
      name: 'Getting up',
      time: '7:00',
      steps: [
        { icon: '🛏️', label: 'Wake up' },
        { icon: '👕', label: 'Get dressed', days: ['mon', 'tue', 'wed', 'thu', 'fri'], who: ['emma'] },
      ],
    },
  ],
  night: [{ name: 'Bedtime', time: '', steps: [{ icon: '🪥', label: 'Brush teeth' }] }],
  week: [{ icon: '🏫', text: 'School', time: '8:30', until: '14:15', days: ['mon', 'tue'] }],
  events: [{ id: 'e1', icon: '🎉', text: 'Julia turns 6', date: '2026-09-09' }],
};

const TODAY = new Date().toISOString().slice(0, 10);

async function call(path: string, init: RequestInit = {}, extra: Partial<Env> = {}) {
  const ctx = createExecutionContext();
  const res = await app.fetch(new Request('https://house' + path, init), { ...env, ...extra }, ctx);
  await waitOnExecutionContext(ctx);
  return res;
}

const json = (body: unknown, method = 'PUT'): RequestInit => ({
  method,
  body: JSON.stringify(body),
  headers: { 'Content-Type': 'application/json' },
});

describe('content', () => {
  it('is null in an empty house', async () => {
    const out = await (await call('/api/v2/storage/content')).json();
    expect(out).toEqual({ content: null });
  });

  it('comes back exactly as stored', async () => {
    expect((await call('/api/v2/storage/content', json(CONTENT))).status).toBe(200);
    const out = await (await call('/api/v2/storage/content')).json<{ content: Content }>();
    expect(out.content).toEqual(CONTENT);
  });

  it('must be a JSON object', async () => {
    expect((await call('/api/v2/storage/content', json([1, 2]))).status).toBe(400);
    expect((await call('/api/v2/storage/content', { method: 'PUT', body: 'nope' })).status).toBe(400);
  });
});

describe('checks', () => {
  it('start empty for any day', async () => {
    const out = await (await call('/api/v2/storage/day?date=2026-01-05')).json();
    expect(out).toEqual({ date: '2026-01-05', checks: {} });
  });

  it('fall back to today on a bad date', async () => {
    const out = await (await call('/api/v2/storage/day?date=yesterday')).json<{ date: string }>();
    expect(out.date).toBe(TODAY);
  });

  it('can be set and unset', async () => {
    await call('/api/v2/storage/check', json({ date: TODAY, key: 'night/brush-teeth/emma', on: true }));
    await call('/api/v2/storage/check', json({ date: TODAY, key: 'day/wake-up/emma', on: true }));
    let out = await (await call('/api/v2/storage/day?date=' + TODAY)).json<{ checks: unknown }>();
    expect(out.checks).toEqual({ 'night/brush-teeth/emma': true, 'day/wake-up/emma': true });

    await call('/api/v2/storage/check', json({ date: TODAY, key: 'day/wake-up/emma', on: false }));
    out = await (await call('/api/v2/storage/day?date=' + TODAY)).json();
    expect(out.checks).toEqual({ 'night/brush-teeth/emma': true });
  });

  it('need a key', async () => {
    expect((await call('/api/v2/storage/check', json({ date: TODAY, on: true }))).status).toBe(400);
  });

  it('clear one routine at a time', async () => {
    await call('/api/v2/storage/check', json({ date: TODAY, key: 'night/brush-teeth/emma', on: true }));
    await call('/api/v2/storage/check', json({ date: TODAY, key: 'day/wake-up/emma', on: true }));
    await call('/api/v2/storage/routine', json({ date: TODAY, routine: 'night' }, 'DELETE'));
    const out = await (await call('/api/v2/storage/day?date=' + TODAY)).json<{ checks: unknown }>();
    expect(out.checks).toEqual({ 'day/wake-up/emma': true });
  });

  it('refuse an unknown routine', async () => {
    const res = await call('/api/v2/storage/routine', json({ date: TODAY, routine: 'afternoon' }, 'DELETE'));
    expect(res.status).toBe(400);
  });
});

describe('the shared key', () => {
  it('is not needed when none is set', async () => {
    expect((await call('/api/v2/storage/content')).status).toBe(200);
  });

  it('locks every /api route when set', async () => {
    expect((await call('/api/v2/storage/content', {}, { SLEUTEL: 's3cret' })).status).toBe(401);
    expect((await call('/api/v2/read', { method: 'POST' }, { SLEUTEL: 's3cret' })).status).toBe(401);
    const ok = await call(
      '/api/v2/storage/content',
      { headers: { 'X-Routine-Key': 's3cret' } },
      { SLEUTEL: 's3cret' },
    );
    expect(ok.status).toBe(200);
  });
});

describe('addresses', () => {
  it('unknown ones are a JSON 404', async () => {
    const res = await call('/api/v2/nothing');
    expect(res.status).toBe(404);
    expect(await res.json()).toEqual({ error: 'Unknown address.' });
    expect((await call('/')).status).toBe(404);
  });
});

describe('the live stream', () => {
  async function open(date = TODAY) {
    const res = await call(`/api/v2/storage/stream?date=${date}`, { headers: { Upgrade: 'websocket' } });
    expect(res.status).toBe(101);
    const ws = res.webSocket!;
    const frames: unknown[] = [];
    const waiters: Array<(frame: unknown) => void> = [];
    ws.accept();
    ws.addEventListener('message', (event) => {
      const frame = JSON.parse(String(event.data));
      const waiter = waiters.shift();
      if (waiter) waiter(frame);
      else frames.push(frame);
    });
    const next = () =>
      new Promise<unknown>((resolve) => {
        const frame = frames.shift();
        if (frame !== undefined) resolve(frame);
        else waiters.push(resolve);
      });
    return { ws, next, pending: () => frames.length };
  }

  it('opens with the whole house', async () => {
    await call('/api/v2/storage/content', json(CONTENT));
    await call('/api/v2/storage/check', json({ date: TODAY, key: 'day/wake-up/emma', on: true }));
    const { ws, next } = await open();
    expect(await next()).toEqual({
      kind: 'start',
      date: TODAY,
      content: CONTENT,
      checks: { 'day/wake-up/emma': true },
    });
    ws.close();
  });

  it('pushes every change to every phone', async () => {
    const a = await open();
    const b = await open();
    await a.next();
    await b.next();

    await call('/api/v2/storage/check', json({ date: TODAY, key: 'day/wake-up/emma', on: true }));
    const frame = { kind: 'check', date: TODAY, key: 'day/wake-up/emma', on: true };
    expect(await a.next()).toEqual(frame);
    expect(await b.next()).toEqual(frame);

    await call('/api/v2/storage/routine', json({ date: TODAY, routine: 'day' }, 'DELETE'));
    expect(await a.next()).toEqual({ kind: 'routine', date: TODAY, routine: 'day' });
    expect(await b.next()).toEqual({ kind: 'routine', date: TODAY, routine: 'day' });

    await call('/api/v2/storage/content', json(CONTENT));
    expect(await b.next()).toEqual({ kind: 'content', content: CONTENT });
    a.ws.close();
    b.ws.close();
  });

  it('skips a phone watching another day, and lets it switch', async () => {
    const other = await open('2020-01-01');
    await other.next();

    await call('/api/v2/storage/check', json({ date: TODAY, key: 'day/wake-up/emma', on: true }));
    await call('/api/v2/storage/content', json(CONTENT));
    expect(await other.next()).toEqual({ kind: 'content', content: CONTENT });
    expect(other.pending()).toBe(0);

    other.ws.send(JSON.stringify({ kind: 'day', date: TODAY }));
    expect(await other.next()).toEqual({
      kind: 'start',
      date: TODAY,
      content: CONTENT,
      checks: { 'day/wake-up/emma': true },
    });
    other.ws.close();
  });

  it('refuses a plain request', async () => {
    expect((await call('/api/v2/storage/stream')).status).toBe(426);
  });
});
