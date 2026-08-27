# De uitlezer

Een Cloudflare Worker die het geplakte bericht aan Claude geeft en teruggeeft wat
er in de app zou moeten komen. Hij staat hier apart van de app, om één reden: de
sleutel van de Claude-api hoort niet in een pagina die iedereen kan openen.

Zonder deze Worker werkt de app gewoon; dan doet de ingebouwde namaak-assistent
het, die maar een handvol patronen kent.

## Neerzetten

```bash
cd assistent
npm install
npx wrangler secret put ANTHROPIC_API_KEY     # van console.anthropic.com
npx wrangler secret put SLEUTEL               # zelfverzonnen woord, zie hieronder
npx wrangler deploy
```

`wrangler deploy` geeft een adres terug, iets als
`https://routine-assistent.<jij>.workers.dev`. Dat gaat in `routine.json`:

```json
"assistent": "https://routine-assistent.jij.workers.dev",
"assistentSleutel": "het-woord-van-hierboven"
```

Zet in `wrangler.toml` bij `HERKOMST` de url waar de app draait
(`https://timnuman.github.io`); alleen die pagina komt er dan langs. Meerdere mag,
met komma's ertussen — handig als je hem ook lokaal wilt proberen.

Zelf uitproberen voordat je hem publiceert: `npx wrangler dev` draait hem op
`http://localhost:8787`, met de secrets uit een `.dev.vars`-bestand ernaast. Dat
bestand staat in `.gitignore` en hoort daar te blijven — het is het enige plekje
in deze repo waar een echte sleutel zou kunnen belanden.

## Over die sleutel

`SLEUTEL` is een drempel, geen slot: het woord staat ook in `routine.json`, en dat
bestand is openbaar. Het houdt tegen dat iemand die willekeurig `workers.dev`-adressen
afgaat jouw tegoed opmaakt — meer niet. Wie de app zelf opent kan het woord vinden.
Dat is dezelfde afweging als bij de database: goed genoeg voor thuis, niet voor
gevoelige dingen.

Wat wel hard is: de sleutel van de Claude-api staat als secret bij Cloudflare en
komt nooit in de browser.

## Wat er heen en weer gaat

Naar de Worker:

```json
{
  "tekst": "het geplakte bericht",
  "vandaag": "2026-08-27",
  "ronde": 1,
  "kinderen": [{ "id": "emma", "naam": "Emma", "kenmerken": { "schoolgroep": "1-2B" } }]
}
```

Alleen de tekst die je zelf plakt gaat mee, plus de voornamen en kenmerken van de
kinderen — die zijn nodig om te weten bij wie iets hoort. Geen achternamen, geen
adressen, geen e-mail: die staan sowieso niet in de app.

Terug komt één van drie dingen; de vorm staat vast, want het antwoord wordt met
een JSON-schema afgedwongen (`output_config.format`):

```jsonc
{ "type": "vraag", "sleutel": "schoolgroep", "vraag": "Wie zit waarin?",
  "opties": ["1-2A", "1-2B"], "meerkeuze": false }

{ "type": "voorstellen", "items": [
  { "soort": "bijzonderheid", "icoon": "🚸", "tekst": "Verkeersles",
    "datum": "2026-09-04", "tijd": "", "wie": ["emma"], "bron": "de zin uit de mail" },
  { "soort": "stap", "ritme": "dag", "groep": "Weggaan", "icoon": "🚲",
    "tekst": "Fiets mee", "datum": "2026-09-04", "wie": ["emma"],
    "bron": "de zin uit de mail" } ] }

{ "type": "niets" }
```

De app vraagt hooguit twee keer door; `ronde` zegt de hoeveelste het is, en vanaf
2 hoort de uitlezer het te doen met wat hij heeft.

## Model en kosten

`claude-opus-5` op `effort: "low"` — uitlezen is licht werk, en het schema doet het
zware sturen al. Een schoolmail is ongeveer 1300 tokens in en 500 uit, dus rond de
twee cent per keer (Opus 5: $5 per miljoen in, $25 per miljoen uit). Een vraagronde
telt als een tweede keer. Geschat, niet gemeten.

Goedkoper mag: zet `MODEL = 'claude-sonnet-5'` bovenin `worker.js` ($2 / $10), of
overrule het zonder de code aan te raken met een var in `wrangler.toml`:

```toml
[vars]
MODEL = "claude-sonnet-5"
MOEITE = "medium"
```

De vaste uitleg staat als eerste blok met `cache_control` erop, zodat een tweede
ronde hem uit de cache kan halen — dat werkt pas zodra dat blok boven de
minimumlengte voor caching uitkomt.
