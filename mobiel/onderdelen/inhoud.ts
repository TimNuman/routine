// Dezelfde vorm als de webversie: alles wat uit de database komt wordt hier
// eerst gladgestreken, zodat de schermen niets meer hoeven te controleren.
import type { Groep, Inhoud, Persoon, Stap } from './soorten';

export const DAGEN = ['zo', 'ma', 'di', 'wo', 'do', 'vr', 'za'];
export const KLEUREN = ['#2FA37C', '#7C6BD6', '#D9724F', '#3B82C4', '#C2417E', '#E0A33E'];

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
  };
  const bestaat = new Set(mensen.map((p) => p.id));
  (['dag', 'nacht'] as const).forEach((r) =>
    uit[r].forEach((g) => g.stappen.forEach((s) => { s.wie = s.wie.filter((id) => bestaat.has(id)); })),
  );
  return uit;
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

export function wieDoetMee(stap: Stap, mensen: Persoon[]): Persoon[] {
  return stap.wie.length ? mensen.filter((p) => stap.wie.includes(p.id)) : mensen;
}

export function zacht(hex: string, alpha: number): string {
  const m = /^#?([0-9a-f]{6})$/i.exec(hex || '');
  if (!m) return `rgba(43,45,66,${alpha})`;
  const n = parseInt(m[1], 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${alpha})`;
}
