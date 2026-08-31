# Ons dagritme

Een visueel dagritme voor kinderen: een ochtend- en een avondroutine met
afvinkbare stappen, één per kind, gedeeld tussen alle telefoons in huis.

**Live:** bij Cloudflare, op je eigen `workers.dev`-adres — zie *Publiceren*.

## Hoe het werkt

Onderin zweeft een menubalk met drie plekken:

- **Ritme** — de stappen van vandaag als kaartjes, per groep. Bovenin schakel je
  tussen **Ochtend** en **Avond**; de app opent zelf op het ritme dat bij de klok
  hoort en kleurt 's avonds donker. Elk kaartje heeft een rond gezichtje per kind
  dat meedoet: tik het aan en het staat binnen een seconde ook op de andere
  telefoon. Daarboven staat per kind hoever het is. Elke dag begint vanzelf leeg.
  Wat er die dag verder is staat er meteen bij: 's ochtends *Vandaag*, 's avonds
  *Vanavond* en *Morgen*.
- **Deze week** — de week van maandag tot en met zondag: bovenin kies je een
  dag, met pijltjes ernaast om een week vooruit of terug te gaan; daaronder
  staat wat er die dag speelt. Hier voeg je ook **iets bijzonders**
  toe: een verjaardag, een uitje, de tandarts. Zo'n regel staat op één datum en
  krijgt een oranje randje, en verschijnt ook bij *Vandaag* en *Morgen* op de
  ritmepagina. Wat geweest is verdwijnt vanzelf bij het eerstvolgende bewaren.
  Daaronder staat **Typ of plak iets**: daar plak je een mail of appje in, of
  typ je gewoon wat er moet komen.
- **Instellingen** — hier bewerk je alles wat in de app staat.

De kaartjes zijn overal even breed: drie op een rij op een telefoon, vijf zodra
er ruimte is. Op een breed scherm (laptop, iPad in liggende stand) staan de
titel, de schakelaar en het menu op één regel en schuift het weekritme naar
een kolom naast de stappen.

## Bewerken

Alles wat in de app staat, pas je in de app zelf aan, onder **Instellingen**:

- **Kinderen** — wie er meedoet, met een emoji als gezicht en een eigen kleur.
  Namen wijzigen mag: de vinkjes blijven bij de juiste persoon, want die hangen
  aan een vast id. Onder **Wat we verder weten** staan de kenmerken van een kind:
  schoolgroep `1-2B`, team `JO9-3`. Meestal hoef je die niet zelf in te vullen —
  zie *Uit een bericht* hieronder.
- **Ochtendritme** en **Avondritme** — groepen en stappen.
- **Weekritme** — één lijst met alles wat er in de week speelt: school, BSO,
  sport. Elk item kent zelf de dagen waarop het valt, dus school staat er één
  keer met *ma, di, do, vr* erachter in plaats van vier keer.
Een tijd bestaat uit een begin en een eind, allebei optioneel: `8:30 – 14:15`,
alleen `18:00`, of alleen `tot 20:00`. Vrije tekst mag ook — *na school* blijft
gewoon staan.

De begintijd bepaalt waar iets terechtkomt: vanaf het uur dat je bij *Naam en
tijden* instelt (standaard 15:00) staat het bij *Vanavond*, daarvoor bij
*Overdag*. Het formulier zegt er meteen bij welke van de twee het wordt. Staat er
alleen een eindtijd, dan telt die; is er helemaal geen tijd, dan staat het bij
Overdag.

- **Eenmalig** — alles wat maar één dag geldt, op datum bij elkaar, en alleen
  hier. Elk zo'n ding is een **taak** of **agenda**: agenda is een regel bij
  Vandaag en Deze week met een tijd, een taak wordt die dag een kaartje tussen de
  stappen — en dan kies je erbij in welk ritme en bij welk onderdeel het hoort. In
  de lijst staat ✅ voor de taken. Wat geweest is verdwijnt vanzelf bij het
  eerstvolgende bewaren.

  Bij *Ochtendritme* en *Avondritme* staan die eenmalige kaartjes bewust niet
  tussen de vaste stappen; daar meldt de kaart alleen dat ze er zijn.
