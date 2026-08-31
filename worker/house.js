import {
  contentToEn,
  contentToNl,
  checkKeyToEn,
  checkKeyToNl,
  checksToNl,
  routineToEn,
  routineToNl,
} from './schema.js';

const DATE = /^\d{4}-\d{2}-\d{2}$/;
const KEEP_DAYS = 7;

const CONTENT = 'content';
const LEGACY_CONTENT = 'inhoud';

export class House {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
    this.migrated = false;
  }

  async fetch(request) {
    await this.ensureMigrated();

    const url = new URL(request.url);
    return url.pathname.startsWith('/v2/')
      ? this.serveV2(request, url)
      : this.serveV1(request, url);
  }

  async serveV2(request, url) {
    const path = url.pathname.slice('/v2'.length);

    if (path === '/stream') return this.stream(url, 2);

    if (path === '/content') {
      if (request.method === 'GET') return json({ content: await this.content() });
      if (request.method === 'PUT') {
        const content = await request.json();
        await this.ctx.storage.put(CONTENT, content);
        this.broadcast({ event: 'content', content });
        return json({ ok: true });
      }
      return json({ error: 'Only GET or PUT.' }, 405);
    }

    if (path === '/day') {
      const date = dateOr(url.searchParams.get('date'));
      return json({ date, checks: await this.checks(date) });
    }

    if (path === '/check' && request.method === 'PUT') {
      const { date, key, on } = await request.json();
      const clean = String(key || '').slice(0, 200);
      if (!clean) return json({ error: 'No key.' }, 400);
      return json(await this.setCheck(dateOr(date), clean, Boolean(on)));
    }

    if (path === '/routine' && request.method === 'DELETE') {
      const { date, routine } = await request.json();
      return json(await this.clearRoutine(dateOr(date), routineToEn(routine)));
    }

    return json({ error: 'Unknown address.' }, 404);
  }

  async serveV1(request, url) {
    if (url.pathname === '/stroom') return this.stream(url, 1);

    if (url.pathname === '/inhoud') {
      if (request.method === 'GET') return json({ inhoud: contentToNl(await this.content()) });
      if (request.method === 'PUT') {
        const content = contentToEn(await request.json());
        await this.ctx.storage.put(CONTENT, content);
        this.broadcast({ event: 'content', content });
        return json({ goed: true });
      }
      return json({ fout: 'Alleen GET of PUT.' }, 405);
    }

    if (url.pathname === '/dag') {
      const date = dateOr(url.searchParams.get('datum'));
      return json({ datum: date, vinkjes: checksToNl(await this.checks(date)) });
    }

    if (url.pathname === '/vink' && request.method === 'PUT') {
      const { datum, sleutel, aan } = await request.json();
      const clean = String(sleutel || '').slice(0, 200);
      if (!clean) return json({ fout: 'Geen sleutel.' }, 400);
      await this.setCheck(dateOr(datum), checkKeyToEn(clean), Boolean(aan));
      return json({ goed: true });
    }

    if (url.pathname === '/ritme' && request.method === 'DELETE') {
      const { datum, ritme } = await request.json();
      await this.clearRoutine(dateOr(datum), routineToEn(ritme));
      return json({ goed: true });
    }

    return json({ fout: 'Onbekend adres.' }, 404);
  }

  async setCheck(date, key, on) {
    const checks = await this.checks(date);
    if (on) checks[key] = true; else delete checks[key];
    await this.ctx.storage.put('dag:' + date, checks);
    this.broadcast({ event: 'check', date, key, on });
    await this.sweep();
    return { ok: true };
  }

  async clearRoutine(date, routine) {
    const checks = await this.checks(date);
    Object.keys(checks).forEach((key) => {
      if (key.startsWith(routine + '/')) delete checks[key];
    });
    await this.ctx.storage.put('dag:' + date, checks);
    this.broadcast({ event: 'routine', date, routine });
    return { ok: true };
  }

  async ensureMigrated() {
    if (this.migrated) return;
    this.migrated = true;

    if (await this.ctx.storage.get(CONTENT)) return;

    const legacy = (await this.ctx.storage.get(LEGACY_CONTENT)) ?? (await this.imported());
    if (!legacy) return;

    await this.ctx.storage.put(CONTENT, contentToEn(legacy));

    const stale = await this.ctx.storage.list({ prefix: 'dag:' });
    for (const [key, checks] of stale) {
      const moved = {};
      for (const [check, value] of Object.entries(checks || {})) moved[checkKeyToEn(check)] = value;
      await this.ctx.storage.put(key, moved);
    }
  }

  async imported() {
    const source = this.env.IMPORT_FROM;
    if (!source) return null;
    try {
      const res = await fetch(source, { cf: { cacheTtl: 0 } });
      if (!res.ok) return null;
      const old = await res.json();
      if (!old || typeof old !== 'object') return null;
      await this.ctx.storage.put(LEGACY_CONTENT, old);
      return old;
    } catch (err) {
      console.warn('import failed:', err && err.message);
      return null;
    }
  }

  async content() {
    return (await this.ctx.storage.get(CONTENT)) ?? null;
  }

  async checks(date) {
    return (await this.ctx.storage.get('dag:' + date)) || {};
  }

  async sweep() {
    const limit = new Date();
    limit.setDate(limit.getDate() - KEEP_DAYS);
    const oldest = 'dag:' + limit.toISOString().slice(0, 10);
    const stale = await this.ctx.storage.list({ prefix: 'dag:', end: oldest });
    if (stale.size) await this.ctx.storage.delete([...stale.keys()]);
  }

  async stream(url, version) {
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.ctx.acceptWebSocket(server);
    const date = dateOr(url.searchParams.get(version === 2 ? 'date' : 'datum'));
    server.serializeAttachment({ date, version });
    server.send(JSON.stringify(await this.opening(date, version)));
    return new Response(null, { status: 101, webSocket: client });
  }

  async opening(date, version) {
    const content = await this.content();
    const checks = await this.checks(date);
    return version === 2
      ? { kind: 'start', date, content, checks }
      : { soort: 'begin', datum: date, inhoud: contentToNl(content), vinkjes: checksToNl(checks) };
  }

  async webSocketMessage(ws, message) {
    let raw;
    try { raw = JSON.parse(message); } catch { return; }

    const watching = attachmentOf(ws);
    const version = watching.version === 2 ? 2 : 1;
    const asked = version === 2 ? raw && raw.kind === 'day' : raw && raw.soort === 'dag';
    if (!asked) return;

    const date = dateOr(version === 2 ? raw.date : raw.datum);
    ws.serializeAttachment({ date, version });
    ws.send(JSON.stringify(await this.opening(date, version)));
  }

  webSocketClose(ws) { try { ws.close(); } catch { } }

  webSocketError() { }

  broadcast(event) {
    for (const ws of this.ctx.getWebSockets()) {
      const watching = attachmentOf(ws);
      if (event.date && watching.date && watching.date !== event.date) continue;
      try {
        ws.send(JSON.stringify(render(event, watching.version === 2 ? 2 : 1)));
      } catch { }
    }
  }
}

function render(event, version) {
  if (version === 2) {
    switch (event.event) {
      case 'content': return { kind: 'content', content: event.content };
      case 'check': return { kind: 'check', date: event.date, key: event.key, on: event.on };
      case 'routine': return { kind: 'routine', date: event.date, routine: event.routine };
    }
  }
  switch (event.event) {
    case 'content': return { soort: 'inhoud', inhoud: contentToNl(event.content) };
    case 'check': return {
      soort: 'vink', datum: event.date, sleutel: checkKeyToNl(event.key), aan: event.on,
    };
    case 'routine': return {
      soort: 'ritme', datum: event.date, ritme: routineToNl(event.routine),
    };
  }
}

function attachmentOf(ws) {
  try { return ws.deserializeAttachment() || {}; } catch { return {}; }
}

function dateOr(value) {
  return DATE.test(String(value || '')) ? String(value) : new Date().toISOString().slice(0, 10);
}

function json(body, status) {
  return new Response(JSON.stringify(body), {
    status: status || 200,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}
