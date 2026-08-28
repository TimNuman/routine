// Praat rechtstreeks met de Realtime Database, net als de webversie. Dit is het
// stuk dat straks achter /api verhuist; de rest van de app merkt daar niets van
// zolang deze vier functies hetzelfde blijven.
import { normaliseer } from './inhoud';
import type { Inhoud, Ritme } from './soorten';

const URL_BASIS = process.env.EXPO_PUBLIC_OPSLAG_URL
  || 'https://routine-35aaa-default-rtdb.europe-west1.firebasedatabase.app';
const GEZIN = process.env.EXPO_PUBLIC_GEZIN || 'huis-9f3k2a';

const basis = `${URL_BASIS.replace(/\/+$/, '')}/${encodeURIComponent(GEZIN)}`;

export async function haalInhoud(): Promise<Inhoud> {
  const res = await fetch(`${basis}/config.json`, { cache: 'no-store' });
  if (!res.ok) throw new Error('HTTP ' + res.status);
  return normaliseer(await res.json());
}

// De hele inhoud gaat in één keer terug: de database bewaart hem als één stuk.
export async function bewaarConfig(ruw: unknown): Promise<void> {
  const res = await fetch(`${basis}/config.json`, {
    method: 'PUT',
    body: JSON.stringify(ruw),
  });
  if (!res.ok) throw new Error('HTTP ' + res.status);
}

export type Vinkjes = Record<string, boolean>;

// Alles van vandaag in één keer; de sleutel is '<ritme>/<stap>/<persoon>'.
export async function haalVinkjes(datum: string): Promise<Vinkjes> {
  const res = await fetch(`${basis}/${datum}.json`, { cache: 'no-store' });
  if (!res.ok) return {};
  const ruw = (await res.json()) || {};
  const uit: Vinkjes = {};
  (['dag', 'nacht'] as Ritme[]).forEach((ritme) => {
    const stappen = ruw[ritme] || {};
    Object.keys(stappen).forEach((stap) => {
      Object.keys(stappen[stap] || {}).forEach((persoon) => {
        if (stappen[stap][persoon]) uit[`${ritme}/${stap}/${persoon}`] = true;
      });
    });
  });
  return uit;
}

export function vinkSleutel(ritme: Ritme, stap: string, persoon: string) {
  return `${ritme}/${stap}/${persoon}`;
}

// Schrijft precies één persoon bij één stap, zodat twee telefoons die tegelijk
// iets aantikken elkaar niet overschrijven.
export async function schrijfVink(datum: string, sleutel: string, aan: boolean): Promise<void> {
  const pad = `${basis}/${datum}/${sleutel}.json`;
  const res = aan
    ? await fetch(pad, { method: 'PUT', body: 'true' })
    : await fetch(pad, { method: 'DELETE' });
  if (!res.ok) throw new Error('HTTP ' + res.status);
}