- **Naam en tijden** — hoe de app heet en vanaf welk uur hij op de avond opent.

Elke regel werkt hetzelfde: rood rondje weghalen, met de greep rechts verslepen,
en de regel zelf aanraken opent **hetzelfde blad**, waar je ook vandaan komt.
**Bewaar** zet het terug in de lijst; annuleren laat alles zoals het was. In de
lijst zie je per regel al staan wanneer hij valt en voor wie hij is.

Dat ene blad kan het omdat alles in deze app hetzelfde ding is met twee
schakelaars: **herhalen** of **één keer**, en **taak** of **agenda**. Een taak
vink je af; agenda staat er alleen. Die vier combinaties zijn precies de vier
plekken waar iets kan staan:

| | herhalen | één keer |
|---|---|---|
| **agenda** | weekritme | een regel bij Vandaag |
| **taak** | kaartje in een onderdeel | kaartje op één dag |

Bij een taak kies je erbij in welk ritme en bij welk onderdeel hij hoort; bij
agenda vul je een tijd in. Omzetten mag altijd, en dan verhuist het ding echt:
een stap uit het ochtendritme die je op *één keer* zet verdwijnt daar en duikt
op bij **Eenmalig**.

Elk scherm opent dat blad alleen met een andere beginstand — bij *Stap
toevoegen* staat *herhalen* en *taak* al aan met de juiste groep, bij *Item
toevoegen* staat het op *herhalen* en *agenda*, bij *Eenmalig* op *één keer* en
*agenda*.

Iconen typ je niet; overal waar er één staat opent een **kiezer** met emoji per
onderwerp — dagritme, eten, spelen, huis, dieren, mensen, dingen.

Een taak is standaard voor iedereen. Wil je er één kind aan hangen, kies dan
onder **Wie doet mee** wie het betreft; alleen die kinderen krijgen dan een
rondje bij die stap, en hun teller telt hem mee. Hetzelfde geldt voor een regel
in het weekritme — daar verschijnt de naam als gekleurd label.

**Gereed** schrijft alles naar het huis, en de andere telefoons zien het
meteen. Lukt dat niet, dan blijft het scherm open staan met de reden — er wordt
nooit stilletjes iets half opgeslagen.

Het huis is de baas over wat er in de app staat; er is geen bestand in deze
repo dat dat nog overschrijft.

## Typ of plak iets

School, voetbal, judo en de bso sturen mail. In plaats van die over te tikken
plak je hem op **Deze week** onder *Typ of plak iets*. Zelf typen mag net zo
goed: *iedere dinsdag om 18:00 tennis Emma* werkt precies zo.

Wat eruit komt is een lijstje voorstellen, elk met de zin eronder waar het
vandaan komt. Er zijn drie soorten, en de keuze daartussen wordt voor je gemaakt:

| | komt terecht bij |
|---|---|
| iets dat elke week terugkomt | **Weekritme**, met de dagen erbij |
| iets op één dag | **Eenmalig**, als regel in de agenda |
| iets dat een kind die dag moet dóén | **Eenmalig**, als kaartje om af te vinken |

Er wordt ook meegedacht. Plak je *Julia is woensdag jarig*, dan komt er naast
die verjaardag een voorstel om zaterdag een cadeautje te halen — met in de bron
dat het zelf bedacht is, zodat je het kunt wegklikken.

Elk voorstel heeft een vinkje links en de regel zelf ernaast. Het vinkje bepaalt
of het meegaat; de regel aanraken opent een formulier waarin je alles nog kunt
omgooien — naam, icoon, dag of dagen, tijd, wie het betreft, en of het een
agendaregel is of iets om af te vinken. Ook van *één dag* naar *elke week* en
terug. **Bewaar** brengt je terug in de lijst, zodat je de volgende kunt
nalopen; pas de knop onderaan zet alles in één keer in de app. Wat er al staat
komt er niet nog eens bij: dezelfde mail twee keer plakken levert niets dubbels
op.

