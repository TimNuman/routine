// Dezelfde vorm als de webversie: alles wat uit de database komt wordt hier
// eerst gladgestreken, zodat de schermen niets meer hoeven te controleren.
import type { Agendaitem, Eenmalig, Groep, Inhoud, Persoon, Ritme, Stap, Weekitem } from './soorten';

export const DAGEN = ['zo', 'ma', 'di', 'wo', 'do', 'vr', 'za'];
export const KLEUREN = ['#2FA37C', '#7C6BD6', '#D9724F', '#3B82C4', '#C2417E', '#E0A33E'];
export const DAGNAMEN = ['zondag', 'maandag', 'dinsdag', 'woensdag', 'donderdag', 'vrijdag', 'zaterdag'];
export const WEEKDAGEN = ['ma', 'di', 'wo', 'do', 'vr', 'za', 'zo'];
export const DAGLETTERS: Record<string, string> = { ma: 'M', di: 'D', wo: 'W', do: 'D', vr: 'V', za: 'Z', zo: 'Z' };
export const MAANDEN = ['januari', 'februari', 'maart', 'april', 'mei', 'juni', 'juli',
  'augustus', 'september', 'oktober', 'november', 'december'];

export function datumTekst(d: Date): string {
  return `${DAGNAMEN[d.getDay()]} ${d.getDate()} ${MAANDEN[d.getMonth()]}`;
}

// De week waar een dag in valt, met maandag vooraan.
export function weekVan(d: Date, weken = 0): Date[] {
  const begin = new Date(d);
  begin.setDate(begin.getDate() - ((begin.getDay() + 6) % 7) + weken * 7);
  begin.setHours(0, 0, 0, 0);
  return Array.from({ length: 7 }, (_, i) => {
    const dag = new Date(begin);
    dag.setDate(begin.getDate() + i);
    return dag;
  });
}

export function lijstVan<T>(waarde: unknown): T[] {
  if (Array.isArray(waarde)) return waarde.filter((x) => x != null) as T[];
  if (waarde && typeof waarde === 'object') {
    return Object.keys(waarde as object)
      .sort((a, b) => Number(a) - Number(b))
      .map((k) => (waarde as Record<string, T>)[k])
      .filter((x) => x != null);
  }
  return [];
}

export function tekst(waarde: unknown, terugval = ''): string {
  const s = typeof waarde === 'string' ? waarde.trim() : '';
  return s || terugval;
}

function dagenVan(waarde: unknown): string[] {
  return lijstVan<string>(waarde)
    .map((d) => String(d).trim().slice(0, 2).toLowerCase())
    .filter((d) => DAGEN.includes(d));
}

// 'wie' leeg betekent iedereen; oudere gegevens gebruikten één 'persoon'.
function wieVan(item: any): string[] {
  const uit = lijstVan<string>(item?.wie).map(String);
  const enkel = tekst(item?.persoon);
  if (!uit.length && enkel) uit.push(enkel);
  return uit;
}

function maakGroepen(waarde: unknown): Groep[] {
  const lijst = lijstVan<any>(waarde);
  if (!lijst.length) return [];
  const gegroepeerd = lijst.some((i) => i && (i.stappen !== undefined || i.groep !== undefined));
  const rauw = gegroepeerd ? lijst : [{ groep: '', tijd: '', stappen: lijst }];
  return rauw.map((item) => ({
    groep: tekst(item?.groep),
    tijd: tekst(item?.tijd),
    stappen: lijstVan<any>(item?.stappen).map(
      (s): Stap => ({
        icoon: tekst(s?.icoon, '⭐'),
        label: tekst(s?.label),
        dagen: dagenVan(s?.dagen),
        datum: /^\d{4}-\d{2}-\d{2}$/.test(tekst(s?.datum)) ? tekst(s.datum) : '',
        wie: wieVan(s),
      }),
    ),
  }));
}

// Een tijd bestaat uit een begin en een eind, allebei optioneel. Stond er
// vroeger één veld met '8:00 - 8:15' in, dan gaat dat hier alsnog uit elkaar.
function tijden(ruw: any): { tijd: string; tot: string } {
  let tijd = tekst(ruw?.tijd);
  let tot = tekst(ruw?.tot);
  if (!tot) {
    const m = /^(.*?)\s*(?:–|—|-|tot|t\/m)\s*(.+)$/i.exec(tijd);
    if (m && uurUitTijd(m[1]) !== null && uurUitTijd(m[2]) !== null) {
      tijd = m[1].trim();
      tot = m[2].trim();
    }
  }
  return { tijd, tot };
}

