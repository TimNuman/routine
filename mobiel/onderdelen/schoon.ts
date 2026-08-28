// Van en naar de vorm waarin het in de database staat. Een bewerkscherm werkt
// op een losse kopie (het concept) en pas bij Gereed gaat die er opgeschoond in.
import { DAGEN, KLEUREN, MAANDEN, WEEKDAGEN, datumVan, kenmerkenVan, lijstVan, tekst, uurUitTijd } from './inhoud';
import type { Inhoud } from './soorten';

export type Ruw = {
  titel: string;
  avondVanaf: number | string;
  mensen: any[];
  dag: any[];
  nacht: any[];
  overzicht: any[];
  events: any[];
};

export function nieuwId(): string {
  return 'p' + Math.random().toString(36).slice(2, 8);
}

export function isDatum(waarde: unknown): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(tekst(waarde));
}

export function alsDatum(waarde: unknown): Date | null {
  const t = tekst(waarde);
  if (!isDatum(t)) return null;
  const [j, m, d] = t.split('-').map(Number);
  return new Date(j, m - 1, d);
}

export function kortDatum(waarde: unknown): string {
  const d = alsDatum(waarde);
  return d ? `${WEEKDAGEN[(d.getDay() + 6) % 7]} ${d.getDate()} ${MAANDEN[d.getMonth()].slice(0, 3)}` : '';
}

export function dagenTekst(dagen: unknown): string {
  const d = lijstVan<string>(dagen);
  if (!d.length || d.length >= WEEKDAGEN.length) return '';
  return WEEKDAGEN.filter((x) => d.includes(x)).join(', ');
}

export function dagenVan(waarde: unknown): string[] {
  return lijstVan<string>(waarde)
    .map((d) => String(d).trim().slice(0, 2).toLowerCase())
    .filter((d) => DAGEN.includes(d));
}

// De begintijd beslist; staat alleen de eindtijd er, dan telt die.
export function naAvond(item: { tijd?: string; tot?: string; avond?: boolean }, vanaf: number): boolean {
  const uur = uurUitTijd(item.tijd) ?? uurUitTijd(item.tot);
  return uur === null ? Boolean(item.avond) : uur >= vanaf;
}

function uurOf(waarde: unknown, terugval: number): number {
  const n = Math.floor(Number(waarde));
  return Number.isFinite(n) && n >= 0 && n <= 23 ? n : terugval;
}

// Een losse, diepe kopie om in te bewerken zonder dat het scherm meebeweegt.
export function alsRuw(inhoud: Inhoud): Ruw {
  return JSON.parse(JSON.stringify({
    titel: inhoud.titel,
    avondVanaf: inhoud.avondVanaf,
    mensen: inhoud.mensen,
    dag: inhoud.dag,
    nacht: inhoud.nacht,
    overzicht: inhoud.overzicht,
    events: inhoud.events,
  }));
}

function schoneGroepen(lijst: unknown) {
  return lijstVan<any>(lijst).map((g) => ({
    groep: tekst(g.groep),
    tijd: tekst(g.tijd),
    stappen: lijstVan<any>(g.stappen).filter((s) => tekst(s.label)).map((s) => {
      const uit: any = { icoon: tekst(s.icoon, '⭐'), label: tekst(s.label) };
      if (isDatum(s.datum)) uit.datum = tekst(s.datum);
      const dagen = dagenVan(s.dagen);
      if (dagen.length && !uit.datum) uit.dagen = dagen;
      const wie = lijstVan<string>(s.wie);
      if (wie.length) uit.wie = wie;
      return uit;
    }),
  })).filter((g) => g.stappen.length || tekst(g.groep));
}

function schoonOverzicht(bron: unknown, vanaf: number) {
  return lijstVan<any>(bron).filter((item) => tekst(item && item.tekst)).map((item) => {
    const uit: any = { icoon: tekst(item.icoon, '📅'), tekst: tekst(item.tekst) };
    if (tekst(item.tijd)) uit.tijd = tekst(item.tijd);
    if (tekst(item.tot)) uit.tot = tekst(item.tot);
    const dagen = dagenVan(item.dagen);
    if (dagen.length && dagen.length < WEEKDAGEN.length) uit.dagen = dagen;
    const wie = lijstVan<string>(item.wie);
    if (wie.length) uit.wie = wie;
    if (naAvond(item, vanaf)) uit.avond = true;
    return uit;
  });
}

// Wat geweest is ruimt zichzelf op: een bijzonderheid van gisteren gaat er bij
// het eerstvolgende bewaren uit.
function schoonEvents(bron: unknown) {
  const grens = datumVan(new Date());
  return lijstVan<any>(bron)
    .filter((e) => tekst(e && e.tekst) && isDatum(e && e.datum))
    .filter((e) => tekst(e.datum) >= grens)
    .map((e) => {
      const uit: any = {
        id: tekst(e.id) || nieuwId(),
        icoon: tekst(e.icoon, '🎉'),
        tekst: tekst(e.tekst),
        datum: tekst(e.datum),
      };
      if (tekst(e.tijd)) uit.tijd = tekst(e.tijd);
      if (tekst(e.tot)) uit.tot = tekst(e.tot);
      const wie = lijstVan<string>(e.wie);
      if (wie.length) uit.wie = wie;
      return uit;
    });
}

export function opgeschoond(c: Ruw) {
  const vanaf = uurOf(c.avondVanaf, 15);
  return {
    titel: tekst(c.titel, 'Ons dagritme'),
    avondVanaf: vanaf,
    mensen: lijstVan<any>(c.mensen).map((p, i) => ({
      id: tekst(p.id, nieuwId()),
      naam: tekst(p.naam, 'Naamloos'),
      emoji: tekst(p.emoji, '🙂'),
      kleur: tekst(p.kleur, KLEUREN[i % KLEUREN.length]),
      kenmerken: kenmerkenVan(p.kenmerken),
    })),
    dag: schoneGroepen(c.dag),
    nacht: schoneGroepen(c.nacht),
    overzicht: schoonOverzicht(c.overzicht, vanaf),
    events: schoonEvents(c.events),
  };
}
