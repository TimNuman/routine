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

Sla het bestand op, push naar `main`, en de pagina is bijgewerkt.

Gaat er iets mis in `routine.json` (typefout, komma vergeten), dan valt de pagina terug
op het ingebouwde standaardritme in `index.html` — je krijgt dus nooit een lege pagina.

## Publiceren

Eén statisch bestand, geen build. Elke push naar `main` publiceert via
GitHub Actions (`.github/workflows/deploy.yml`) naar GitHub Pages.
