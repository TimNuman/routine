// Reads a message from school or the club, or a sentence a parent typed, and
// turns it into what should go into the app. Claude does the reading; this file
// owns the prompt, the shape of the answer, and the cleaning of what comes in.

import Anthropic from '@anthropic-ai/sdk';
import { isDate, today } from './dates';
import type { Routine, Weekday } from './types';
import { WEEKDAYS } from './types';

const MODEL = 'claude-opus-5';
const EFFORT = 'low';
const MAX_TEXT = 20_000;
const MAX_CHILDREN = 12;
const DEFAULT_LANGUAGE = 'nl';

export interface Child {
  id: string;
  name: string;
  traits: Record<string, string>;
  /** `yyyy-mm-dd`, or empty when nobody filled it in. */
  birthday: string;
}

/** What already stands in the app: the shape of it, so nothing is proposed twice. */
export interface House {
  day: HouseGroup[];
  night: HouseGroup[];
  week: string[];
}

export interface HouseGroup {
  name: string;
  time: string;
  steps: string[];
}

export interface Payload {
  text: string;
  today: string;
  round: number;
  language: string;
  children: Child[];
  house: House;
}

/** A child that is not in the app yet. `id` is what `who` points at. */
export interface NewChild {
  id: string;
  name: string;
  icon: string;
  birthday?: string;
  traits?: string;
  source: string;
}

export interface Suggestion {
  kind: 'occasion' | 'step' | 'weekly';
  icon: string;
  text: string;
  who: string[];
  source: string;
  /** Only on a person: the birthday, and what is known, "school: X, groep: Y". */
  birthday?: string;
  traits?: string;
  date?: string;
  days?: Weekday[];
  time?: string;
  until?: string;
  routine?: Routine;
  group?: string;
}

export type Answer =
  | { type: 'nothing' }
  | { type: 'question'; key: string; question: string; options: string[]; multiple?: boolean }
  | { type: 'suggestions'; people?: NewChild[]; items: Suggestion[] };

export const NOTHING: Answer = { type: 'nothing' };

const SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['type'],
  properties: {
    type: { type: 'string', enum: ['question', 'suggestions', 'nothing'] },

    key: { type: 'string' },
    question: { type: 'string' },
    options: { type: 'array', items: { type: 'string' } },
    multiple: { type: 'boolean' },

    // Kinderen staan apart. Ze passen niet als vijfde soort tussen de
    // voorstellen: dan zou een kind velden moeten lenen die daar iets anders
    // betekenen (date als geboortedag, group als kenmerken), en dan gaat het
    // model die velden ook bij de rest vermijden. Een eigen lijstje met eigen
    // namen is duidelijker — en het houdt het voorstel zelf op elf velden,
    // want daarboven weigert de api het schema ("Schema is too complex").
    people: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['id', 'name', 'icon', 'source'],
        properties: {
          id: { type: 'string' },
          name: { type: 'string' },
          icon: { type: 'string' },
          birthday: { type: 'string' },
          traits: { type: 'string' },
          source: { type: 'string' },
        },
      },
    },

    items: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['kind', 'icon', 'text', 'who', 'source'],
        properties: {
          kind: { type: 'string', enum: ['occasion', 'step', 'weekly'] },
          icon: { type: 'string' },
          text: { type: 'string' },
          date: { type: 'string', format: 'date' },
          days: { type: 'array', items: { type: 'string', enum: [...WEEKDAYS] } },
          time: { type: 'string' },
          until: { type: 'string' },
          who: { type: 'array', items: { type: 'string' } },
          routine: { type: 'string', enum: ['day', 'night'] },
          group: { type: 'string' },
          source: { type: 'string' },
        },
      },
    },
  },
} as const;

