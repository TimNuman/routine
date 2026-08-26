# Ons dagritme

Een visueel dagritme voor kinderen: een dag- en een avondroutine met afvinkbare
stappen, in een dag/nacht-thema dat meeschakelt.

**Live:** https://timnuman.github.io/routine/

## Hoe het werkt

- Schakel bovenin tussen **Dag** en **Avond**; achtergrond, zon/maan en sterren volgen mee.
- Tik een stap aan om hem af te vinken, nog eens om hem terug te zetten.
- *Opnieuw beginnen* wist de vinkjes van de zichtbare routine.

## Aanpassen

Alles wat je wilt wijzigen staat in **`routine.json`** — je hoeft de HTML niet aan te raken.

- `titel` — de kop van de pagina (en de browsertab)
- `kinderen` — het regeltje eronder
- `avondVanaf` — vanaf welk uur de pagina op de avondroutine opent (standaard 15)
- `dag` / `nacht` — de stappen, in volgorde; elke stap heeft een `icoon` (een emoji) en een `label`
- `groep` / `tijd` — per rij een kopje en de tijd eronder; laat `tijd` weg als je die niet wilt

Een routine mag op twee manieren opgeschreven worden. Als **platte lijst**, die als
één rij verschijnt:

```json
"nacht": [
  { "icoon": "🍽️", "label": "Avondeten" },
  { "icoon": "🌙", "label": "Licht uit" }
]
```

Of opgedeeld in **groepen**, die elk een eigen rij met een kopje ervoor krijgen:

```json
"dag": [
  {
    "groep": "Boven",
    "tijd": "6:00 – 6:30",
    "stappen": [
      { "icoon": "🛏️", "label": "Wakker worden" },
      { "icoon": "🪥", "label": "Tanden poetsen" }
    ]
  },
  {
    "groep": "Weggaan",
    "tijd": "8:00 – 8:15",
    "stappen": [
      { "icoon": "🚪", "label": "Naar school!" }
    ]
  }
]
```

Beide vormen mogen naast elkaar gebruikt worden — de ochtend in groepen, de avond
als platte lijst, of andersom. Lijsten mogen zo lang of kort zijn als je wilt, en de
stapnummers lopen gewoon door over de groepen heen.

### Stappen op bepaalde dagen

Een stap kan een `dagen`-lijst krijgen. Staat die er, dan verschijnt de stap
alleen op die dagen; zonder `dagen` hoort een stap bij elke dag.

```json
{ "icoon": "⚽", "label": "Voetbaltas", "dagen": ["wo"] }
```

Gebruik `ma di wo do vr za zo`, of de dagen voluit (`woensdag`) — beide worden
herkend. Meerdere dagen mag: `["di", "do"]`.

De stapnummers tellen alleen wat er die dag te zien is, en valt een hele groep
weg, dan verdwijnt zijn kopje mee.

Let op: er wordt naar de dag van *vandaag* gekeken. Moet de voetbaltas dinsdagavond
al klaargezet worden, zet die stap dan in de avondroutine op `["di"]`.

Sla het bestand op, push naar `main`, en de pagina is bijgewerkt.

Gaat er iets mis in `routine.json` (typefout, komma vergeten), dan valt de pagina terug
op het ingebouwde standaardritme in `index.html` — je krijgt dus nooit een lege pagina.

## Afvinken delen tussen telefoons

Zonder instellingen worden de vinkjes per toestel bewaard (in de browser), en
elke dag begint leeg. Vul je `opslag.url` in `routine.json` in, dan delen alle
toestellen dezelfde vinkjes en verschijnt een vinkje van de één binnen een
seconde bij de ander — zonder verversen.

Eenmalig opzetten, gratis:

1. Ga naar [console.firebase.google.com](https://console.firebase.google.com),
   maak een project (Analytics mag uit).
2. **Build → Realtime Database → Create Database**, regio `europe-west1`,
   en kies **Start in locked mode**.
3. Tabblad **Rules**, plak dit en publiceer:

   ```json
   {
     "rules": {
       "$gezin": {
         ".read": true,
         "$datum": {
           ".write": "$datum.matches(/^\\d{4}-\\d{2}-\\d{2}$/)",
           "$ritme": {
             "$stap": { ".validate": "newData.isBoolean()" }
           }
         }
       }
     }
   }
   ```

4. Kopieer de database-url (`https://…-default-rtdb.europe-west1.firebasedatabase.app`)
   en zet hem in `routine.json`:

   ```json
   "opslag": {
     "url": "https://jouw-project-default-rtdb.europe-west1.firebasedatabase.app",
     "gezin": "een-eigen-woord"
   }
   ```

Hoe het werkt: de status staat per dag en per ritme onder
`<gezin>/<jjjj-mm-dd>/<dag|nacht>/<stap>`. Een eigen tak per dag betekent dat het
ritme 's ochtends vanzelf weer leeg is; takken ouder dan een week worden bij het
laden opgeruimd. Aan- en afvinken schrijft precies één stap, dus twee telefoons
die tegelijk iets aantikken overschrijven elkaar niet.

Blijft de pagina 's nachts openstaan, dan springt hij om middernacht zelf naar de
nieuwe dag.

**Let op:** met deze regels kan iedereen die de url kent meelezen en meeschrijven.
Voor een afvinklijstje thuis is dat prima, maar zet er geen gevoelige dingen in.
Kies voor `gezin` liever een woord dat niet te raden is dan je achternaam.

Werkt de database even niet, dan blijft de pagina gewoon werken; de vinkjes staan
dan alleen op dat ene toestel.

## Op je telefoon zetten

Open de pagina en kies *Deel → Zet op beginscherm* (iOS) of *Toevoegen aan startscherm*
(Android). Hij verschijnt dan als **Dagritme** met een eigen icoon — een zon boven een
bed — en opent zonder browserbalk, dus als een losse app.

Het icoon is `icon.svg`; de PNG's ernaast zijn daaruit gerenderd (32, 180, 192 en 512px,
plus een ruimer opgezette `maskable`-versie voor Android, dat er een cirkel uit snijdt).
Pas je `icon.svg` aan, render de PNG's dan opnieuw in dezelfde maten.

## Publiceren

Eén statisch bestand, geen build. Elke push naar `main` publiceert via
GitHub Actions (`.github/workflows/deploy.yml`) naar GitHub Pages.
