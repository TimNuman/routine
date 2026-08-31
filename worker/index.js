import Anthropic from '@anthropic-ai/sdk';
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
    type: { type: 'string', enum: ['vraag', 'voorstellen', 'niets'] },

    sleutel: { type: 'string' },
    vraag: { type: 'string' },
    opties: { type: 'array', items: { type: 'string' } },
    meerkeuze: { type: 'boolean' },

    items: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['soort', 'icoon', 'tekst', 'wie', 'bron'],
        properties: {
          soort: { type: 'string', enum: ['bijzonderheid', 'stap', 'weekritme'] },
          icoon: { type: 'string' },
          tekst: { type: 'string' },
          datum: { type: 'string', format: 'date' },
          dagen: {
            type: 'array',
            items: { type: 'string', enum: ['ma', 'di', 'wo', 'do', 'vr', 'za', 'zo'] },
          },
          tijd: { type: 'string' },
          tot: { type: 'string' },
          wie: { type: 'array', items: { type: 'string' } },
          ritme: { type: 'string', enum: ['dag', 'nacht'] },
          groep: { type: 'string' },
          bron: { type: 'string' },
        },
      },
    },
  },
};

const SYSTEM = `Je vult een gezinsapp met een dagritme per kind. Je krijgt tekst van een ouder: een doorgestuurde mail van school of de club, een appje, of gewoon een zin die die ouder zelf typt ("iedere dinsdag om 18:00 tennis Emma"). Behandel allebei hetzelfde — het gaat erom wat er in de app moet komen.

Je krijgt verder de datum van vandaag en de kinderen die in de app staan met wat er van ze bekend is (schoolgroep, team, en wat er verder aan kenmerken bij ze staat).

Antwoord met één van drie dingen.

1. "vraag" — alleen als de tekst onderscheid maakt dat je met de bekende kenmerken niet kunt maken. Bijvoorbeeld: er staat per schoolgroep (1-2A tot en met 1-2D) een andere dag, en van geen van de kinderen is de schoolgroep bekend. Stel dan precies één vraag, met de mogelijke waarden als "opties", en een korte "sleutel" waaronder het antwoord bij het kind bewaard wordt: schoolgroep, team, bsogroep. Kun je het ook zonder, vraag dan niets — een voorstel voor iedereen is beter dan een vraag. Bij ronde 2 of hoger stel je geen vraag meer, maar doe je het met wat je hebt.

2. "voorstellen" — wat er in de app moet komen. Er zijn drie soorten, en de keuze daartussen is het belangrijkste dat je doet:

   - "weekritme": iets dat elke week terugkomt. "Iedere dinsdag tennis", "school", "woensdag naar oma". Zet "dagen" op de weekdagen waarop het valt (ma di wo do vr za zo); laat "dagen" leeg als het echt elke dag is. Geen "datum".
   - "bijzonderheid": iets dat op één dag valt en verder niets van je vraagt. Een uitje, een ouderavond, een verjaardag, een wedstrijd. Zet "datum".
   - "stap": iets dat een kind die ene dag zelf moet dóén, en dat je afvinkt — meestal iets meenemen of klaarzetten. Zet "datum", plus "ritme" ("dag" voor de ochtend, "nacht" voor de avond) en "groep": de naam van het onderdeel waar het hoort, meestal "Weggaan".

   Komt iets elke week terug, kies dan weekritme, ook als de tekst één datum noemt als voorbeeld. Gaat het over één keer, kies bijzonderheid of stap.

   Verder per voorstel:
   - "tekst": kort, zoals je het tegen een kind zegt. "Tennis", "Verkeersles", "Fiets mee". Geen hele zinnen.
   - "tijd" is de begintijd en "tot" de eindtijd, allebei alleen als ze er staan. Een stap krijgt geen tijd; die hoort bij het onderdeel waar hij in staat.
   - "wie": de ids van de kinderen die het betreft, uit de meegegeven lijst. Leeg betekent iedereen; gebruik dat als de tekst geen onderscheid maakt. Gaat iets over een groep waar geen van de kinderen in zit, laat dat voorstel dan helemaal weg.
   - "icoon": één emoji die erbij past.
   - "bron": waar dit vandaan komt. Staat het er letterlijk, neem dan die zin over. Heb je het zelf bedacht (zie hieronder), schrijf dan in één korte zin waarom.

   Denk mee. Wat er staat is vaak niet alles wat er moet gebeuren: bij een verjaardag hoort een cadeau dat op tijd in huis is, bij een sportdag horen gymspullen, bij een uitje hoort soms een lunchpakket. Stel dat er gerust bij, als eigen voorstel op een dag die klopt — een cadeautje voor een verjaardag op woensdag koop je in het weekend ervoor, niet die ochtend. Zeg in "bron" dat jij het bedacht hebt, zodat de ouder het kan wegklikken. Houd het bij wat een ouder ook echt zou willen: één of twee vooruitdenkers, geen lijstje van tien.

   Eén regel per ding per dag; geen dubbele voorstellen.

3. "niets" — er valt niets uit te halen dat in de app hoort.

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
  if(request.headers.get('X-Routine-Sleutel') === env.SLEUTEL) return true;
  return new URL(request.url).searchParams.get('sleutel') === env.SLEUTEL;
}

function childLine(child){
  const traits = Object.entries(child.kenmerken || {})
    .map(([key, value]) => `${key}: ${value}`).join(', ');
  return `- id ${child.id}, ${child.naam || 'naamloos'} — ${traits || 'nog niets bekend'}`;
}

function promptText(payload){
  const d = new Date(payload.vandaag + 'T12:00:00Z');
  const dayName = Number.isNaN(d.getTime()) ? '' : ` (${DAY_NAMES[d.getUTCDay()]})`;
  return [
    `Vandaag is ${payload.vandaag}${dayName}. Dit is ronde ${payload.ronde}.`,
    '',
    'De kinderen in de app:',
    payload.kinderen.map(childLine).join('\n'),
    '',
    'Het bericht:',
    '"""',
    payload.tekst,
    '"""',
  ].join('\n');
}

function cleanPayload(raw){
  const message = typeof raw.tekst === 'string' ? raw.tekst.trim() : '';
  const children = Array.isArray(raw.kinderen) ? raw.kinderen : [];
  return {
    tekst: message.slice(0, MAX_TEXT),
    vandaag: /^\d{4}-\d{2}-\d{2}$/.test(raw.vandaag) ? raw.vandaag : new Date().toISOString().slice(0, 10),
    ronde: Number.isFinite(Number(raw.ronde)) ? Math.max(1, Math.floor(Number(raw.ronde))) : 1,
    kinderen: children.slice(0, 12).map(child => ({
      id: String(child && child.id || '').slice(0, 40),
      naam: String(child && child.naam || '').slice(0, 40),
      kenmerken: child && typeof child.kenmerken === 'object' && child.kenmerken ? child.kenmerken : {},
    })).filter(child => child.id),
  };
}

async function read(request, env){
  if(request.method !== 'POST') return reply({ fout: 'Alleen POST.' }, 405);
  if(!mayPass(request, env)) return reply({ fout: 'Verkeerde of ontbrekende sleutel.' }, 401);
  if(!env.ANTHROPIC_API_KEY) return reply({ fout: 'De uitlezer heeft nog geen sleutel.' }, 500);

  let raw;
  try{ raw = await request.json(); }
  catch{ return reply({ fout: 'Geen geldige JSON.' }, 400); }

  const payload = cleanPayload(raw || {});
  if(!payload.tekst) return reply({ type: 'niets' });

  const claude = new Anthropic({
    apiKey: env.ANTHROPIC_API_KEY,
    ...(env.ANTHROPIC_BASE_URL ? { baseURL: env.ANTHROPIC_BASE_URL } : {}),
  });

  try{
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
    if(!textBlock) return reply({ type: 'niets' });
    return reply(JSON.parse(textBlock.text));
  }catch(err){
    if(err instanceof Anthropic.AuthenticationError){
      console.error('bad api key:', err.message);
      return reply({ fout: 'De sleutel van de uitlezer klopt niet.' }, 500);
    }
    if(err instanceof Anthropic.RateLimitError){
      return reply({ fout: 'Even te druk, probeer het zo nog eens.' }, 429);
    }
    if(err instanceof Anthropic.APIError){
      console.error('api returned', err.status, err.message);
      return reply({ fout: `De Claude-api gaf ${err.status}: ${reason(err)}` }, 502);
    }
    console.error('unexpected:', err);
    return reply({ fout: 'Er ging iets mis in de uitlezer: ' + (err && err.message || err) }, 500);
  }
}

function houseOf(env){
  const name = env.HOUSEHOLD || 'huis';
  return env.HOUSE.get(env.HOUSE.idFromName(name));
}

async function storage(request, env){
  const url = new URL(request.url);
  const rest = url.pathname.slice('/api/opslag'.length) || '/';
  const target = new URL(rest + url.search, 'https://huis');
  return await houseOf(env).fetch(new Request(target, request));
}

const ROUTES = {
  '/api/lees': read,
};

export default {
  async fetch(request, env){
    const path = new URL(request.url).pathname;

    if(path.startsWith('/api/opslag')){
      if(!mayPass(request, env)) return reply({ fout: 'Verkeerde of ontbrekende sleutel.' }, 401);
      return await storage(request, env);
    }

    const route = ROUTES[path];
    if(route) return await route(request, env);
    if(path.startsWith('/api/')) return reply({ fout: 'Onbekend adres.' }, 404);
    return env.ASSETS.fetch(request);
  },
};