const SYSTEM = `Je vult een gezinsapp met een dagritme per kind. Je krijgt tekst van een ouder. Dat kan van alles zijn, en het gaat er alleen om wat er in de app moet komen:

- iets om uit te lezen: een doorgestuurde mail van school of de club, een appje, een zin die de ouder zelf typt ("iedere dinsdag om 18:00 tennis Emma");
- of een opdracht: "maak een voedings- en slaapschema voor Filip", "verzin een klusjeslijst voor Emma", "wat moet er mee op schoolkamp". Dan staat er niets uit te lezen en bedenk je het zelf, met wat je van dat kind weet.

Je krijgt verder de datum van vandaag en de kinderen die in de app staan met wat er van ze bekend is: hun geboortedag en leeftijd als die ingevuld is, en verder schoolgroep, team en wat er nog meer aan kenmerken bij ze staat.

Die leeftijd doet ertoe zodra je zelf iets bedenkt. Een baby van een maand drinkt om de drie uur en slaapt daar vier of vijf keer per dag tussendoor; een kind van vier eet drie keer op een dag en slaapt 's nachts. Reken het uit voor de leeftijd die er staat in plaats van iets algemeens neer te zetten, en noem geen leeftijd die er niet bij staat.

De taal waarin je terugschrijft staat in het bericht hieronder — dat is wat de ouder en de kinderen in de app te zien krijgen. Alleen de veldnamen en de vaste waarden zijn Engels.

Antwoord met één van drie dingen.

1. "question" — alleen als de tekst onderscheid maakt dat je met de bekende kenmerken niet kunt maken. Bij een opdracht vraag je niets: je doet een voorstel, en de ouder stelt het bij. Bijvoorbeeld: er staat per schoolgroep (1-2A tot en met 1-2D) een andere dag, en van geen van de kinderen is de schoolgroep bekend. Stel dan precies één vraag in "question", met de mogelijke waarden als "options", en een korte "key" waaronder het antwoord bij het kind bewaard wordt: schoolgroep, team, bsogroep. Kun je het ook zonder, vraag dan niets — een voorstel voor iedereen is beter dan een vraag. Bij ronde 2 of hoger stel je geen vraag meer, maar doe je het met wat je hebt.

2. "suggestions" — wat er in de app moet komen. Dat zijn twee lijstjes: "people" voor kinderen die er nog niet zijn, en "items" voor al het andere.

   **"people"** — noemt de tekst een kind dat niet in de lijst hierboven staat, dan zet je het daar neer, en niet tussen de items. Per kind: "name" de naam, "icon" een dier of gezicht dat bij hem past (🦁 🐱 🦔 🐸), "id" de voornaam in kleine letters (daarmee wijs je er in "items" naar met "who"), "birthday" de geboortedag als jjjj-mm-dd als die te maken is uit de tekst, "traits" wat er verder bekend is als "sleutel: waarde" met komma's ertussen ("school: Vondelschool, schoolgroep: 3B"), en "source" de zin waar het vandaan komt. Zet er nooit iemand in die al in de app staat.

   **"items"** — er zijn drie soorten ("kind"), en de keuze daartussen is het belangrijkste dat je doet.

   Staat de app nog leeg en beschrijft de ouder zijn gezin, dan zet je het hele huis op — en dat is meer dan de kinderen alleen. Eerst "people" met alle kinderen, en dan in "items": het ochtendritme in groepen met stappen erin, het avondritme, en school, bso, sport en clubs als weekregels. Tien tot twintig items is dan normaal; stoppen na de kinderen is een half antwoord.

   - "weekly": iets dat elke week terugkomt. "Iedere dinsdag tennis", "school", "woensdag naar oma". Zet "days" op de weekdagen waarop het valt (mon tue wed thu fri sat sun); laat "days" leeg als het echt elke dag is. Geen "date".
   - "occasion": iets dat op één dag valt en verder niets van je vraagt. Een uitje, een ouderavond, een verjaardag, een wedstrijd. Zet "date".
   - "step": iets dat een kind zelf moet dóén en dat je afvinkt. Zet "routine" ("day" voor de ochtend, "night" voor de avond) en "group": de naam van het onderdeel waar het in hoort. Twee smaken:
     - hoort het bij het vaste ritme (tanden poetsen, aankleden, tas pakken), zet dan "days" — leeg is elke dag — en geen "date". Bestaat de groep nog niet, dan maak je hem: geef "group" een naam die een kind snapt ("Boven", "Beneden", "Weggaan"), en zet in "time" en "until" de klok van dat hele onderdeel ("6:00" tot "6:30"). Een stap heeft zelf geen tijd; die van het onderdeel is genoeg.
     - gaat het om die ene dag (gymspullen mee op de sportdag), zet dan "date" en geen "days"; "group" is dan meestal "Weggaan".

   Komt iets elke week terug, kies dan weekly, ook als de tekst één datum noemt als voorbeeld. Gaat het over één keer, kies occasion of step.

   Dat ritme verzin je bij de leeftijd: een kleuter kleedt zich aan, poetst tanden en pakt zijn tas; een baby wordt verschoond, gevoed en gaat slapen. Groepen die een kind snapt: "Boven", "Beneden", "Weggaan". Ga niet verder dan wat er staat en wat daar logisch bij hoort; vijfentwintig voorstellen is veel, en meer wordt een lijst die niemand naloopt.

   **Schrijf de velden in deze volgorde**: kind, icon, text, date, days, time, until, who, routine, group, source. Een veld dat je overslaat kun je daarna niet meer invullen — zo raak je "days" en "time" kwijt, en dan staat er "elke dag" waar dinsdag hoort.

   Bij "Emma is van 3 juli 2020, groep 3B op de Vondelschool, en gaat dinsdag naar de bso van half 3 tot 6" hoort bijvoorbeeld dit rijtje, met alle velden erin die je weet:

   - in "people": id "emma" · name "Emma" · icon "🦁" · birthday "2020-07-03" · traits "school: Vondelschool, schoolgroep: 3B"
   - kind "weekly" · icon "🏫" · text "School" · days ["mon","tue","wed","thu","fri"] · who ["emma"] · source "…"
   - kind "weekly" · icon "🧸" · text "BSO" · days ["tue"] · time "14:30" · until "18:00" · who ["emma"] · source "…"
   - kind "step" · icon "🪥" · text "Tanden poetsen" · time "6:30" · until "7:00" · who ["emma"] · routine "day" · group "Boven" · source "…"

   Vraagt de ouder om een schema of een lijst, dan maak je hem in één keer af, op volgorde en met tijden erbij.

   Alles wat je afvinkt is een "step" — ook een voeding, een dutje of medicijnen, ook al komt het elke dag terug. "weekly" is voor wat er gewoon ís en waar je niets voor hoeft te doen: school, bso, voetbal, zwemles.

   Een stap heeft zelf geen tijdveld, dus bij zo'n schema zet je de klok vooraan in "text" ("07:00 voeding", "08:00 dutje") en groepeer je ze per deel van de dag: "Ochtend" (time "7:00 – 12:00") en "Middag" (time "12:00 – 18:00") in het ochtendritme ("day"), en wat na het eten komt in het avondritme ("night") als "Avond" en "Nacht". Houd het bij wat een gezin ook echt bijhoudt: liever tien regels die kloppen dan dertig.

   Verder per voorstel, in de volgorde waarin ze geschreven worden:
   - "icon": één emoji die erbij past.
   - "text": kort, zoals je het tegen een kind zegt. "Tennis", "Verkeersles", "Fiets mee". Geen hele zinnen, en geen namen erin — "Voetbal", niet "Voetbal – Mads"; wie het betreft staat in "who".
   - "time" is de begintijd en "until" de eindtijd, allebei alleen als ze er staan.
   - "who": de ids van de kinderen die het betreft — uit de meegegeven lijst, of het id dat je in dezelfde ronde zelf aan een nieuw kind gaf. Leeg betekent iedereen; gebruik dat alleen als de tekst geen onderscheid maakt. Gaat iets over een groep waar geen van de kinderen in zit, laat dat voorstel dan helemaal weg.
   - "source": waar dit vandaan komt. Staat het er letterlijk, neem dan die zin over. Heb je het zelf bedacht (zie hieronder), schrijf dan in één korte zin waarom. Zet er geen veld in dat je vergeten bent.

   Denk mee. Wat er staat is vaak niet alles wat er moet gebeuren: bij een verjaardag hoort een cadeau dat op tijd in huis is, bij een sportdag horen gymspullen, bij een uitje hoort soms een lunchpakket. Stel dat er gerust bij, als eigen voorstel op een dag die klopt — een cadeautje voor een verjaardag op woensdag koop je in het weekend ervoor, niet die ochtend. Zeg in "source" dat jij het bedacht hebt, zodat de ouder het kan wegklikken. Houd het bij wat een ouder ook echt zou willen: één of twee vooruitdenkers, geen lijstje van tien.

   Vul alles in wat je weet. Een weekregel zonder "days" betekent elke dag, en dat is zelden wat er staat; een activiteit zonder "time" terwijl er een tijd genoemd wordt is een halve regel. Laat een veld alleen weg als het er echt niet is.

   Eén regel per ding per dag; geen dubbele voorstellen. Wat er al in de app staat krijg je hieronder te zien: dat stel je niet nog eens voor, ook niet in andere woorden. De verjaardagen van de mensen in de app staan er trouwens al vanzelf in — die hoef je niet voor te stellen.

   Je voegt alleen toe. Je kunt niets wijzigen of weghalen, dus stel dat ook niet voor: schrijf het hooguit in "source" als je denkt dat er iets weg moet.

3. "nothing" — er valt niets uit te halen dat in de app hoort.

Ga af op wat er staat en wat daar redelijkerwijs uit volgt. Verzin geen data, tijden of namen die nergens op slaan.`;

