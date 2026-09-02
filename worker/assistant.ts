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
}

export interface Payload {
  text: string;
  today: string;
  round: number;
  language: string;
  children: Child[];
}

export interface Suggestion {
  kind: 'occasion' | 'step' | 'weekly';
  icon: string;
  text: string;
  who: string[];
  source: string;
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
  | { type: 'suggestions'; items: Suggestion[] };

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

const SYSTEM = `Je vult een gezinsapp met een dagritme per kind. Je krijgt tekst van een ouder: een doorgestuurde mail van school of de club, een appje, of gewoon een zin die die ouder zelf typt ("iedere dinsdag om 18:00 tennis Emma"). Behandel allebei hetzelfde — het gaat erom wat er in de app moet komen.

Je krijgt verder de datum van vandaag en de kinderen die in de app staan met wat er van ze bekend is (schoolgroep, team, en wat er verder aan kenmerken bij ze staat).

De taal waarin je terugschrijft staat in het bericht hieronder — dat is wat de ouder en de kinderen in de app te zien krijgen. Alleen de veldnamen en de vaste waarden zijn Engels.

Antwoord met één van drie dingen.

1. "question" — alleen als de tekst onderscheid maakt dat je met de bekende kenmerken niet kunt maken. Bijvoorbeeld: er staat per schoolgroep (1-2A tot en met 1-2D) een andere dag, en van geen van de kinderen is de schoolgroep bekend. Stel dan precies één vraag in "question", met de mogelijke waarden als "options", en een korte "key" waaronder het antwoord bij het kind bewaard wordt: schoolgroep, team, bsogroep. Kun je het ook zonder, vraag dan niets — een voorstel voor iedereen is beter dan een vraag. Bij ronde 2 of hoger stel je geen vraag meer, maar doe je het met wat je hebt.

2. "suggestions" — wat er in de app moet komen. Er zijn drie soorten ("kind"), en de keuze daartussen is het belangrijkste dat je doet:

   - "weekly": iets dat elke week terugkomt. "Iedere dinsdag tennis", "school", "woensdag naar oma". Zet "days" op de weekdagen waarop het valt (mon tue wed thu fri sat sun); laat "days" leeg als het echt elke dag is. Geen "date".
   - "occasion": iets dat op één dag valt en verder niets van je vraagt. Een uitje, een ouderavond, een verjaardag, een wedstrijd. Zet "date".
   - "step": iets dat een kind die ene dag zelf moet dóén, en dat je afvinkt — meestal iets meenemen of klaarzetten. Zet "date", plus "routine" ("day" voor de ochtend, "night" voor de avond) en "group": de naam van het onderdeel waar het hoort, meestal "Weggaan".

   Komt iets elke week terug, kies dan weekly, ook als de tekst één datum noemt als voorbeeld. Gaat het over één keer, kies occasion of step.

   Verder per voorstel:
   - "text": kort, zoals je het tegen een kind zegt. "Tennis", "Verkeersles", "Fiets mee". Geen hele zinnen.
   - "time" is de begintijd en "until" de eindtijd, allebei alleen als ze er staan. Een step krijgt geen tijd; die hoort bij het onderdeel waar hij in staat.
   - "who": de ids van de kinderen die het betreft, uit de meegegeven lijst. Leeg betekent iedereen; gebruik dat als de tekst geen onderscheid maakt. Gaat iets over een groep waar geen van de kinderen in zit, laat dat voorstel dan helemaal weg.
   - "icon": één emoji die erbij past.
   - "source": waar dit vandaan komt. Staat het er letterlijk, neem dan die zin over. Heb je het zelf bedacht (zie hieronder), schrijf dan in één korte zin waarom.

   Denk mee. Wat er staat is vaak niet alles wat er moet gebeuren: bij een verjaardag hoort een cadeau dat op tijd in huis is, bij een sportdag horen gymspullen, bij een uitje hoort soms een lunchpakket. Stel dat er gerust bij, als eigen voorstel op een dag die klopt — een cadeautje voor een verjaardag op woensdag koop je in het weekend ervoor, niet die ochtend. Zeg in "source" dat jij het bedacht hebt, zodat de ouder het kan wegklikken. Houd het bij wat een ouder ook echt zou willen: één of twee vooruitdenkers, geen lijstje van tien.

   Eén regel per ding per dag; geen dubbele voorstellen.

3. "nothing" — er valt niets uit te halen dat in de app hoort.

Ga af op wat er staat en wat daar redelijkerwijs uit volgt. Verzin geen data, tijden of namen die nergens op slaan.`;

const LANGUAGE = /^[a-zA-Z]{2,3}(-[a-zA-Z0-9]{2,8})*$/;

/** Takes whatever the client sent and keeps only what is allowed, trimmed to size. */
export function cleanPayload(raw: unknown): Payload {
  const r = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>;
  const round = Number(r.round);
  const children = Array.isArray(r.children) ? (r.children as unknown[]) : [];
  return {
    text: (typeof r.text === 'string' ? r.text.trim() : '').slice(0, MAX_TEXT),
    today: isDate(r.today) ? r.today : today(),
    round: Number.isFinite(round) ? Math.max(1, Math.floor(round)) : 1,
    language: typeof r.language === 'string' && LANGUAGE.test(r.language) ? r.language : DEFAULT_LANGUAGE,
    children: children.slice(0, MAX_CHILDREN).map(cleanChild).filter((child) => child.id),
  };
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
  };
}

function languageName(tag: string): string {
  try {
    return new Intl.DisplayNames([tag], { type: 'language' }).of(tag) ?? tag;
  } catch {
    return tag;
  }
}

function childLine(child: Child): string {
  const traits = Object.entries(child.traits)
    .map(([key, value]) => `${key}: ${value}`)
    .join(', ');
  return `- id ${child.id}, ${child.name || 'naamloos'} — ${traits || 'nog niets bekend'}`;
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
    payload.children.map(childLine).join('\n'),
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
    max_tokens: 16_000,
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
