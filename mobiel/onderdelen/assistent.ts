// School, voetbal, judo en de bso sturen berichten; die wil je niet overtikken.
// Plak er een in en er komt een lijstje uit dat je met een tik overneemt. Weet
// de uitlezer iets niet — welk kind in 1-2B zit bijvoorbeeld — dan vraagt hij
// ernaar, en het antwoord blijft als kenmerk bij het kind staan.
import { lijstVan, tekst } from './inhoud';
import { dagenVan, isDatum } from './schoon';
import type { Ding } from './ding';
import type { Persoon, Ritme } from './soorten';
import type { Ruw } from './schoon';

// Op web staat de uitlezer op dezelfde Worker als de app zelf. Een telefoon
// heeft een heel adres nodig; dat komt dan uit de omgeving.
const ADRES = process.env.EXPO_PUBLIC_ASSISTENT_URL || '/api/lees';
const SLEUTEL = process.env.EXPO_PUBLIC_ASSISTENT_SLEUTEL || '';

export type Lading = {
  tekst: string; vandaag: string; ronde: number;
  kinderen: { id: string; naam: string; kenmerken: Record<string, string> }[];
};

export type Vraag = { sleutel: string; vraag: string; opties: string[]; meerkeuze: boolean };
export type Voorstel = Ding & { bron: string };

export class Uitleesfout extends Error {
  vanServer: boolean;
  constructor(bericht: string, vanServer: boolean) {
    super(bericht);
    this.vanServer = vanServer;
  }
}

export async function vraagAssistent(lading: Lading): Promise<any> {
  const kopjes: Record<string, string> = { 'Content-Type': 'application/json' };
  if (SLEUTEL) kopjes['X-Routine-Sleutel'] = SLEUTEL;
  const res = await fetch(ADRES, { method: 'POST', headers: kopjes, body: JSON.stringify(lading) });
  const uit = await res.json().catch(() => null);
  if (!res.ok) {
    // Zegt de uitlezer zelf wat er mis is, dan is dat de melding — er hoeft
    // geen 'het lukte niet' omheen.
    throw new Uitleesfout(tekst(uit && uit.fout, 'HTTP ' + res.status), Boolean(uit && uit.fout));
  }
  return uit || { type: 'niets' };
}

// Wat er terugkomt is van buiten. Het wordt hier meteen hetzelfde ding als de
// rest van de app kent: wekelijks of niet, taak of niet.
const SOORTEN = ['bijzonderheid', 'stap', 'weekritme'];

export function schoonVoorstel(ruw: any, mensen: Persoon[]): Voorstel | null {
  const soort = SOORTEN.includes(tekst(ruw?.soort)) ? tekst(ruw.soort) : 'bijzonderheid';
  const bekend = new Set(mensen.map((p) => p.id));
  const datum = isDatum(ruw?.datum) ? tekst(ruw.datum) : '';
  const uit: Voorstel = {
    icoon: tekst(ruw?.icoon, soort === 'stap' ? '⭐' : '🎉'),
    tekst: tekst(ruw?.tekst || ruw?.label),
    wekelijks: soort === 'weekritme',
    taak: soort === 'stap',
    tijd: tekst(ruw?.tijd),
    tot: tekst(ruw?.tot),
    datum,
    dagen: dagenVan(ruw?.dagen),
    wie: lijstVan<any>(ruw?.wie).map(String).filter((id) => bekend.has(id)),
    bron: tekst(ruw?.bron).slice(0, 200),
    ritme: (tekst(ruw?.ritme) === 'nacht' ? 'nacht' : 'dag') as Ritme,
    groep: tekst(ruw?.groep),
  };
  if (!uit.tekst) return null;
  // Wat elke week terugkomt heeft dagen in plaats van een datum; leeg betekent
  // daar elke dag, dus dat mag.
  return uit.wekelijks || uit.datum ? uit : null;
}

// Hetzelfde bericht twee keer plakken hoort niets dubbels op te leveren.
function dingSleutel(item: any, taak: boolean): string {
  return [tekst(taak ? item.label : item.tekst).toLowerCase(),
          tekst(item.datum), dagenVan(item.dagen).join('+'),
          lijstVan<string>(item.wie).join('+')].join('|');
}

export function alBekend(bron: Ruw, g: Ding): boolean {
  const sleutel = dingSleutel(g, g.taak);
  if (g.taak) {
    return lijstVan<any>(bron[g.ritme]).some((groep) =>
      lijstVan<any>(groep.stappen).some((stap) => dingSleutel(stap, true) === sleutel));
  }
  const lijst = g.wekelijks ? bron.overzicht : bron.events;
  return lijstVan<any>(lijst).some((item) => dingSleutel(item, false) === sleutel);
}
