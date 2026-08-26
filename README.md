# Ons dagritme

Een visueel dagritme voor kinderen: een dag- en een avondroutine met afvinkbare
stappen, in een dag/nacht-thema dat meeschakelt.

**Live:** https://timnuman.github.io/routine/

## Hoe het werkt

- Schakel bovenin tussen **Dag** en **Avond**; achtergrond, zon/maan en sterren volgen mee.
- Tik een stap aan om hem af te vinken, nog eens om hem terug te zetten.
- *Opnieuw beginnen* wist de vinkjes van de zichtbare routine.

De stappen staan in `index.html` in het object `routines` — icoon en label per stap,
dus aanpassen is een kwestie van die lijst wijzigen.

## Publiceren

Eén statisch bestand, geen build. Elke push naar `main` publiceert via
GitHub Actions (`.github/workflows/deploy.yml`) naar GitHub Pages.