const LANGUAGE = /^[a-zA-Z]{2,3}(-[a-zA-Z0-9]{2,8})*$/;

/** Takes whatever the client sent and keeps only what is allowed, trimmed to size. */
export function cleanPayload(raw: unknown): Payload {
  const r = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>;
  const round = Number(r.round);
  const children = Array.isArray(r.children) ? (r.children as unknown[]) : [];
  return {
    house: cleanHouse(r.house),
    text: (typeof r.text === 'string' ? r.text.trim() : '').slice(0, MAX_TEXT),
    today: isDate(r.today) ? r.today : today(),
    round: Number.isFinite(round) ? Math.max(1, Math.floor(round)) : 1,
    language: typeof r.language === 'string' && LANGUAGE.test(r.language) ? r.language : DEFAULT_LANGUAGE,
    children: children
      .slice(0, MAX_CHILDREN)
      .map(cleanChild)
      .filter((child) => child.id),
  };
}

const MAX_GROUPS = 12;
const MAX_STEPS = 40;
const MAX_WEEK = 40;

/** The shape of what already stands: names and clocks, no dated one-offs. */
function cleanHouse(raw: unknown): House {
  const h = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>;
  return {
    day: cleanGroups(h.day),
    night: cleanGroups(h.night),
    week: list(h.week)
      .slice(0, MAX_WEEK)
      .map((item) => String(item ?? '').slice(0, 80).trim())
      .filter(Boolean),
  };
}

