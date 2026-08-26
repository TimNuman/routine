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
