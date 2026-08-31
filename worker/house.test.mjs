import assert from 'node:assert/strict';
import { House } from './house.js';

class Storage {
  constructor(seed = {}) { this.map = new Map(Object.entries(seed)); }
  async get(k) { return this.map.get(k); }
  async put(k, v) { this.map.set(k, JSON.parse(JSON.stringify(v))); }
  async delete(keys) { for (const k of keys) this.map.delete(k); }
  async list({ prefix, end } = {}) {
    return new Map([...this.map.entries()]
      .filter(([k]) => (!prefix || k.startsWith(prefix)) && (!end || k < end)));
  }
}

class Socket {
  constructor() { this.sent = []; this.attachment = null; }
  send(text) { this.sent.push(JSON.parse(text)); }
  serializeAttachment(a) { this.attachment = a; }
  deserializeAttachment() { return this.attachment; }
  close() {}
  last() { return this.sent[this.sent.length - 1]; }
}

const RealResponse = globalThis.Response;
globalThis.Response = class extends RealResponse {
  constructor(body, init = {}) {
    if (init.status === 101) { super(null, { status: 200 }); this.upgraded = true; return; }
    super(body, init);
  }
};

globalThis.WebSocketPair = function () {
  const server = new Socket();
  return { 0: new Socket(), 1: server };
};

function makeHouse(seed) {
  const sockets = [];
  const ctx = {
    storage: new Storage(seed),
    acceptWebSocket: (ws) => sockets.push(ws),
    getWebSockets: () => sockets,
  };
  const house = new House(ctx, {});
  house.sockets = sockets;
  return house;
}

const req = (path, method = 'GET', body) => new Request('https://house' + path, {
  method,
  ...(body ? { body: JSON.stringify(body), headers: { 'Content-Type': 'application/json' } } : {}),
});

const DUTCH = {
  titel: 'Ons dagritme',
  avondVanaf: 17,
  mensen: [{ id: 'emma', naam: 'Emma', emoji: '🦄', kleur: '#2FA37C', kenmerken: {} }],
  dag: [{ groep: 'Opstaan', tijd: '7:00', stappen: [
    { icoon: '🛏️', label: 'Wakker worden' },
    { icoon: '👕', label: 'Aankleden', dagen: ['ma', 'di', 'wo', 'do', 'vr'], wie: ['emma'] },
  ] }],
  nacht: [{ groep: 'Naar bed', tijd: '', stappen: [{ icoon: '🪥', label: 'Tanden poetsen' }] }],
  overzicht: [{ icoon: '🏫', tekst: 'School', tijd: '8:30', tot: '14:15', dagen: ['ma', 'di'] }],
  events: [{ id: 'e1', icoon: '🎉', tekst: 'Julia jarig', datum: '2026-09-09' }],
};

const TODAY = new Date().toISOString().slice(0, 10);
let pass = 0;
const check = (name, fn) => { fn(); pass++; console.log('  ok  ' + name); };

console.log('\nmigration');
{
  const house = makeHouse({
    inhoud: DUTCH,
    ['dag:' + TODAY]: { 'dag/wakker-worden/emma': true, 'nacht/tanden-poetsen/emma': true },
  });
  await house.fetch(req('/v2/content'));

  const stored = await house.ctx.storage.get('content');
  check('inhoud -> content, in english', () => {
    assert.equal(stored.version, 2);
    assert.equal(stored.title, 'Ons dagritme');
    assert.deepEqual(stored.day[0].steps[1].days, ['mon', 'tue', 'wed', 'thu', 'fri']);
    assert.deepEqual(stored.people[0].traits, {});
  });
  check('legacy inhoud kept as rollback', async () => {
    assert.deepEqual(house.ctx.storage.map.get('inhoud'), DUTCH);
  });
  check('check keys rewritten to english', async () => {
    assert.deepEqual(house.ctx.storage.map.get('dag:' + TODAY), {
      'day/wakker-worden/emma': true, 'night/tanden-poetsen/emma': true,
    });
  });
  check('migration is idempotent', async () => {
    house.migrated = false;
    await house.fetch(req('/v2/content'));
    assert.deepEqual(house.ctx.storage.map.get('content'), stored);
  });
}

console.log('\nboth protocols read the same store');
{
  const house = makeHouse({ inhoud: DUTCH });
  const v1 = await (await house.fetch(req('/inhoud'))).json();
  const v2 = await (await house.fetch(req('/v2/content'))).json();

  check('v1 sees byte-identical dutch', () => assert.deepEqual(v1.inhoud, DUTCH));
  check('v2 sees english', () => {
    assert.equal(v2.content.title, 'Ons dagritme');
    assert.equal(v2.content.week[0].text, 'School');
    assert.deepEqual(v2.content.week[0].days, ['mon', 'tue']);
  });
}

