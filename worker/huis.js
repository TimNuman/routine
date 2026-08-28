// Eén huis: alles van dit gezin bij elkaar, met de telefoons die meekijken.
//
// Een Durable Object is de enige plek in het verhaal die twee dingen tegelijk
// kan: gegevens bewaren en weten wie er op dat moment verbonden is. Daardoor
// hoeft niemand te pollen — wie iets afvinkt schrijft het hier op, en iedereen
// die openstaat krijgt het meteen te horen.
//
// Twee soorten gegevens, net als eerst: 'inhoud' is wat je in de app bewerkt,
// en per datum staat wie welke stap heeft afgevinkt. Een eigen sleutel per dag
// betekent dat het ritme 's ochtends vanzelf leeg begint.

const DAG = /^\d{4}-\d{2}-\d{2}$/;
const BEWAARDAGEN = 7;

export class Huis {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
  }

  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === '/stroom') return this.stroom(url);

    if (url.pathname === '/inhoud') {
      if (request.method === 'GET') return json({ inhoud: await this.inhoud() });
      if (request.method === 'PUT') {
        const inhoud = await request.json();
        await this.ctx.storage.put('inhoud', inhoud);
        this.roep({ soort: 'inhoud', inhoud });
        return json({ goed: true });
      }
      return json({ fout: 'Alleen GET of PUT.' }, 405);
    }

    if (url.pathname === '/dag') {
      const datum = dagOf(url.searchParams.get('datum'));
      return json({ datum, vinkjes: await this.vinkjes(datum) });
    }

    if (url.pathname === '/vink' && request.method === 'PUT') {
      const { datum, sleutel, aan } = await request.json();
      const dag = dagOf(datum);
      const schoon = String(sleutel || '').slice(0, 200);
      if (!schoon) return json({ fout: 'Geen sleutel.' }, 400);
      const vinkjes = await this.vinkjes(dag);
      if (aan) vinkjes[schoon] = true; else delete vinkjes[schoon];
      await this.ctx.storage.put('dag:' + dag, vinkjes);
      this.roep({ soort: 'vink', datum: dag, sleutel: schoon, aan: Boolean(aan) });
      await this.ruimOp();
      return json({ goed: true });
    }

    // Opnieuw beginnen: alles van één ritme op één dag in één keer weg.
    if (url.pathname === '/ritme' && request.method === 'DELETE') {
      const { datum, ritme } = await request.json();
      const dag = dagOf(datum);
      const r = ritme === 'nacht' ? 'nacht' : 'dag';
      const vinkjes = await this.vinkjes(dag);
      Object.keys(vinkjes).forEach((s) => { if (s.startsWith(r + '/')) delete vinkjes[s]; });
      await this.ctx.storage.put('dag:' + dag, vinkjes);
      this.roep({ soort: 'ritme', datum: dag, ritme: r });
      return json({ goed: true });
    }

    return json({ fout: 'Onbekend adres.' }, 404);
  }

  async inhoud() {
    const bewaard = await this.ctx.storage.get('inhoud');
    if (bewaard) return bewaard;
    // Eenmalig overnemen wat er in de oude database stond, zodat verhuizen
    // niets kost. Daarna staat het hier en wordt er niet meer gekeken.
    const bron = this.env.OVERNEMEN;
    if (!bron) return null;
    try {
      const res = await fetch(bron, { cf: { cacheTtl: 0 } });
      if (!res.ok) return null;
      const oud = await res.json();
      if (!oud || typeof oud !== 'object') return null;
      await this.ctx.storage.put('inhoud', oud);
      return oud;
    } catch (err) {
      console.warn('overnemen mislukt:', err && err.message);
      return null;
    }
  }

  async vinkjes(datum) {
    return (await this.ctx.storage.get('dag:' + datum)) || {};
  }

  // Oude dagen blijven anders voor altijd staan.
  async ruimOp() {
    const grens = new Date();
    grens.setDate(grens.getDate() - BEWAARDAGEN);
    const oudste = 'dag:' + grens.toISOString().slice(0, 10);
    const alles = await this.ctx.storage.list({ prefix: 'dag:', end: oudste });
    if (alles.size) await this.ctx.storage.delete([...alles.keys()]);
  }

  // ------------------------------------------------------------- meekijken ---
  async stroom(url) {
    const paar = new WebSocketPair();
    const [client, server] = Object.values(paar);
    // Slapen mag: het object hoeft niet wakker te blijven voor een open
    // verbinding waar niets op gebeurt.
    this.ctx.acceptWebSocket(server);
    const datum = dagOf(url.searchParams.get('datum'));
    server.serializeAttachment({ datum });
    server.send(JSON.stringify({
      soort: 'begin',
      datum,
      inhoud: await this.inhoud(),
      vinkjes: await this.vinkjes(datum),
    }));
    return new Response(null, { status: 101, webSocket: client });
  }

  // De enige boodschap die binnenkomt: 'ik kijk nu naar deze dag' — als het
  // middernacht is geweest, of als je de app na een dag weer opent.
  async webSocketMessage(ws, bericht) {
    let ruw;
    try { ruw = JSON.parse(bericht); } catch { return; }
    if (!ruw || ruw.soort !== 'dag') return;
    const datum = dagOf(ruw.datum);
    ws.serializeAttachment({ datum });
    ws.send(JSON.stringify({
      soort: 'begin',
      datum,
      inhoud: await this.inhoud(),
      vinkjes: await this.vinkjes(datum),
    }));
  }

  webSocketClose(ws) { try { ws.close(); } catch { /* al dicht */ } }
  webSocketError() { /* de verbinding valt vanzelf weg */ }

  // Iedereen die openstaat hoort het meteen; wie naar een andere dag kijkt
  // heeft niets aan een vinkje van vandaag.
  roep(bericht) {
    const pakje = JSON.stringify(bericht);
    for (const ws of this.ctx.getWebSockets()) {
      if (bericht.datum) {
        let mee;
        try { mee = ws.deserializeAttachment(); } catch { mee = null; }
        if (mee && mee.datum && mee.datum !== bericht.datum) continue;
      }
      try { ws.send(pakje); } catch { /* net weggevallen */ }
    }
  }
}

function dagOf(waarde) {
  return DAG.test(String(waarde || '')) ? String(waarde) : new Date().toISOString().slice(0, 10);
}

function json(inhoud, status) {
  return new Response(JSON.stringify(inhoud), {
    status: status || 200,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}
