export const CONTENT_VERSION = 2;

const DAY_TO_EN = { zo: 'sun', ma: 'mon', di: 'tue', wo: 'wed', do: 'thu', vr: 'fri', za: 'sat' };
const DAY_TO_NL = flip(DAY_TO_EN);

const ROUTINE_TO_EN = { dag: 'day', nacht: 'night' };
const ROUTINE_TO_NL = flip(ROUTINE_TO_EN);

const SUGGESTION_TO_EN = { bijzonderheid: 'occasion', stap: 'step', weekritme: 'weekly' };
const SUGGESTION_TO_NL = flip(SUGGESTION_TO_EN);

function flip(map) {
  return Object.fromEntries(Object.entries(map).map(([a, b]) => [b, a]));
}

function list(value) {
  return Array.isArray(value) ? value : [];
}

function object(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

function has(source, key) {
  return source != null && Object.prototype.hasOwnProperty.call(source, key);
}

function move(source, from, target, to, convert) {
  if (!has(source, from)) return target;
  target[to] = convert ? convert(source[from]) : source[from];
  return target;
}

function days(value, map) {
  return list(value).map((d) => map[d] ?? d);
}

export function routineToEn(value) {
  return ROUTINE_TO_EN[value] ?? 'day';
}

export function routineToNl(value) {
  return ROUTINE_TO_NL[value] ?? 'dag';
}

function swapHead(key, map) {
  const text = String(key ?? '');
  const cut = text.indexOf('/');
  if (cut < 0) return text;
  return (map[text.slice(0, cut)] ?? text.slice(0, cut)) + text.slice(cut);
}

export function checkKeyToEn(key) {
  return swapHead(key, ROUTINE_TO_EN);
}

export function checkKeyToNl(key) {
  return swapHead(key, ROUTINE_TO_NL);
}

function swapChecks(checks, map) {
  const out = {};
  for (const [key, value] of Object.entries(object(checks))) out[swapHead(key, map)] = value;
  return out;
}

export function checksToEn(checks) {
  return swapChecks(checks, ROUTINE_TO_EN);
}

export function checksToNl(checks) {
  return swapChecks(checks, ROUTINE_TO_NL);
}

function stepToEn(raw) {
  const s = object(raw);
  const out = {};
  move(s, 'icoon', out, 'icon');
  move(s, 'label', out, 'label');
  move(s, 'datum', out, 'date');
  move(s, 'dagen', out, 'days', (v) => days(v, DAY_TO_EN));
  move(s, 'wie', out, 'who', list);
  return out;
}

function stepToNl(raw) {
  const s = object(raw);
  const out = {};
  move(s, 'icon', out, 'icoon');
  move(s, 'label', out, 'label');
  move(s, 'date', out, 'datum');
  move(s, 'days', out, 'dagen', (v) => days(v, DAY_TO_NL));
  move(s, 'who', out, 'wie', list);
  return out;
}

function groupToEn(raw) {
  const g = object(raw);
  const out = {};
  move(g, 'groep', out, 'name');
  move(g, 'tijd', out, 'time');
  move(g, 'stappen', out, 'steps', (v) => list(v).map(stepToEn));
  return out;
}

function groupToNl(raw) {
  const g = object(raw);
  const out = {};
  move(g, 'name', out, 'groep');
  move(g, 'time', out, 'tijd');
  move(g, 'steps', out, 'stappen', (v) => list(v).map(stepToNl));
  return out;
}

function weekItemToEn(raw) {
  const w = object(raw);
  const out = {};
  move(w, 'icoon', out, 'icon');
  move(w, 'tekst', out, 'text');
  move(w, 'tijd', out, 'time');
  move(w, 'tot', out, 'until');
  move(w, 'dagen', out, 'days', (v) => days(v, DAY_TO_EN));
  move(w, 'wie', out, 'who', list);
  move(w, 'avond', out, 'evening');
  return out;
}

function weekItemToNl(raw) {
  const w = object(raw);
  const out = {};
  move(w, 'icon', out, 'icoon');
  move(w, 'text', out, 'tekst');
  move(w, 'time', out, 'tijd');
  move(w, 'until', out, 'tot');
  move(w, 'days', out, 'dagen', (v) => days(v, DAY_TO_NL));
  move(w, 'who', out, 'wie', list);
  move(w, 'evening', out, 'avond');
  return out;
}

function eventToEn(raw) {
  const e = object(raw);
  const out = {};
  move(e, 'id', out, 'id');
  move(e, 'icoon', out, 'icon');
  move(e, 'tekst', out, 'text');
  move(e, 'tijd', out, 'time');
  move(e, 'tot', out, 'until');
  move(e, 'datum', out, 'date');
  move(e, 'wie', out, 'who', list);
  return out;
}

function eventToNl(raw) {
  const e = object(raw);
  const out = {};
  move(e, 'id', out, 'id');
  move(e, 'icon', out, 'icoon');
  move(e, 'text', out, 'tekst');
  move(e, 'time', out, 'tijd');
  move(e, 'until', out, 'tot');
  move(e, 'date', out, 'datum');
  move(e, 'who', out, 'wie', list);
  return out;
}

function personToEn(raw) {
  const p = object(raw);
  const out = {};
  move(p, 'id', out, 'id');
  move(p, 'naam', out, 'name');
  move(p, 'emoji', out, 'emoji');
  move(p, 'kleur', out, 'color');
  move(p, 'kenmerken', out, 'traits', object);
  return out;
}

function personToNl(raw) {
  const p = object(raw);
  const out = {};
  move(p, 'id', out, 'id');
  move(p, 'name', out, 'naam');
  move(p, 'emoji', out, 'emoji');
  move(p, 'color', out, 'kleur');
  move(p, 'traits', out, 'kenmerken', object);
  return out;
}

export function contentToEn(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const out = { version: CONTENT_VERSION };
  move(raw, 'titel', out, 'title');
  move(raw, 'avondVanaf', out, 'eveningFrom');
  move(raw, 'assistent', out, 'assistant');
  move(raw, 'assistentSleutel', out, 'assistantKey');
  move(raw, 'mensen', out, 'people', (v) => list(v).map(personToEn));
  move(raw, 'dag', out, 'day', (v) => list(v).map(groupToEn));
  move(raw, 'nacht', out, 'night', (v) => list(v).map(groupToEn));
  move(raw, 'overzicht', out, 'week', (v) => list(v).map(weekItemToEn));
  move(raw, 'events', out, 'events', (v) => list(v).map(eventToEn));
  return out;
}

export function contentToNl(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const out = {};
  move(raw, 'title', out, 'titel');
  move(raw, 'eveningFrom', out, 'avondVanaf');
  move(raw, 'assistant', out, 'assistent');
  move(raw, 'assistantKey', out, 'assistentSleutel');
  move(raw, 'people', out, 'mensen', (v) => list(v).map(personToNl));
  move(raw, 'day', out, 'dag', (v) => list(v).map(groupToNl));
  move(raw, 'night', out, 'nacht', (v) => list(v).map(groupToNl));
  move(raw, 'week', out, 'overzicht', (v) => list(v).map(weekItemToNl));
  move(raw, 'events', out, 'events', (v) => list(v).map(eventToNl));
  return out;
}

export function suggestionToNl(raw) {
  const s = object(raw);
  const out = {};
  out.soort = SUGGESTION_TO_NL[s.kind] ?? 'bijzonderheid';
  move(s, 'icon', out, 'icoon');
  move(s, 'text', out, 'tekst');
  move(s, 'date', out, 'datum');
  move(s, 'days', out, 'dagen', (v) => days(v, DAY_TO_NL));
  move(s, 'time', out, 'tijd');
  move(s, 'until', out, 'tot');
  move(s, 'who', out, 'wie', list);
  move(s, 'routine', out, 'ritme', routineToNl);
  move(s, 'group', out, 'groep');
  move(s, 'source', out, 'bron');
  return out;
}

export function suggestionToEn(raw) {
  const s = object(raw);
  const out = {};
  out.kind = SUGGESTION_TO_EN[s.soort] ?? 'occasion';
  move(s, 'icoon', out, 'icon');
  move(s, 'tekst', out, 'text');
  move(s, 'datum', out, 'date');
  move(s, 'dagen', out, 'days', (v) => days(v, DAY_TO_EN));
  move(s, 'tijd', out, 'time');
  move(s, 'tot', out, 'until');
  move(s, 'wie', out, 'who', list);
  move(s, 'ritme', out, 'routine', routineToEn);
  move(s, 'groep', out, 'group');
  move(s, 'bron', out, 'source');
  return out;
}