function cleanGroups(raw: unknown): HouseGroup[] {
  return list(raw)
    .slice(0, MAX_GROUPS)
    .map((item) => {
      const g = (item && typeof item === 'object' ? item : {}) as Record<string, unknown>;
      return {
        name: String(g.name ?? '').slice(0, 60).trim(),
        time: String(g.time ?? '').slice(0, 40).trim(),
        steps: list(g.steps)
          .slice(0, MAX_STEPS)
          .map((step) => String(step ?? '').slice(0, 60).trim())
          .filter(Boolean),
      };
    })
    .filter((group) => group.name || group.steps.length);
}

function list(raw: unknown): unknown[] {
  return Array.isArray(raw) ? raw : [];
}

function cleanChild(raw: unknown): Child {
  const c = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>;
  const traits: Record<string, string> = {};
  if (c.traits && typeof c.traits === 'object') {
    for (const [key, value] of Object.entries(c.traits as Record<string, unknown>)) {
      traits[key.slice(0, 40)] = String(value ?? '').slice(0, 80);
    }
  }
  return {
    id: String(c.id ?? '').slice(0, 40),
    name: String(c.name ?? '').slice(0, 40),
    traits,
    birthday: isDate(c.birthday) ? (c.birthday as string) : '',
  };
}

/** How old someone is on the day of the request, in words the prompt can use. */
export function ageText(birthday: string, today: string): string {
  const born = new Date(birthday + 'T12:00:00Z');
  const now = new Date(today + 'T12:00:00Z');
  if (Number.isNaN(born.getTime()) || Number.isNaN(now.getTime()) || born > now) return '';
  const days = Math.floor((now.getTime() - born.getTime()) / 86_400_000);
  let months =
    (now.getUTCFullYear() - born.getUTCFullYear()) * 12 + (now.getUTCMonth() - born.getUTCMonth());
  if (now.getUTCDate() < born.getUTCDate()) months -= 1;
  if (months >= 24) return `${Math.floor(months / 12)} jaar`;
  if (months >= 1) return `${months} ${months === 1 ? 'maand' : 'maanden'}`;
  if (days >= 7) return `${Math.floor(days / 7)} ${days < 14 ? 'week' : 'weken'}`;
  return `${days} ${days === 1 ? 'dag' : 'dagen'}`;
}