// Het uur uit een tijd zoals je hem opschrijft: '19:30', '8.00 - 8.15', '15u'.
export function uurUitTijd(waarde: unknown): number | null {
  const t = tekst(waarde);
  const m = /(\d{1,2})\s*[:.uh]\s*(\d{2})?/i.exec(t) || /^\s*(\d{1,2})\s*$/.exec(t);
  if (!m) return null;
  const uur = Number(m[1]);
  return uur >= 0 && uur <= 23 ? uur : null;
}

// De begintijd beslist of iets bij Overdag of bij Vanavond hoort; staat alleen
// de eindtijd er, dan telt die. Zonder tijd telt nog wat er ooit is aangevinkt.
export function isAvond(item: { tijd?: string; tot?: string; avond?: boolean }, vanaf: number): boolean {
  const uur = uurUitTijd(item.tijd) ?? uurUitTijd(item.tot);
  return uur === null || uur === undefined ? Boolean(item.avond) : uur >= vanaf;
}

export function tijdTekst(item: { tijd?: string; tot?: string }): string {
  const van = tekst(item.tijd), tot = tekst(item.tot);
  if (van && tot) return `${van} – ${tot}`;
  return tot ? 'tot ' + tot : van;
}

function weekitem(ruw: any): Weekitem {
  return {
    icoon: tekst(ruw?.icoon, '📅'),
    tekst: tekst(ruw?.tekst),
    ...tijden(ruw),
    dagen: dagenVan(ruw?.dagen),
    wie: wieVan(ruw),
    avond: Boolean(ruw?.avond),
  };
}

// Het overzicht stond vroeger per dag ingevuld, waardoor school vijf keer in de
// database stond; zo'n oude tak wordt hier samengevoegd.
function overzichtLijst(waarde: unknown): Weekitem[] {
  if (Array.isArray(waarde) || !waarde || typeof waarde !== 'object') {
    return lijstVan<any>(waarde).map(weekitem).filter((i) => i.tekst);
  }
  const sleutels = Object.keys(waarde as object);
  const perDag = sleutels.length
    && sleutels.every((k) => DAGEN.includes(String(k).trim().slice(0, 2).toLowerCase()));
  if (!perDag) return lijstVan<any>(waarde).map(weekitem).filter((i) => i.tekst);

  const uit: Weekitem[] = [];
  const gezien = new Map<string, Weekitem>();
  ['ma', 'di', 'wo', 'do', 'vr', 'za', 'zo'].forEach((dag) => {
    lijstVan<any>((waarde as any)[dag]).forEach((ruw) => {
      const item = weekitem(ruw);
      if (!item.tekst) return;
      const sleutel = [item.icoon, item.tekst, item.tijd, item.tot, item.wie.join('+'), item.avond].join('|');
      const eerder = gezien.get(sleutel);
      if (eerder) { eerder.dagen.push(dag); return; }
      item.dagen = [dag];
      gezien.set(sleutel, item);
      uit.push(item);
    });
  });
  uit.forEach((item) => { if (item.dagen.length === 7) item.dagen = []; });
  return uit;
}

function eenmalig(ruw: any): Eenmalig {
  return {
    id: tekst(ruw?.id) || 'e' + Math.random().toString(36).slice(2, 8),
    icoon: tekst(ruw?.icoon, '🎉'),
    tekst: tekst(ruw?.tekst),
    ...tijden(ruw),
    datum: /^\d{4}-\d{2}-\d{2}$/.test(tekst(ruw?.datum)) ? tekst(ruw.datum) : '',
    wie: wieVan(ruw),
  };
}

export function normaliseer(ruw: any): Inhoud {
  const bron = ruw || {};
  const mensen = lijstVan<any>(bron.mensen).map(
    (p, i): Persoon => ({
      id: tekst(p?.id, 'p' + i),
      naam: tekst(p?.naam, 'Naamloos'),
      emoji: tekst(p?.emoji, '🙂'),
      kleur: tekst(p?.kleur, KLEUREN[i % KLEUREN.length]),
    }),
  );
  const uit: Inhoud = {
    titel: tekst(bron.titel, 'Ons dagritme'),
    avondVanaf: Number.isFinite(Number(bron.avondVanaf)) ? Math.floor(Number(bron.avondVanaf)) : 15,
    mensen,
    dag: maakGroepen(bron.dag),
    nacht: maakGroepen(bron.nacht),
    overzicht: overzichtLijst(bron.overzicht),
    events: lijstVan<any>(bron.events).map(eenmalig)
      .filter((e) => e.tekst && e.datum)
      .sort((a, b) => a.datum.localeCompare(b.datum) || a.tijd.localeCompare(b.tijd)),
  };
  const bestaat = new Set(mensen.map((p) => p.id));
  const schoon = (w: string[]) => w.filter((id) => bestaat.has(id));
  (['dag', 'nacht'] as const).forEach((r) =>
    uit[r].forEach((g) => g.stappen.forEach((s) => { s.wie = schoon(s.wie); })),
  );
  uit.overzicht.forEach((i) => { i.wie = schoon(i.wie); });
  uit.events.forEach((i) => { i.wie = schoon(i.wie); });
  return uit;
}