console.log('\nwrites cross over');
{
  const house = makeHouse({ inhoud: DUTCH });
  const edited = structuredClone(DUTCH);
  edited.titel = 'Nieuw huis';
  edited.mensen.push({ id: 'mads', naam: 'Mads', emoji: '🦖', kleur: '#7C6BD6', kenmerken: {} });
  await house.fetch(req('/inhoud', 'PUT', edited));

  check('v1 write -> v2 read', async () => {
    const out = await (await house.fetch(req('/v2/content'))).json();
    assert.equal(out.content.title, 'Nieuw huis');
    assert.equal(out.content.people[1].name, 'Mads');
  });

  const english = (await (await house.fetch(req('/v2/content'))).json()).content;
  english.title = 'Terug';
  english.week.push({ icon: '⚽', text: 'Voetbal', time: '18:00', days: ['sat'], evening: true });
  await house.fetch(req('/v2/content', 'PUT', english));

  check('v2 write -> v1 read, back in dutch', async () => {
    const out = await (await house.fetch(req('/inhoud'))).json();
    assert.equal(out.inhoud.titel, 'Terug');
    assert.deepEqual(out.inhoud.overzicht[1],
      { icoon: '⚽', tekst: 'Voetbal', tijd: '18:00', dagen: ['za'], avond: true });
  });
}

console.log('\nchecks cross over');
{
  const house = makeHouse({ inhoud: DUTCH });
  await house.fetch(req('/vink', 'PUT',
    { datum: TODAY, sleutel: 'nacht/tanden-poetsen/emma', aan: true }));

  check('v1 tick stored in english', async () => {
    assert.deepEqual(house.ctx.storage.map.get('dag:' + TODAY),
      { 'night/tanden-poetsen/emma': true });
  });
  check('v2 sees it', async () => {
    const out = await (await house.fetch(req('/v2/day?date=' + TODAY))).json();
    assert.deepEqual(out.checks, { 'night/tanden-poetsen/emma': true });
  });
  check('v1 sees it back in dutch', async () => {
    const out = await (await house.fetch(req('/dag?datum=' + TODAY))).json();
    assert.deepEqual(out.vinkjes, { 'nacht/tanden-poetsen/emma': true });
  });

  await house.fetch(req('/v2/check', 'PUT',
    { date: TODAY, key: 'day/wakker-worden/emma', on: true }));
  check('v2 tick -> v1 read', async () => {
    const out = await (await house.fetch(req('/dag?datum=' + TODAY))).json();
    assert.deepEqual(out.vinkjes,
      { 'nacht/tanden-poetsen/emma': true, 'dag/wakker-worden/emma': true });
  });

  await house.fetch(req('/ritme', 'DELETE', { datum: TODAY, ritme: 'nacht' }));
  check('v1 reset clears the english night keys', async () => {
    assert.deepEqual(house.ctx.storage.map.get('dag:' + TODAY), { 'day/wakker-worden/emma': true });
  });
}

console.log('\nlive stream, both shapes at once');
{
  const house = makeHouse({ inhoud: DUTCH });
  await house.fetch(req('/stroom?datum=' + TODAY));
  await house.fetch(req('/v2/stream?date=' + TODAY));
  const [dutchSocket, englishSocket] = house.sockets;

  check('opening frames differ per protocol', () => {
    assert.equal(dutchSocket.last().soort, 'begin');
    assert.equal(dutchSocket.last().inhoud.titel, 'Ons dagritme');
    assert.equal(englishSocket.last().kind, 'start');
    assert.equal(englishSocket.last().content.title, 'Ons dagritme');
  });

  await house.fetch(req('/v2/check', 'PUT',
    { date: TODAY, key: 'night/tanden-poetsen/emma', on: true }));

  check('one v2 tick reaches both sockets, each in its own shape', () => {
    assert.deepEqual(dutchSocket.last(), {
      soort: 'vink', datum: TODAY, sleutel: 'nacht/tanden-poetsen/emma', aan: true,
    });
    assert.deepEqual(englishSocket.last(), {
      kind: 'check', date: TODAY, key: 'night/tanden-poetsen/emma', on: true,
    });
  });

  await house.fetch(req('/inhoud', 'PUT', { ...DUTCH, titel: 'Van de webapp' }));
  check('a v1 edit reaches the v2 socket in english', () => {
    assert.equal(dutchSocket.last().soort, 'inhoud');
    assert.equal(dutchSocket.last().inhoud.titel, 'Van de webapp');
    assert.equal(englishSocket.last().kind, 'content');
    assert.equal(englishSocket.last().content.title, 'Van de webapp');
  });

  check('a socket on another day is skipped', async () => {
    dutchSocket.attachment = { date: '2020-01-01', version: 1 };
    const before = dutchSocket.sent.length;
    await house.fetch(req('/v2/check', 'PUT', { date: TODAY, key: 'day/x/emma', on: true }));
    assert.equal(dutchSocket.sent.length, before);
  });
}

console.log('\nempty house');
{
  const house = makeHouse({});
  check('v2 returns null content, no crash', async () => {
    const out = await (await house.fetch(req('/v2/content'))).json();
    assert.equal(out.content, null);
  });
  check('v1 returns null content, no crash', async () => {
    const out = await (await house.fetch(req('/inhoud'))).json();
    assert.equal(out.inhoud, null);
  });
}

console.log(`\n${pass} checks passed\n`);