Weet de app iets niet, dan vraagt hij het eerst. Een schoolmail die het over
groep 1-2 A tot en met D heeft is pas te plaatsen als bekend is wie waarin zit;
dan verschijnt die vraag met een rijtje knopjes per kind. Het antwoord blijft als
kenmerk bij het kind staan, dus de volgende mail van dezelfde school komt er
zonder vragen doorheen. Hij vraagt hooguit twee keer; daarna doet hij het met
wat hij heeft.

Wat de deur uit gaat is de tekst die je plakt, plus de voornamen en kenmerken van
de kinderen — die zijn nodig om te weten bij wie iets hoort. Verder niets: de app
kent zelf ook geen achternamen, adressen of mailadressen. Wat terugkomt zijn ids
die de app al had.

Het echte uitlezen doet Claude, op `/api/lees` — hetzelfde adres als de app, dus
Dat draait in de Worker en niet in de pagina, om één reden: de sleutel van de
Claude-api hoort niet in iets wat iedereen kan openen. Hoe je hem neerzet, wat hij
kost en welk protocol hij spreekt staat in [`worker/README.md`](worker/README.md).

Maak je dat veld leeg, dan neemt een ingebouwde namaak-assistent het over. Die
kent maar een handvol patronen — een datum, een groep als `1-2B`, en een paar
woorden — genoeg om de schermen te proberen zonder achterkant.


## Opslag

Alles staat achter `/api/opslag` op dezelfde Worker die de app uitserveert. Daar
zit één *huis* — een Durable Object — met twee soorten gegevens:

```
inhoud                de inhoud die je in de app bewerkt
dag:<jjjj-mm-dd>      { "<dag|nacht>/<stap>/<persoon>": true, ... }
```

Een eigen sleutel per dag betekent dat het ritme 's ochtends vanzelf leeg is;
dagen ouder dan een week ruimt het huis zelf op. Aan- en afvinken schrijft precies
één persoon bij één stap, dus twee telefoons die tegelijk iets aantikken
overschrijven elkaar niet.

### Live, op elke telefoon tegelijk

Naast lezen en schrijven is er `/api/opslag/stroom`: een WebSocket die openblijft
zolang de app openstaat. Wie iets afvinkt schrijft het naar het huis, en dat huis
vertelt het meteen aan iedereen die verbonden is — dus geen gepoll, en binnen een
seconde staat het ook op de andere telefoon.

Een Durable Object is de enige plek in het verhaal die twee dingen tegelijk kan:
gegevens bewaren en weten wie er op dat moment meekijkt. Vandaar dat het daar
staat en niet in een losse database.

Dat het een WebSocket is en geen EventSource heeft één reden: `EventSource`
bestaat niet in React Native. Een WebSocket kennen de browser en de app allebei,
dus is het één stuk code voor allebei.

Berichten die over de stroom komen:

| soort    | wanneer                          | wat erin zit                    |
| -------- | -------------------------------- | ------------------------------- |
| `begin`  | zodra je verbindt, en na een dagwissel | de hele inhoud en de vinkjes van die dag |
| `inhoud` | iemand heeft iets bewerkt        | de hele nieuwe inhoud           |
| `vink`   | iemand vinkt aan of af           | `datum`, `sleutel`, `aan`       |
| `ritme`  | iemand begint opnieuw            | `datum`, `ritme`                |

De verbinding maakt zichzelf opnieuw als hij wegvalt, met een pauze die oploopt
tot een halve minuut. Een telefoon die uit zijn slaap komt heeft geen verbinding
meer, en dat merk je pas als je het probeert.

### Eenmalig opzetten

Er is niets op te zetten: het huis wordt vanzelf gemaakt bij het eerste bezoek.
Twee dingen staan in `wrangler.toml`:

