const DATE = /^\d{4}-\d{2}-\d{2}$/;
const KEEP_DAYS = 7;

export class House {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
  }

  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === '/stroom') return this.stream(url);

    if (url.pathname === '/inhoud') {
      if (request.method === 'GET') return json({ inhoud: await this.content() });
      if (request.method === 'PUT') {
        const content = await request.json();
        await this.ctx.storage.put('inhoud', content);
        this.broadcast({ soort: 'inhoud', inhoud: content });
        return json({ goed: true });
      }
      return json({ fout: 'Alleen GET of PUT.' }, 405);
    }

    if (url.pathname === '/dag') {
      const date = dateOr(url.searchParams.get('datum'));
      return json({ datum: date, vinkjes: await this.checks(date) });
    }

    if (url.pathname === '/vink' && request.method === 'PUT') {
      const { datum, sleutel, aan } = await request.json();
      const date = dateOr(datum);
      const key = String(sleutel || '').slice(0, 200);
      if (!key) return json({ fout: 'Geen sleutel.' }, 400);
      const checks = await this.checks(date);
      if (aan) checks[key] = true; else delete checks[key];
      await this.ctx.storage.put('dag:' + date, checks);
      this.broadcast({ soort: 'vink', datum: date, sleutel: key, aan: Boolean(aan) });
      await this.sweep();
      return json({ goed: true });
    }

    if (url.pathname === '/ritme' && request.method === 'DELETE') {
      const { datum, ritme } = await request.json();
      const date = dateOr(datum);
      const which = ritme === 'nacht' ? 'nacht' : 'dag';
      const checks = await this.checks(date);
      Object.keys(checks).forEach((key) => { if (key.startsWith(which + '/')) delete checks[key]; });
      await this.ctx.storage.put('dag:' + date, checks);
      this.broadcast({ soort: 'ritme', datum: date, ritme: which });
      return json({ goed: true });
    }

    return json({ fout: 'Onbekend adres.' }, 404);
  }

  async content() {
    const stored = await this.ctx.storage.get('inhoud');
    if (stored) return stored;
    const source = this.env.IMPORT_FROM;
    if (!source) return null;
    try {
      const res = await fetch(source, { cf: { cacheTtl: 0 } });
      if (!res.ok) return null;
      const old = await res.json();
      if (!old || typeof old !== 'object') return null;
      await this.ctx.storage.put('inhoud', old);
      return old;
    } catch (err) {
      console.warn('import failed:', err && err.message);
      return null;
    }
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

  async stream(url) {
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.ctx.acceptWebSocket(server);
    const date = dateOr(url.searchParams.get('datum'));
    server.serializeAttachment({ datum: date });
    server.send(JSON.stringify({
      soort: 'begin',
      datum: date,
      inhoud: await this.content(),
      vinkjes: await this.checks(date),
    }));
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws, message) {
    let raw;
    try { raw = JSON.parse(message); } catch { return; }
    if (!raw || raw.soort !== 'dag') return;
    const date = dateOr(raw.datum);
    ws.serializeAttachment({ datum: date });
    ws.send(JSON.stringify({
      soort: 'begin',
      datum: date,
      inhoud: await this.content(),
      vinkjes: await this.checks(date),
    }));
  }

  webSocketClose(ws) { try { ws.close(); } catch { } }

  webSocketError() { }

  broadcast(message) {
    const packet = JSON.stringify(message);
    for (const ws of this.ctx.getWebSockets()) {
      if (message.datum) {
        let watching;
        try { watching = ws.deserializeAttachment(); } catch { watching = null; }
        if (watching && watching.datum && watching.datum !== message.datum) continue;
      }
      try { ws.send(packet); } catch { }
    }
  }
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
