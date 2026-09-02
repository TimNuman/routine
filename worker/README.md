# De achterkant

Eén Cloudflare Worker, in TypeScript, met alleen `/api/*`. De iOS-app is de
enige client; er is geen webversie meer en de Worker serveert dus ook geen
bestanden.

```
worker/
  index.ts        de routes (Hono): sleutelcontrole, /api/v2/storage/*, /api/v2/read
  house.ts        het huis: een Durable Object met de inhoud, de vinkjes en de
                  telefoons die meekijken
  assistant.ts    het uitlezen van een bericht door Claude
  types.ts        de vormen die app en server delen
  dates.ts        datumhulpjes
  env.d.ts        de secrets die wrangler.toml niet kent
  *.test.ts       de proeven; draaien in echte workerd
```

## Neerzetten

```bash
npm install
npx wrangler secret put ANTHROPIC_API_KEY     # van console.anthropic.com
npx wrangler deploy
```

Meer is het niet. `SLEUTEL` is optioneel, zie *Wie mag erbij*.

Elke push naar `main` rolt vanzelf uit via `.github/workflows/deploy.yml`, zodra
`CLOUDFLARE_API_TOKEN` en `CLOUDFLARE_ACCOUNT_ID` bij **Settings → Secrets and
variables → Actions** staan. De proeven en de typecontrole draaien daar eerst;
gaan die rood, dan wordt er niet uitgerold.

### Zelf draaien

```bash
npm start          # wrangler dev, op http://localhost:8787
npm test           # vitest, in workerd
npm run check      # wrangler types, tsc, oxlint en oxfmt --check
npm run format     # oxfmt schrijft de opmaak zelf
```

