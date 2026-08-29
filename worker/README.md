# De achterkant

Eén Cloudflare Worker doet twee dingen: de app uitserveren (dat zijn de bestanden
in `public/`) en `/api/*` afhandelen. Statische bestanden zijn bij Cloudflare
gratis en ongemeten, dus de app kost niets; alleen `/api` draait code.

Dat het één ding is, is de bedoeling. De app en de api staan op hetzelfde adres,
dus er is geen CORS nodig en niets om te configureren — en de proeven ernaast
(`mobiel/` in React Native, `ios/` in Swift) praten met precies dezelfde
adressen.

```
routine.<jij>.workers.dev/            → public/index.html
                         /icon-*.png  → public/
                         /routine.json
                         /api/lees    → worker/index.js
```

## Neerzetten

```bash
npm install
npx wrangler secret put ANTHROPIC_API_KEY     # van console.anthropic.com
npx wrangler deploy
```

Meer is het niet: `SLEUTEL` heb je pas nodig als er een client van buiten de
browser bij komt (zie onder).

### Zonder laptop

Het kan ook helemaal vanuit de browser, zonder `wrangler`. In het Cloudflare-
dashboard: **Workers & Pages → Create application → Import a repository**, koppel
GitHub, kies deze repo. Bij de instellingen:

| Veld | Waarde |
|---|---|
| Build command | `npm install && node stempel.mjs` |
| Deploy command | `npx wrangler deploy` |

Daarna **Save and Deploy**. Cloudflare bouwt vanaf dat moment bij elke push naar
`main` zelf, dus de Cloudflare-baan in de GitHub-workflow heb je dan niet meer
nodig.

De sleutel zet je er in dezelfde webpagina bij: **je Worker → Settings →
Variables and Secrets → Add**, type *Secret*, naam `ANTHROPIC_API_KEY`.

### Vanzelf uitrollen

`.github/workflows/deploy.yml` doet `wrangler deploy` bij elke push naar `main`,
zodra deze twee bij **Settings → Secrets and variables → Actions** staan:

| Secret | Waar |
|---|---|
| `CLOUDFLARE_API_TOKEN` | Cloudflare → My Profile → API Tokens, sjabloon *Edit Cloudflare Workers* |
| `CLOUDFLARE_ACCOUNT_ID` | staat rechts op je Workers-overzicht |

Staan ze er niet, dan slaat die stap zichzelf over in plaats van rood te worden.
Dit is precies waar GitHub-secrets wél voor bedoeld zijn: ze bestaan alleen
tijdens de build en komen nergens in iets gepubliceerds terecht — anders dan
`routine.json`, dat gewoon openbaar is.

### Zelf draaien

```bash
npx wrangler dev
```

Draait alles op `http://localhost:8787` — app en api, net als live. Secrets komen
dan uit een `.dev.vars` ernaast:

```
ANTHROPIC_API_KEY = "sk-ant-..."
```

Dat bestand staat in `.gitignore` en hoort daar te blijven; het is het enige
plekje in deze repo waar een echte sleutel kan belanden.

## Een reservekopie

Er zit geen exportknop op een Durable Object en geen console waar je even in kunt
kijken, dus dat doet [`reservekopie.mjs`](../reservekopie.mjs):

```bash
ROUTINE_ADRES=https://routine.jouwnaam.workers.dev npm run reservekopie
```

Dat zet de inhoud plus de vinkjes van de afgelopen zeven dagen als één bestand in
`reservekopie/`. Verder terug heeft geen zin: het huis ruimt oudere dagen zelf op.

Terugzetten gaat per bestand, en alleen de inhoud:

```bash
ROUTINE_ADRES=... node reservekopie.mjs --terug reservekopie/2026-08-29-2115.json
```

De vinkjes staan er wel in om te kunnen kijken wat er was, maar gaan niet terug —
een ochtend die al geweest is opnieuw afvinken helpt niemand. Staat er een
`SLEUTEL`, zet die dan in `ROUTINE_SLEUTEL`.

## Wie mag erbij

De Worker stuurt met opzet **geen CORS-kopjes**. Daardoor kan een pagina op een
ander adres hier niet bij: de browser blokkeert het antwoord. De app zelf staat
op hetzelfde adres en heeft er dus niets voor nodig.

Een app buiten de browser kent geen CORS en heeft daar dus ook niets aan. Zet
daarvoor een `SLEUTEL` neer:

```bash
npx wrangler secret put SLEUTEL
```

Dan wil `/api/*` een `X-Routine-Sleutel`-kopje met dat woord. Zet hetzelfde woord
bij `assistentSleutel` in `routine.json`, anders komt de web-app er zelf ook niet
meer langs.

Wees eerlijk over wat dat is: een drempel, geen slot. Het woord staat ook in
`routine.json` en dat bestand is openbaar. Het houdt scanners tegen, niet iemand
die de app openmaakt. Echt dichtzetten is inloggen — zie *Straks* hieronder.

## `POST /api/lees`

Erin: het bericht dat de ouder plakt óf zelf typt — allebei gaat door dezelfde
weg.

```json
{
  "tekst": "het geplakte bericht",
  "vandaag": "2026-08-27",
  "ronde": 1,
  "kinderen": [{ "id": "emma", "naam": "Emma", "kenmerken": { "schoolgroep": "1-2B" } }]
}
```

Alleen de tekst die je plakt, plus de voornamen en kenmerken van de kinderen —
die zijn nodig om te weten bij wie iets hoort.

Eruit komt één van drie dingen. De vorm staat vast, want het antwoord wordt met
een JSON-schema afgedwongen (`output_config.format`):