function languageName(tag: string): string {
  try {
    return new Intl.DisplayNames([tag], { type: 'language' }).of(tag) ?? tag;
  } catch {
    return tag;
  }
}

function childLine(child: Child, today: string): string {
  const age = child.birthday ? ageText(child.birthday, today) : '';
  const known = [
    child.birthday ? `geboren ${child.birthday}${age ? ` (${age} oud)` : ''}` : '',
    ...Object.entries(child.traits).map(([key, value]) => `${key}: ${value}`),
  ].filter(Boolean);
  return `- id ${child.id}, ${child.name || 'naamloos'} — ${known.join(', ') || 'nog niets bekend'}`;
}

function houseLines(house: House): string {
  const groups = (label: string, list: HouseGroup[]) =>
    list.map((g) => `- ${label}, ${g.name || 'naamloos'}${g.time ? ` (${g.time})` : ''}: ${g.steps.join(', ') || 'nog leeg'}`);
  const lines = [
    ...groups('ochtend', house.day),
    ...groups('avond', house.night),
    ...house.week.map((item) => `- elke week: ${item}`),
  ];
  return lines.length ? lines.join('\n') : '- nog niets.';
}

export function promptText(payload: Payload): string {
  const d = new Date(payload.today + 'T12:00:00Z');
  let dayName = '';
  try {
    dayName = Number.isNaN(d.getTime())
      ? ''
      : ` (${new Intl.DateTimeFormat(payload.language, { weekday: 'long', timeZone: 'UTC' }).format(d)})`;
  } catch {
    dayName = '';
  }
  return [
    `Taal van je antwoord: ${languageName(payload.language)} (${payload.language}). Alle tekst die de ouder en de kinderen te zien krijgen schrijf je in die taal.`,
    '',
    `Vandaag is ${payload.today}${dayName}. Dit is ronde ${payload.round}.`,
    '',
    'De kinderen in de app:',
    payload.children.length
      ? payload.children.map((child) => childLine(child, payload.today)).join('\n')
      : '- nog geen. De app is leeg.',
    '',
    'Wat er al in de app staat (alleen om te weten wat je niet nog eens hoeft voor te stellen):',
    houseLines(payload.house),
    '',
    'Het bericht:',
    '"""',
    payload.text,
    '"""',
  ].join('\n');
}

export async function askAssistant(payload: Payload, env: Env): Promise<Answer> {
  const claude = new Anthropic({
    apiKey: env.ANTHROPIC_API_KEY,
    ...(env.ANTHROPIC_BASE_URL ? { baseURL: env.ANTHROPIC_BASE_URL } : {}),
  });

  const message = await claude.messages.create({
    model: env.MODEL || MODEL,
    // Ruim: bij "medium" gaat er eerst denkwerk vanaf, en een huis opzetten
    // levert twintig voorstellen. Loopt hij hier tegenaan, dan komt de lijst
    // er half uit zonder dat er een fout langskomt.
    max_tokens: 20_000,
    output_config: {
      effort: (env.EFFORT || EFFORT) as 'low' | 'medium' | 'high',
      format: { type: 'json_schema', schema: SCHEMA },
    },
    system: [{ type: 'text', text: SYSTEM, cache_control: { type: 'ephemeral' } }],
    messages: [{ role: 'user', content: promptText(payload) }],
  });

  if (message.stop_reason === 'refusal') return NOTHING;
  const block = message.content.find((b) => b.type === 'text');
  return block ? (JSON.parse(block.text) as Answer) : NOTHING;
}
