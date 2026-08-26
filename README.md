# Ons dagritme

Een visueel dagritme voor kinderen: een ochtend- en een avondroutine met
afvinkbare stappen, één per kind, gedeeld tussen alle telefoons in huis.

**Live:** https://timnuman.github.io/routine/

## Hoe het werkt

- Bovenin schakel je tussen **Ochtend** en **Avond**; de pagina opent zelf op het
  ritme dat bij de klok hoort.
- Elke stap heeft een rond knopje per persoon. Tik het aan en het staat binnen een
  seconde ook op de andere telefoon.
- Ernaast (op een telefoon erboven) staat wat er die dag op het programma staat.
  's Avonds zie je wat er vanavond nog gebeurt én wat er morgen komt.
- Elke dag begint vanzelf leeg.

## Bewerken

Alles wat in de app staat, pas je in de app zelf aan. Tik op het **potlood**
rechtsboven:

- **Ochtend** en **Avond** — groepen en stappen: hernoemen, van volgorde
  wisselen, toevoegen, weghalen. Per stap kun je met het kalenderknopje instellen
  op welke dagen hij meedoet; kies je geen dag, dan hoort hij bij elke dag.
- **Mensen** — wie er meedoet, met een emoji als gezicht en een eigen kleur.
  Iedereen in die lijst krijgt een rondje bij elke stap. Namen wijzigen mag: de
  vinkjes blijven bij de juiste persoon, want die hangen aan een vast id.

**Bewaar** schrijft alles naar de database, en de andere telefoons zien het
meteen. Lukt dat niet, dan blijft het scherm open staan met de reden — er wordt
nooit stilletjes iets half opgeslagen.

`routine.json` in deze repo is alleen nog het **zaadje**: de eerste keer dat de
app een lege database vindt, zet hij die inhoud erin. Daarna is de database de
baas en hoef je dit bestand niet meer aan te raken.

## Opslag

Alles staat in een Firebase Realtime Database, onder één tak per gezin:

```
<gezin>/config                              de inhoud die je in de app bewerkt
<gezin>/<jjjj-mm-dd>/<dag|nacht>/<stap>/<persoon> = true
```

Een eigen tak per dag betekent dat het ritme 's ochtends vanzelf leeg is; takken
ouder dan een week ruimt de app bij het laden op. Aan- en afvinken schrijft
precies één persoon bij één stap, dus twee telefoons die tegelijk iets aantikken
overschrijven elkaar niet.

### Eenmalig opzetten

1. Maak op [console.firebase.google.com](https://console.firebase.google.com) een
   project en daarin een **Realtime Database** (regio `europe-west1`).
2. Zet bij **Rules** deze regels neer en publiceer ze:

   ```json
   {
     "rules": {
       "$gezin": {
         ".read": true,
         "config": { ".write": true },
         "$datum": {
           ".write": "$datum.matches(/^\\d{4}-\\d{2}-\\d{2}$/)",
           "$ritme": {
             "$stap": {
               "$persoon": { ".validate": "newData.isBoolean()" }
             }
           }
         }
       }
     }
   }
   ```

3. Zet de database-url in `routine.json`:

   ```json
   "opslag": {
     "url": "https://jouw-project-default-rtdb.europe-west1.firebasedatabase.app",
     "gezin": "een-eigen-woord"
   }
   ```

**Let op:** met deze regels kan iedereen die de url kent meelezen en meeschrijven.
Voor een afvinklijstje thuis is dat prima, maar zet er geen gevoelige dingen in,
en kies voor `gezin` liever een woord dat niet te raden is.

Werkt de database even niet, dan blijft de pagina gewoon werken: de laatst bekende
inhoud en de vinkjes van vandaag staan ook in de browser zelf.

## Op je telefoon zetten

Open de pagina en kies *Deel → Zet op beginscherm* (iOS) of *Toevoegen aan
startscherm* (Android). Hij verschijnt als **Dagritme** met een eigen icoon — een
zon boven een bed — en opent zonder browserbalk.

Omdat de app-weergave geen browserbalk heeft, is er ook geen ingebouwd
trek-om-te-verversen. Die beweging zit daarom zelf in de pagina: sleep vanaf
bovenaan naar beneden tot het rondje verschijnt en laat los.

Verder werkt de app zichzelf bij: de deploy stempelt het commit-nummer in de
pagina én in `versie.txt` ernaast, en bij elke terugkeer in de app wordt dat
vergeleken. Verschilt het, dan herlaadt de pagina met een verse url zodat de
bewaarde versie gepasseerd wordt.

Het icoon is `icon.svg`; de PNG's ernaast zijn daaruit gerenderd (32, 180, 192 en
512px, plus een ruimer opgezette `maskable`-versie voor Android, dat er een cirkel
uit snijdt).

## Publiceren

Eén statische pagina, geen build. Elke push naar `main` publiceert via
GitHub Actions (`.github/workflows/deploy.yml`) naar GitHub Pages.

## Ontwerpen

De schermontwerpen voor een mogelijke native iOS-versie staan als canvas op
[claude.ai](https://claude.ai/code/artifact/60939a36-177b-4690-ad4f-2b847ddff646).
De web-versie volgt diezelfde vormtaal.