```jsonc
{ "type": "vraag", "sleutel": "schoolgroep", "vraag": "Wie zit waarin?",
  "opties": ["1-2A", "1-2B"], "meerkeuze": false }

{ "type": "voorstellen", "items": [
  // elke week terug → het weekritme; dagen in plaats van een datum
  { "soort": "weekritme", "icoon": "🎾", "tekst": "Tennis", "dagen": ["di"],
    "tijd": "18:00", "tot": "19:00", "wie": ["emma"], "bron": "iedere dinsdag tennis Emma" },
  // één dag, en verder niets te doen → Eenmalig, als agendaregel
  { "soort": "bijzonderheid", "icoon": "🚸", "tekst": "Verkeersles",
    "datum": "2026-09-04", "tijd": "", "wie": ["emma"], "bron": "de zin uit de mail" },
  // één dag, en er moet iets gebeuren → Eenmalig, als kaartje om af te vinken
  { "soort": "stap", "ritme": "dag", "groep": "Weggaan", "icoon": "🚲",
    "tekst": "Fiets mee", "datum": "2026-09-04", "wie": ["emma"],
    "bron": "de zin uit de mail" } ] }

{ "type": "niets" }
```

De systeemprompt vraagt ook om vooruitdenken: bij een verjaardag hoort een
cadeau dat op tijd in huis is, bij een sportdag horen gymspullen. Zulke
voorstellen zetten in `bron` dat ze zelf bedacht zijn, zodat de ouder ziet wat er
letterlijk stond en wat erbij verzonnen is.

Gaat er iets mis, dan komt er `{ "fout": "..." }` met een leesbare reden; de app
laat die letterlijk zien.

De app vraagt hooguit twee keer door; `ronde` zegt de hoeveelste het is, en vanaf
2 hoort de uitlezer het te doen met wat hij heeft.

## Model en kosten

`claude-opus-5` op `effort: "low"` — uitlezen is licht werk, en het schema doet
het zware sturen al. Een schoolmail is ongeveer 1300 tokens in en 500 uit, dus
rond de twee cent per keer (Opus 5: $5 per miljoen in, $25 per miljoen uit). Een
vraagronde telt als een tweede keer. Geschat, niet gemeten.

De 10 ms cpu-tijd van het gratis plan is geen probleem: wachten op de api kost
geen cpu.

Goedkoper mag, zonder de code aan te raken, met een var in `wrangler.toml`:

```toml
[vars]
MODEL = "claude-sonnet-5"
MOEITE = "medium"
```

## De opslag

Naast de uitlezer staat hier de opslag: `/api/opslag/*`. Alles van dit gezin zit
in één *huis* — een Durable Object, klasse `Huis` in `huis.js` — en de Worker doet
er niets anders mee dan de sleutel controleren en het verzoek doorgeven.

```
GET    /api/opslag/inhoud            wat er nu in de app staat
PUT    /api/opslag/inhoud            het bewerkte geheel
GET    /api/opslag/dag?datum=…       de vinkjes van die dag
PUT    /api/opslag/vink              { datum, sleutel, aan }
DELETE /api/opslag/ritme             { datum, ritme } — opnieuw beginnen
GET    /api/opslag/stroom?datum=…    WebSocket: alles wat er verandert
```

Welk huis staat in `GEZIN` in `wrangler.toml`, op de server dus. De app hoeft dat
niet te weten, en er hoeft ook niets over de lijn dat je zou moeten raden.

**Waarom een Durable Object en geen D1.** Het gaat om de stroom. Een database kan
bewaren maar niet vertellen; een Durable Object kan allebei, want het weet wie er
op dat moment verbonden is. Daarmee is `PUT /vink` één schrijfactie die meteen bij
alle open telefoons terechtkomt, zonder pollen. Dat was precies wat de oude
Firebase-opzet gaf en wat D1 niet kan.

Het is een SQLite-Durable-Object (`new_sqlite_classes` in de migratie), en die
horen bij het gratis plan. De verbindingen gebruiken de hibernation-api:
`ctx.acceptWebSocket`, niet een handler die wakker moet blijven. Een huis waar
niemand iets doet kost dus niets.

**Vinkjes zijn platte sleutels**, `<ritme>/<stap>/<persoon>`. Eén tik schrijft
precies één sleutel, dus twee telefoons die tegelijk iets aantikken overschrijven
elkaar niet. Dagen ouder dan een week ruimt het huis zelf op, bij het eerstvolgende
vinkje.

**Verhuizen.** Staat er `OVERNEMEN` in de vars, dan haalt een leeg huis die inhoud
er één keer bij en bewaart hem. Daarna wordt er niet meer gekeken.

## Straks: wie mag erbij

`/api` is nu de goede vorm voor een app in een store: gewoon HTTP, JSON en een
WebSocket, niets browser-eigens. Beide clients praten met dezelfde adressen en de
gegevens zijn alleen nog via de Worker te bereiken.

Wat er nog niet is, is wie erbij mag. Nu geldt: wie het adres van de app kent, kan
meelezen en meeschrijven — `SLEUTEL` maakt daar één gedeeld wachtwoord van, meer
niet. Voor een afvinklijstje thuis is dat genoeg; met een app in een store niet
meer. De volgende stap is dus aanmelden:

```
POST /api/aanmelden          → een token voor dit gezin
```

en `GEZIN` uit de vars halen: het huis volgt dan uit het token in plaats van uit
de configuratie. Dat is werk voor als er een tweede gezin bijkomt.