```toml
[vars]
HOUSEHOLD = "een-eigen-woord"      # welk huis; de naam staat op de server
IMPORT_FROM = ""                   # eenmalig, om te verhuizen — zie hieronder
```

`HOUSEHOLD` staat met opzet op de server en niet in de app: de app hoeft niet te weten
in welk huis hij kijkt, dus hoeft er ook niets over de lijn dat je zou moeten
raden.

**Verhuizen vanaf een oude database.** Zet in `IMPORT_FROM` het adres waar de oude
inhoud staat (bijvoorbeeld de `config.json` van een Firebase Realtime Database).
De eerste keer dat het huis leeg blijkt haalt hij die er één keer bij en bewaart
hem. Daarna wordt er niet meer gekeken en mag de regel weg. De vinkjes van vandaag
verhuizen niet mee; die zijn morgen toch weg.

**Let op:** iedereen die het adres van de app kent, kan meelezen en meeschrijven.
Voor een afvinklijstje thuis is dat prima, maar zet er geen gevoelige dingen in.
Wil je het dicht, zet dan `SLEUTEL` als secret — dan moet elk verzoek
`X-Routine-Sleutel` meesturen (of `?sleutel=` bij de WebSocket, want daar kan een
browser geen kopjes meegeven).

Werkt het huis even niet, dan blijft de pagina gewoon werken: de laatst bekende
inhoud en de vinkjes van vandaag staan ook in de browser zelf.

## Op je telefoon zetten

Open de pagina en kies *Deel → Zet op beginscherm* (iOS) of *Toevoegen aan
startscherm* (Android). Hij verschijnt als **Dagritme** met een eigen icoon — een
zon boven een bed — en opent zonder browserbalk.

Omdat de app-weergave geen browserbalk heeft, is er ook geen ingebouwd
trek-om-te-verversen. Die beweging zit daarom zelf in de pagina: sleep vanaf
bovenaan naar beneden tot het rondje verschijnt en laat los.

Bijwerken gaat zoals bij elke pagina: een nieuwe uitgave staat er na een
herlading. Het stempelen van commit-nummers dat de oude handgeschreven versie
gebruikte is weg, samen met die versie.

Het icoon is `icon.svg`; de PNG's ernaast zijn daaruit gerenderd (32, 180, 192 en
512px, plus een ruimer opgezette `maskable`-versie voor Android, dat er een cirkel
uit snijdt).

## Hoe het in elkaar zit

```
public/     de webversie: de export van mobiel/, plus de iconen
worker/     de achterkant: /api/*, en hij serveert public/ uit
mobiel/     de bron van die webversie, in React Native — zie mobiel/README.md
ios/        dezelfde app in Swift, voor de iPhone — zie ios/README.md
wrangler.toml
```

De webversie wordt nu gebouwd: `public/` is de uitvoer van `npm run bouw` in
`mobiel/` en hoort niet met de hand bewerkt te worden. De Worker heeft
`npm install` nodig, voor de Claude-sdk.

## Publiceren

Alles draait bij Cloudflare, op één adres: de app als statische bestanden (gratis
en ongemeten) en `/api/*` in dezelfde Worker. Elke push naar `main` rolt vanzelf
uit — Cloudflare bouwt zelf uit deze repo.

Zelf uitrollen kan ook: `npm run deploy`.

`.github/workflows/deploy.yml` is er alleen nog voor wie het liever via GitHub
Actions doet; bouwt Cloudflare zelf, dan mag dat bestand weg.

Zie [`worker/README.md`](worker/README.md) voor het opzetten, en voor waar dit
heen gaat nu er apps naast de webversie staan.

## Ontwerpen

De schermontwerpen staan als canvas op
[claude.ai](https://claude.ai/code/artifact/60939a36-177b-4690-ad4f-2b847ddff646).
De web-versie volgt die vormtaal: melkglazen kaarten, een zwevende menubalk en
een verlopend behang dat 's avonds donker wordt.
