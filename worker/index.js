import Anthropic from '@anthropic-ai/sdk';
import { suggestionToNl } from './schema.js';
export { House } from './house.js';

const MODEL = 'claude-opus-5';
const EFFORT = 'low';
const MAX_TEXT = 20000;
const DAY_NAMES = ['zondag','maandag','dinsdag','woensdag','donderdag','vrijdag','zaterdag'];

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
          days: {
            type: 'array',
            items: { type: 'string', enum: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'] },
          },
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
};

const SYSTEM = `Je vult een gezinsapp met een dagritme per kind. Je krijgt tekst van een ouder: een doorgestuurde mail van school of de club, een appje, of gewoon een zin die die ouder zelf typt ("iedere dinsdag om 18:00 tennis Emma"). Behandel allebei hetzelfde — het gaat erom wat er in de app moet komen.

Je krijgt verder de datum van vandaag en de kinderen die in de app staan met wat er van ze bekend is (schoolgroep, team, en wat er verder aan kenmerken bij ze staat).

Alle tekst die je teruggeeft is Nederlands — dat is wat de ouder en de kinderen in de app te zien krijgen. Alleen de veldnamen en de vaste waarden zijn Engels.

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

function reason(err){
  const fromBody = err && err.error && err.error.error && err.error.error.message;
  return String(fromBody || (err && err.message) || err).slice(0, 400);
}

function reply(body, status){
  return new Response(JSON.stringify(body), {
    status: status || 200,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}

function mayPass(request, env){
  if(!env.SLEUTEL) return true;
  const headers = request.headers;
  if(headers.get('X-Routine-Key') === env.SLEUTEL) return true;
  if(headers.get('X-Routine-Sleutel') === env.SLEUTEL) return true;
  const query = new URL(request.url).searchParams;
  return query.get('key') === env.SLEUTEL || query.get('sleutel') === env.SLEUTEL;
}

function childLine(child){
  const traits = Object.entries(child.traits || {})
    .map(([key, value]) => `${key}: ${value}`).join(', ');
  return `- id ${child.id}, ${child.name || 'naamloos'} — ${traits || 'nog niets bekend'}`;
}

function promptText(payload){
  const d = new Date(payload.today + 'T12:00:00Z');
  const dayName = Number.isNaN(d.getTime()) ? '' : ` (${DAY_NAMES[d.getUTCDay()]})`;
  return [
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

function cleanPayload(raw){
  const message = typeof raw.text === 'string' ? raw.text.trim() : '';
  const children = Array.isArray(raw.children) ? raw.children : [];
  return {
    text: message.slice(0, MAX_TEXT),
    today: /^\d{4}-\d{2}-\d{2}$/.test(raw.today) ? raw.today : new Date().toISOString().slice(0, 10),
    round: Number.isFinite(Number(raw.round)) ? Math.max(1, Math.floor(Number(raw.round))) : 1,
    children: children.slice(0, 12).map(child => ({
      id: String(child && child.id || '').slice(0, 40),
      name: String(child && child.name || '').slice(0, 40),
      traits: child && typeof child.traits === 'object' && child.traits ? child.traits : {},
    })).filter(child => child.id),
  };
}

function payloadFromNl(raw){
  return {
    text: raw.tekst,
    today: raw.vandaag,
    round: raw.ronde,
    children: (Array.isArray(raw.kinderen) ? raw.kinderen : []).map(child => ({
      id: child && child.id,
      name: child && child.naam,
      traits: child && child.kenmerken,
    })),
  };
}

function answerToNl(answer){
  const TYPES = { question: 'vraag', suggestions: 'voorstellen', nothing: 'niets' };
  const out = { type: TYPES[answer.type] ?? 'niets' };
  if(answer.key !== undefined) out.sleutel = answer.key;
  if(answer.question !== undefined) out.vraag = answer.question;
  if(answer.options !== undefined) out.opties = answer.options;
  if(answer.multiple !== undefined) out.meerkeuze = answer.multiple;
  if(answer.items !== undefined) out.items = answer.items.map(suggestionToNl);
  return out;
}

async function askClaude(payload, env){
  const claude = new Anthropic({
    apiKey: env.ANTHROPIC_API_KEY,
    ...(env.ANTHROPIC_BASE_URL ? { baseURL: env.ANTHROPIC_BASE_URL } : {}),
  });

  const message = await claude.messages.create({
    model: env.MODEL || MODEL,
    max_tokens: 4000,
    output_config: {
      effort: env.EFFORT || EFFORT,
      format: { type: 'json_schema', schema: SCHEMA },
    },
    system: [{ type: 'text', text: SYSTEM, cache_control: { type: 'ephemeral' } }],
    messages: [{ role: 'user', content: promptText(payload) }],
  });

  const textBlock = message.content.find(block => block.type === 'text');
  return textBlock ? JSON.parse(textBlock.text) : { type: 'nothing' };
}

async function read(request, env, version){
  const dutch = version === 1;
  const fail = (message, status) => reply(dutch ? { fout: message } : { error: message }, status);

  if(request.method !== 'POST') return fail('Alleen POST.', 405);
  if(!mayPass(request, env)) return fail('Verkeerde of ontbrekende sleutel.', 401);
  if(!env.ANTHROPIC_API_KEY) return fail('De uitlezer heeft nog geen sleutel.', 500);

  let raw;
  try{ raw = await request.json(); }
  catch{ return fail('Geen geldige JSON.', 400); }

  const payload = cleanPayload(dutch ? payloadFromNl(raw || {}) : (raw || {}));
  const nothing = dutch ? { type: 'niets' } : { type: 'nothing' };
  if(!payload.text) return reply(nothing);

  try{
    const answer = await askClaude(payload, env);
    return reply(dutch ? answerToNl(answer) : answer);
  }catch(err){
    if(err instanceof Anthropic.AuthenticationError){
      console.error('bad api key:', err.message);
      return fail('De sleutel van de uitlezer klopt niet.', 500);
    }
    if(err instanceof Anthropic.RateLimitError){
      return fail('Even te druk, probeer het zo nog eens.', 429);
    }
    if(err instanceof Anthropic.APIError){
      console.error('api returned', err.status, err.message);
      return fail(`De Claude-api gaf ${err.status}: ${reason(err)}`, 502);
    }
    console.error('unexpected:', err);
    return fail('Er ging iets mis in de uitlezer: ' + (err && err.message || err), 500);
  }
}

function householdFor(request, env){
  const name = env.HOUSEHOLD;
  if(!name) throw new Error('HOUSEHOLD is not set; refusing to guess a household name.');
  return env.HOUSE.get(env.HOUSE.idFromName(name));
}

async function storage(request, env, prefix, forward){
  let house;
  try{ house = householdFor(request, env); }
  catch(err){
    console.error(err.message);
    return reply({ error: 'The worker is misconfigured; no household is set.' }, 500);
  }
  const url = new URL(request.url);
  const rest = url.pathname.slice(prefix.length) || '/';
  const target = new URL(forward + rest + url.search, 'https://house');
  return await house.fetch(new Request(target, request));
}

export default {
  async fetch(request, env){
    const path = new URL(request.url).pathname;

    if(path.startsWith('/api/v2/storage')){
      if(!mayPass(request, env)) return reply({ error: 'Wrong or missing key.' }, 401);
      return await storage(request, env, '/api/v2/storage', '/v2');
    }
    if(path === '/api/v2/read') return await read(request, env, 2);

    if(path.startsWith('/api/opslag')){
      if(!mayPass(request, env)) return reply({ fout: 'Verkeerde of ontbrekende sleutel.' }, 401);
      return await storage(request, env, '/api/opslag', '');
    }
    if(path === '/api/lees') return await read(request, env, 1);

    if(path.startsWith('/api/v2/')) return reply({ error: 'Unknown address.' }, 404);
    if(path.startsWith('/api/')) return reply({ fout: 'Onbekend adres.' }, 404);
    return env.ASSETS.fetch(request);
  },
};
