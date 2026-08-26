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

```json
{
  "titel": "Ons dagritme",
  "kinderen": "voor Emma & Mads",
  "dag":   [ { "icoon": "🛏️", "label": "Wakker worden" } ],
  "nacht": [ { "icoon": "🌙", "label": "Licht uit" } ]
}
```

- `titel` — de kop van de pagina (en de browsertab)
- `kinderen` — het regeltje eronder
- `dag` / `nacht` — de stappen, in volgorde; elke stap heeft een `icoon` (een emoji) en een `label`

Een lijst mag zo lang of kort zijn als je wilt. Sla het bestand op, push naar `main`,
en de pagina is bijgewerkt.

Gaat er iets mis in `routine.json` (typefout, komma vergeten), dan valt de pagina terug
op het ingebouwde standaardritme in `index.html` — je krijgt dus nooit een lege pagina.

## Publiceren

Eén statisch bestand, geen build. Elke push naar `main` publiceert via
GitHub Actions (`.github/workflows/deploy.yml`) naar GitHub Pages.