// Wat er die dag is: eerst het bijzondere, daaronder het vaste weekritme.
export function itemsVan(inhoud: Inhoud, d: Date): Agendaitem[] {
  const dag = DAGEN[d.getDay()];
  const datum = datumVan(d);
  const bijzonder: Agendaitem[] = inhoud.events
    .filter((e) => e.datum === datum)
    .map((e) => ({ ...e, dagen: [], avond: false, bijzonder: true }));
  const week = inhoud.overzicht.filter((i) => !i.dagen.length || i.dagen.includes(dag));
  return bijzonder.concat(week);
}

export type Blok = { kop: string; items: Agendaitem[]; later?: boolean };

// 's Ochtends wat er vandaag is; 's avonds wat er vanavond nog komt en wat
// morgen wacht.
export function ritmeBlokken(inhoud: Inhoud, ritme: 'dag' | 'nacht', nu: Date): Blok[] {
  const overdag = (d: Date) => itemsVan(inhoud, d).filter((i) => !isAvond(i, inhoud.avondVanaf));
  if (ritme !== 'nacht') return [{ kop: 'Vandaag', items: overdag(nu) }];
  const morgen = new Date(nu);
  morgen.setDate(morgen.getDate() + 1);
  return [
    { kop: 'Vanavond', items: itemsVan(inhoud, nu).filter((i) => isAvond(i, inhoud.avondVanaf)) },
    { kop: 'Morgen', items: overdag(morgen), later: true },
  ];
}

// De sleutel waaronder een vinkje in de database staat: aan de tekst van de
// stap, niet aan het volgnummer, zodat er een stap tussen kan.
export function stapSleutel(stap: Stap): string {
  return (stap.label || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '') || 'stap';
}

export function opDeze(stap: Stap, d: Date): boolean {
  if (stap.datum) return stap.datum === datumVan(d);
  if (!stap.dagen.length) return true;
  return stap.dagen.includes(DAGEN[d.getDay()]);
}

export function datumVan(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

export function aantalStappen(groepen: Groep[]): number {
  return groepen.reduce((n, g) => n + g.stappen.length, 0);
}

// Alles wat op één datum staat, bij elkaar: het bijzondere uit de agenda en een
// stap die maar één ochtend meedoet. Op datum, want zo kijk je ernaar — niet
// per lijst waar het toevallig in bewaard wordt.
export type EenmaligDing =
  | { soort: 'event'; datum: string; item: Eenmalig }
  | { soort: 'stap'; datum: string; ritme: Ritme; groep: Groep; stap: Stap };

export function eenmaligeDingen(inhoud: Inhoud): EenmaligDing[] {
  const uit: EenmaligDing[] = inhoud.events
    .filter((e) => e.datum)
    .map((item) => ({ soort: 'event', datum: item.datum, item }));
  (['dag', 'nacht'] as Ritme[]).forEach((ritme) =>
    inhoud[ritme].forEach((groep) =>
      groep.stappen.forEach((stap) => {
        if (stap.datum) uit.push({ soort: 'stap', datum: stap.datum, ritme, groep, stap });
      })));
  return uit.sort((a, b) => a.datum.localeCompare(b.datum)
    || (a.soort === 'event' ? a.item.tijd : '').localeCompare(b.soort === 'event' ? b.item.tijd : ''));
}

export function wieDoetMee(stap: Stap, mensen: Persoon[]): Persoon[] {
  return stap.wie.length ? mensen.filter((p) => stap.wie.includes(p.id)) : mensen;
}

export function zacht(hex: string, alpha: number): string {
  const m = /^#?([0-9a-f]{6})$/i.exec(hex || '');
  if (!m) return `rgba(43,45,66,${alpha})`;
  const n = parseInt(m[1], 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${alpha})`;
}