Opmaak en lint komen van [oxc](https://oxc.rs): `.oxfmtrc.json` en
`.oxlintrc.json`. De lint staat op de categorieën *correctness* en *suspicious*
als fout; wat daarbuiten valt is smaak en staat uit.

Secrets komen lokaal uit `.dev.vars`:

```
ANTHROPIC_API_KEY = "sk-ant-..."
```

Dat bestand staat in `.gitignore` en hoort daar te blijven.

`npm run check` schrijft eerst `worker-configuration.d.ts` met de types van de
runtime en van de bindings uit `wrangler.toml`. Wat daar niet in staat (de
secrets) staat in `worker/env.d.ts`.

## De opslag: `/api/v2/storage`

Alles van dit gezin zit in één *huis*: een Durable Object, klasse `House` in
`house.ts`. De Worker praat ermee over RPC; alleen de WebSocket gaat via `fetch`.

```
GET    /content            wat er nu in de app staat
PUT    /content            het bewerkte geheel (een JSON-object, tot 512 KB)
GET    /day?date=…         de vinkjes van die dag
PUT    /check              { date, key, on }
DELETE /routine            { date, routine } — opnieuw beginnen, day of night
GET    /stream?date=…      WebSocket: alles wat er verandert
```

De inhoud is voor de server een document: de app is de baas over de vorm, de
server bewaart en verspreidt hem. De vorm staat in `types.ts`.

**Vinkjes zijn platte sleutels**, `<routine>/<stap>/<persoon>`, per dag. Eén tik
schrijft precies één sleutel, dus twee telefoons die tegelijk iets aantikken
overschrijven elkaar niet. Dagen ouder dan een week ruimt het huis zelf op.

**Waarom een Durable Object en geen database.** Het gaat om de stroom. Een
database kan bewaren maar niet vertellen; een Durable Object kan allebei, want
het weet wie er op dat moment verbonden is. Een tik is daarmee één schrijfactie
die meteen bij alle open telefoons terechtkomt, zonder pollen. Het is een
SQLite-Durable-Object en de verbindingen gebruiken de hibernation-api, dus een
huis waar niemand iets doet kost niets.

Over de stroom komen deze berichten, als JSON met een `kind`:

| kind      | wanneer                                | wat erin zit                      |
|-----------|----------------------------------------|-----------------------------------|
| `start`   | zodra je verbindt, en na een dagwissel | `date`, `content`, `checks`       |
| `content` | iemand heeft iets bewerkt              | de hele nieuwe `content`          |
| `check`   | iemand vinkt aan of af                 | `date`, `key`, `on`               |
| `routine` | iemand begint opnieuw                  | `date`, `routine`                 |

Een telefoon die een andere dag wil zien stuurt `{ "kind": "day", "date": "…" }`
en krijgt een nieuwe `start`.

Welk huis staat in `HOUSEHOLD` in `wrangler.toml`, op de server. De app hoeft
dat niet te weten. Dat wordt anders zodra er accounts zijn: dan volgt het huis
uit wie er ingelogd is.

## Het uitlezen: `POST /api/v2/read`

Erin: het bericht dat de ouder plakt óf zelf typt, de datum, de hoeveelste
ronde het is, en de kinderen met hun kenmerken. Alleen voornamen en kenmerken
gaan de deur uit; de app kent zelf ook niet meer.

```json
{
  "text": "het geplakte bericht",
  "today": "2026-08-27",
  "round": 1,
  "language": "nl",
  "children": [{ "id": "emma", "name": "Emma", "traits": { "schoolgroep": "1-2B" } }]
}
```

Eruit komt één van drie dingen. De vorm staat vast, want het antwoord wordt met
een JSON-schema afgedwongen (`output_config.format`):

```jsonc
{ "type": "question", "key": "schoolgroep", "question": "Wie zit waarin?",
  "options": ["1-2A", "1-2B"], "multiple": false }

{ "type": "suggestions", "items": [
  // elke week terug → het weekritme; dagen in plaats van een datum
  { "kind": "weekly", "icon": "🎾", "text": "Tennis", "days": ["tue"],
    "time": "18:00", "until": "19:00", "who": ["emma"], "source": "iedere dinsdag tennis Emma" },
  // één dag, en verder niets te doen → een agendaregel
  { "kind": "occasion", "icon": "🚸", "text": "Verkeersles",
    "date": "2026-09-04", "who": ["emma"], "source": "de zin uit de mail" },
  // één dag, en er moet iets gebeuren → een kaartje om af te vinken
  { "kind": "step", "routine": "day", "group": "Weggaan", "icon": "🚲",
    "text": "Fiets mee", "date": "2026-09-04", "who": ["emma"],
    "source": "de zin uit de mail" } ] }

{ "type": "nothing" }
```

Gaat er iets mis, dan komt er `{ "error": "..." }` met een leesbare reden en een
passende status: 429 als Claude het te druk heeft, 502 als de api iets anders
teruggeeft, 500 als de sleutel ontbreekt of niet klopt.

### Model en kosten

`claude-opus-5` op `effort: "low"`: uitlezen is licht werk, en het schema doet
het zware sturen al. Een schoolmail is ongeveer 1300 tokens in en 500 uit, dus
rond de twee cent per keer (Opus 5: $5 per miljoen in, $25 per miljoen uit).
De systeemprompt staat in de cache, dus die telt de tweede keer nauwelijks mee.

Anders mag, zonder de code aan te raken:

```toml
[vars]
MODEL = "claude-sonnet-5"
EFFORT = "medium"
```

## Wie mag erbij

Nu geldt: wie het adres kent, kan meelezen en meeschrijven. `SLEUTEL` maakt
daar één gedeeld wachtwoord van:

```bash
npx wrangler secret put SLEUTEL
```

Dan wil `/api/*` een `X-Routine-Key`-kopje met dat woord, ook op de WebSocket.
Zet hetzelfde woord in de app (`ROUTINE_KEY` in `Info.plist`).

Dat is een drempel, geen slot: één woord voor iedereen. Voor een afvinklijstje
thuis is dat genoeg; voor een app in een store niet. Wat er dan komt, in deze
volgorde:

1. **Aanmelden** met Apple en Google. De app stuurt het id-token, de Worker
   controleert het tegen de publieke sleutels van Apple en Google en geeft een
   eigen, kortlopend JWT terug. Gebruikers, huizen en wie bij welk huis hoort
   komen in D1; het huis zelf blijft een Durable Object, per huis één.
2. **Uitnodigen**: een code of link waarmee een tweede ouder bij hetzelfde huis
   komt.
3. **Mail**: per huis een adres waar je een schoolmail naar doorstuurt.
   Cloudflare Email Routing levert die af bij de Worker, die hem uitleest en
   de voorstellen in het huis zet.
4. **MCP**, zodat een assistent buiten de app bij het huis kan.

## Een reservekopie

Er zit geen exportknop op een Durable Object, dus dat doet
[`backup.mjs`](../backup.mjs):

```bash
ROUTINE_URL=https://routine.jouwnaam.workers.dev npm run backup
```

Dat zet de inhoud plus de vinkjes van de afgelopen zeven dagen als één bestand
in `backups/`. Terugzetten gaat per bestand, en alleen de inhoud:

```bash
ROUTINE_URL=... node backup.mjs --restore backups/2026-08-29-2115.json
```

Staat er een `SLEUTEL`, zet die dan in `ROUTINE_KEY`.
