# Ons dagritme

Een visueel dagritme voor kinderen: een ochtend- en een avondroutine met
afvinkbare stappen, één per kind, gedeeld tussen alle telefoons in huis.

**Live:** https://timnuman.github.io/routine/

## Hoe het werkt

Onderin zweeft een menubalk met drie plekken:

- **Ritme** — de stappen van vandaag als kaartjes, per groep. Bovenin schakel je
  tussen **Ochtend** en **Avond**; de app opent zelf op het ritme dat bij de klok
  hoort en kleurt 's avonds donker. Elk kaartje heeft een rond gezichtje per kind
  dat meedoet: tik het aan en het staat binnen een seconde ook op de andere
  telefoon. Daarboven staat per kind hoever het is. Elke dag begint vanzelf leeg.
  Wat er die dag verder is staat er meteen bij: 's ochtends *Vandaag*, 's avonds
  *Vanavond* en *Morgen*.
- **Deze week** — een week vooruit vanaf vandaag: bovenin kies je een dag,
  daaronder staat wat er die dag speelt. Hier voeg je ook **iets bijzonders**
  toe: een verjaardag, een uitje, de tandarts. Zo'n regel staat op één datum en
  krijgt een oranje randje, en verschijnt ook bij *Vandaag* en *Morgen* op de
  ritmepagina. Wat geweest is verdwijnt vanzelf bij het eerstvolgende bewaren.
- **Instellingen** — hier bewerk je alles wat in de app staat.

De kaartjes zijn overal even breed: drie op een rij op een telefoon, vijf zodra
er ruimte is. Op een breed scherm (laptop, iPad in liggende stand) staan de
titel, de schakelaar en het menu op één regel en schuift het weekritme naar
een kolom naast de stappen.

## Bewerken

Alles wat in de app staat, pas je in de app zelf aan, onder **Instellingen**:

- **Kinderen** — wie er meedoet, met een emoji als gezicht en een eigen kleur.
  Namen wijzigen mag: de vinkjes blijven bij de juiste persoon, want die hangen
  aan een vast id.
- **Ochtendritme** en **Avondritme** — groepen en stappen.
- **Weekritme** — één lijst met alles wat er in de week speelt: school, BSO,
  sport. Elk item kent zelf de dagen waarop het valt, dus school staat er één
  keer met *ma, di, do, vr* erachter in plaats van vier keer.
- **Naam en tijden** — hoe de app heet en vanaf welk uur hij op de avond opent.

Elke regel werkt hetzelfde: rood rondje weghalen, met de greep rechts verslepen,
en de regel zelf aanraken opent een blad met alles wat erbij hoort — icoon, naam,
op welke dagen, en wie meedoet (bij het weekritme ook een tijd en of het pas
's avonds speelt). **Bewaar** zet het terug in de lijst; annuleren laat alles
zoals het was. In de lijst zie je per regel al staan op welke dagen hij valt en
voor wie hij is.

Iconen typ je niet; overal waar er één staat opent een **kiezer** met emoji per
onderwerp — dagritme, eten, spelen, huis, dieren, mensen, dingen.

Een taak is standaard voor iedereen. Wil je er één kind aan hangen, kies dan
onder **Wie doet mee** wie het betreft; alleen die kinderen krijgen dan een
rondje bij die stap, en hun teller telt hem mee. Hetzelfde geldt voor een regel
in het weekritme — daar verschijnt de naam als gekleurd label.

**Gereed** schrijft alles naar de database, en de andere telefoons zien het
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

De schermontwerpen staan als canvas op
[claude.ai](https://claude.ai/code/artifact/60939a36-177b-4690-ad4f-2b847ddff646).
De web-versie volgt die vormtaal: melkglazen kaarten, een zwevende menubalk en
een verlopend behang dat 's avonds donker wordt.
