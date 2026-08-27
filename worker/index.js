// De achterkant. Eén Worker die twee dingen doet: de app uitserveren (dat zijn
// de bestanden in public/, en dat kost niets) en /api/* afhandelen.
//
// Nu zit er één ding onder /api: de uitlezer achter 'Uit een bericht overnemen'.
// Die staat hier en niet in de pagina, zodat de sleutel van de Claude-api op de
// server blijft. Alles wat er later bij komt — inloggen, het ritme zelf — hoort
// hier ook, want dan kan een React Native app dezelfde adressen gebruiken.
import Anthropic from '@anthropic-ai/sdk';

const MODEL = 'claude-opus-5';
const MOEITE = 'low';            // low | medium | high — uitlezen is licht werk
const MAX_TEKST = 20000;         // een mail, geen boek
const DAGNAMEN = ['zondag','maandag','dinsdag','woensdag','donderdag','vrijdag','zaterdag'];

// Wat er terug mag komen. Met dit schema is het antwoord altijd geldige JSON in
// deze vorm; de app hoeft niets te repareren.
const SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['type'],
  properties: {
    type: { type: 'string', enum: ['vraag', 'voorstellen', 'niets'] },

    // bij type 'vraag'
    sleutel: { type: 'string' },
    vraag: { type: 'string' },
    opties: { type: 'array', items: { type: 'string' } },
    meerkeuze: { type: 'boolean' },

    // bij type 'voorstellen'
    items: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['soort', 'icoon', 'tekst', 'datum', 'wie', 'bron'],
        properties: {
          soort: { type: 'string', enum: ['bijzonderheid', 'stap'] },
          icoon: { type: 'string' },
          tekst: { type: 'string' },
          datum: { type: 'string', format: 'date' },
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

const SYSTEEM = `Je haalt afspraken uit berichten van school, sportclub en bso, voor een gezinsapp met een dagritme per kind.

Je krijgt het bericht, de datum van vandaag, en de kinderen die in de app staan met wat er van ze bekend is (schoolgroep, team, en wat er verder aan kenmerken bij ze staat).

Antwoord met één van drie dingen.

1. "vraag" — alleen als het bericht onderscheid maakt dat je met de bekende kenmerken niet kunt maken. Bijvoorbeeld: het noemt per schoolgroep (1-2A tot en met 1-2D) een andere dag, en van geen van de kinderen is de schoolgroep bekend. Stel dan precies één vraag, met de mogelijke waarden als "opties", en een korte "sleutel" waaronder het antwoord bij het kind bewaard wordt: schoolgroep, team, bsogroep. Kun je het ook zonder, vraag dan niets — een voorstel voor iedereen is beter dan een vraag. Bij ronde 2 of hoger stel je geen vraag meer, maar doe je het met wat je hebt.

2. "voorstellen" — wat er in de app moet komen. Per voorstel:
   - "soort": "bijzonderheid" voor iets dat op één dag speelt en in de weekagenda hoort (een uitje, een ouderavond, een verkeersles, een wedstrijd). "stap" voor iets dat een kind die dag zelf moet dóén en tussen de afvinkbare stappen hoort — meestal iets meenemen. Zet bij een stap ook "ritme" ("dag" voor de ochtend, "nacht" voor de avond) en "groep": de naam van de groep waar hij hoort, meestal "Weggaan".
   - "tekst": kort, zoals je het tegen een kind zegt. "Verkeersles", "Fiets mee", "Gymspullen mee". Geen hele zinnen.
   - "datum": jjjj-mm-dd, uitgerekend vanaf vandaag. Staat er geen jaartal bij, dan is het de eerstvolgende keer.
   - "tijd": de begintijd, alleen als het bericht die noemt, anders leeg. "tot" is de eindtijd, ook alleen als die er staat.
   - "wie": de ids van de kinderen die het betreft, uit de meegegeven lijst. Leeg betekent iedereen; gebruik dat als het bericht geen onderscheid maakt. Gaat een dag over een groep waar geen van de kinderen in zit, laat dat voorstel dan helemaal weg.
   - "bron": de zin uit het bericht waar dit vandaan komt, letterlijk overgenomen, zodat de ouder het kan nakijken.
   - "icoon": één emoji die erbij past.
   Eén regel per ding per dag; geen dubbele voorstellen.

3. "niets" — er staat geen afspraak of datum in het bericht.

Ga alleen af op wat er staat. Verzin geen data, tijden of namen die er niet in staan.`;

// De api zet zijn uitleg in error.message; err.message zelf heeft de status en
// de hele json er nog omheen staan.
function reden(err){
  const uitLijf = err && err.error && err.error.error && err.error.error.message;
  return String(uitLijf || (err && err.message) || err).slice(0, 400);
}

function antwoord(inhoud, status){
  return new Response(JSON.stringify(inhoud), {
    status: status || 200,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}

// Geen CORS-kopjes, met opzet: daardoor kan een browser op een ander adres hier
// niet bij. Een app buiten de browser kent geen CORS en heeft er ook niets aan,
// dus daarvoor is er SLEUTEL — zie de README.
function magErbij(request, env){
  if(!env.SLEUTEL) return true;
  return request.headers.get('X-Routine-Sleutel') === env.SLEUTEL;
}

function kindregel(kind){
  const kenmerken = Object.entries(kind.kenmerken || {})
    .map(([sleutel, waarde]) => `${sleutel}: ${waarde}`).join(', ');
  return `- id ${kind.id}, ${kind.naam || 'naamloos'} — ${kenmerken || 'nog niets bekend'}`;
}

function vraagtekst(lading){
  const d = new Date(lading.vandaag + 'T12:00:00Z');
  const dagnaam = Number.isNaN(d.getTime()) ? '' : ` (${DAGNAMEN[d.getUTCDay()]})`;
  return [
    `Vandaag is ${lading.vandaag}${dagnaam}. Dit is ronde ${lading.ronde}.`,
    '',
    'De kinderen in de app:',
    lading.kinderen.map(kindregel).join('\n'),
    '',
    'Het bericht:',
    '"""',
    lading.tekst,
    '"""',
  ].join('\n');
}

// Alleen de velden die we kennen, en alleen van het soort dat we verwachten.
function schoneLading(ruw){
  const bericht = typeof ruw.tekst === 'string' ? ruw.tekst.trim() : '';
  const kinderen = Array.isArray(ruw.kinderen) ? ruw.kinderen : [];
  return {
    tekst: bericht.slice(0, MAX_TEKST),
    vandaag: /^\d{4}-\d{2}-\d{2}$/.test(ruw.vandaag) ? ruw.vandaag : new Date().toISOString().slice(0, 10),
    ronde: Number.isFinite(Number(ruw.ronde)) ? Math.max(1, Math.floor(Number(ruw.ronde))) : 1,
    kinderen: kinderen.slice(0, 12).map(kind => ({
      id: String(kind && kind.id || '').slice(0, 40),
      naam: String(kind && kind.naam || '').slice(0, 40),
      kenmerken: kind && typeof kind.kenmerken === 'object' && kind.kenmerken ? kind.kenmerken : {},
    })).filter(kind => kind.id),
  };
}

// POST /api/lees — bericht erin, voorstellen eruit.
async function lees(request, env){
  if(request.method !== 'POST') return antwoord({ fout: 'Alleen POST.' }, 405);
  if(!magErbij(request, env)) return antwoord({ fout: 'Verkeerde of ontbrekende sleutel.' }, 401);
  if(!env.ANTHROPIC_API_KEY) return antwoord({ fout: 'De uitlezer heeft nog geen sleutel.' }, 500);

  let ruw;
  try{ ruw = await request.json(); }
  catch{ return antwoord({ fout: 'Geen geldige JSON.' }, 400); }

  const lading = schoneLading(ruw || {});
  if(!lading.tekst) return antwoord({ type: 'niets' });

  const claude = new Anthropic({
    apiKey: env.ANTHROPIC_API_KEY,
    ...(env.ANTHROPIC_BASIS ? { baseURL: env.ANTHROPIC_BASIS } : {}),
  });

  try{
    const bericht = await claude.messages.create({
      model: env.MODEL || MODEL,
      max_tokens: 4000,
      output_config: {
        effort: env.MOEITE || MOEITE,
        format: { type: 'json_schema', schema: SCHEMA },
      },
      system: [{ type: 'text', text: SYSTEEM, cache_control: { type: 'ephemeral' } }],
      messages: [{ role: 'user', content: vraagtekst(lading) }],
    });

    const tekstblok = bericht.content.find(blok => blok.type === 'text');
    if(!tekstblok) return antwoord({ type: 'niets' });
    // Het schema garandeert de vorm, dus dit is alleen nog omzetten.
    return antwoord(JSON.parse(tekstblok.text));
  }catch(err){
    if(err instanceof Anthropic.AuthenticationError){
      console.error('sleutel klopt niet:', err.message);
      return antwoord({ fout: 'De sleutel van de uitlezer klopt niet.' }, 500);
    }
    if(err instanceof Anthropic.RateLimitError){
      return antwoord({ fout: 'Even te druk, probeer het zo nog eens.' }, 429);
    }
    // De reden gaat mee terug. Dit is een gezinsapp, geen dienst voor vreemden:
    // 'het lukte niet' laat je met lege handen staan, en de api zet zijn eigen
    // sleutel niet in een foutmelding.
    if(err instanceof Anthropic.APIError){
      console.error('api gaf', err.status, err.message);
      return antwoord({ fout: `De Claude-api gaf ${err.status}: ${reden(err)}` }, 502);
    }
    console.error('onverwacht:', err);
    return antwoord({ fout: 'Er ging iets mis in de uitlezer: ' + (err && err.message || err) }, 500);
  }
}

const ROUTES = {
  '/api/lees': lees,
};

export default {
  async fetch(request, env){
    const pad = new URL(request.url).pathname;
    const route = ROUTES[pad];
    if(route) return await route(request, env);
    if(pad.startsWith('/api/')) return antwoord({ fout: 'Onbekend adres.' }, 404);
    // Al het andere is de app zelf.
    return env.ASSETS.fetch(request);
  },
};
