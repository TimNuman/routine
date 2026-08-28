// Praat met de eigen achterkant: /api/opslag op dezelfde Worker die de app
// uitserveert. Naast lezen en schrijven is er een stroom — een WebSocket die
// openblijft — zodat elke telefoon meteen ziet wat er op een andere gebeurt.
// Dat is ook waarom het een WebSocket is en geen EventSource: die laatste
// bestaat niet in React Native.
import { normaliseer } from './inhoud';
import type { Inhoud, Ritme } from './soorten';

// Op web staat de achterkant op hetzelfde adres als de app. Een telefoon heeft
// een heel adres nodig; dat komt dan uit de omgeving.
const BASIS = (process.env.EXPO_PUBLIC_API || '/api/opslag').replace(/\/+$/, '');
const SLEUTEL = process.env.EXPO_PUBLIC_SLEUTEL || '';

const kopjes: Record<string, string> = SLEUTEL ? { 'X-Routine-Sleutel': SLEUTEL } : {};

function adres(pad: string, vragen?: Record<string, string>): string {
  const zoek = new URLSearchParams(vragen || {}).toString();
  return `${BASIS}${pad}${zoek ? '?' + zoek : ''}`;
}

async function haal(pad: string, vragen?: Record<string, string>) {
  const res = await fetch(adres(pad, vragen), { headers: kopjes });
  if (!res.ok) throw new Error('HTTP ' + res.status);
  return await res.json();
}

async function stuur(pad: string, wijze: 'PUT' | 'DELETE', lijf: unknown) {
  const res = await fetch(adres(pad), {
    method: wijze,
    headers: { ...kopjes, 'Content-Type': 'application/json' },
    body: JSON.stringify(lijf),
  });
  if (!res.ok) throw new Error('HTTP ' + res.status);
}

export async function haalInhoud(): Promise<Inhoud> {
  const uit = await haal('/inhoud');
  return normaliseer(uit && uit.inhoud);
}

// De hele inhoud gaat in één keer terug: de app bewerkt hem ook als één stuk.
export async function bewaarConfig(ruw: unknown): Promise<void> {
  await stuur('/inhoud', 'PUT', ruw);
}

export type Vinkjes = Record<string, boolean>;

export async function haalVinkjes(datum: string): Promise<Vinkjes> {
  const uit = await haal('/dag', { datum });
  return (uit && uit.vinkjes) || {};
}

// De sleutel waaronder een vinkje staat: '<ritme>/<stap>/<persoon>'.
export function vinkSleutel(ritme: Ritme, stap: string, persoon: string): string {
  return `${ritme}/${stap}/${persoon}`;
}

export async function schrijfVink(datum: string, sleutel: string, aan: boolean): Promise<void> {
  await stuur('/vink', 'PUT', { datum, sleutel, aan });
}

// Alles van dit ritme op deze dag in één keer weg: opnieuw beginnen.
export async function wisRitme(datum: string, ritme: Ritme): Promise<void> {
  await stuur('/ritme', 'DELETE', { datum, ritme });
}

// ----------------------------------------------------------------- stroom ---
export type Bericht =
  | { soort: 'begin'; datum: string; inhoud: unknown; vinkjes: Vinkjes }
  | { soort: 'inhoud'; inhoud: unknown }
  | { soort: 'vink'; datum: string; sleutel: string; aan: boolean }
  | { soort: 'ritme'; datum: string; ritme: Ritme };

function stroomadres(datum: string): string {
  const vragen: Record<string, string> = { datum };
  // Een browser kan bij een WebSocket geen kopjes meesturen.
  if (SLEUTEL) vragen.sleutel = SLEUTEL;
  const pad = adres('/stroom', vragen);
  if (/^https?:/.test(pad)) return pad.replace(/^http/, 'ws');
  const hier = typeof location !== 'undefined' ? location.origin : '';
  return hier.replace(/^http/, 'ws') + pad;
}

// Blijft zichzelf opnieuw verbinden zolang je hem niet stopzet: een telefoon
// die uit zijn slaap komt heeft geen verbinding meer, en dat merk je pas als je
// het probeert.
export function volg(datum: string, opBericht: (b: Bericht) => void) {
  let ws: WebSocket | null = null;
  let dicht = false;
  let wachten: ReturnType<typeof setTimeout> | null = null;
  let pogingen = 0;
  let dag = datum;

  const verbind = () => {
    if (dicht) return;
    try {
      ws = new WebSocket(stroomadres(dag));
    } catch {
      opnieuw();
      return;
    }
    ws.onopen = () => { pogingen = 0; };
    ws.onmessage = (e) => {
      try { opBericht(JSON.parse(String(e.data))); } catch { /* geen json */ }
    };
    ws.onerror = () => { /* onclose komt erachteraan */ };
    ws.onclose = () => { ws = null; opnieuw(); };
  };

  const opnieuw = () => {
    if (dicht || wachten) return;
    // Rustig aan als het blijft mislukken, maar nooit langer dan een halve minuut.
    const pauze = Math.min(1000 * 2 ** pogingen, 30000);
    pogingen += 1;
    wachten = setTimeout(() => { wachten = null; verbind(); }, pauze);
  };

  verbind();

  return {
    // Na middernacht kijk je naar een andere dag; de stroom volgt mee.
    kijkNaar(nieuw: string) {
      dag = nieuw;
      if (ws && ws.readyState === 1) ws.send(JSON.stringify({ soort: 'dag', datum: nieuw }));
    },
    stop() {
      dicht = true;
      if (wachten) clearTimeout(wachten);
      if (ws) { ws.onclose = null; ws.close(); }
    },
  };
}
