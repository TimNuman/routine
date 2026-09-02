# Ons dagritme

Een visueel dagritme voor kinderen: een ochtend- en een avondroutine met
afvinkbare stappen, één per kind, gedeeld tussen alle telefoons in huis.

Een iOS-app in Swift, met een achterkant op Cloudflare. Zie *Hoe het in elkaar
zit* onderaan.

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

Het echte uitlezen doet Claude, op `/api/v2/read`. Dat draait in de Worker en
niet in de app, om één reden: de sleutel van de Claude-api hoort niet in iets
wat iedereen kan openen. Hoe je hem neerzet, wat hij kost en welk protocol hij
spreekt staat in [`worker/README.md`](worker/README.md).


## Opslag

Alles staat achter `/api/v2/storage` op de Worker. Daar zit één *huis*, een
Durable Object, met twee soorten gegevens: de inhoud die je in de app bewerkt,
en per dag de vinkjes. Een eigen sleutel per dag betekent dat het ritme
's ochtends vanzelf leeg is; dagen ouder dan een week ruimt het huis zelf op.

Naast lezen en schrijven is er een WebSocket die openblijft zolang de app
openstaat. Wie iets afvinkt schrijft het naar het huis, en dat huis vertelt het
meteen aan iedereen die verbonden is: geen gepoll, en binnen een seconde staat
het ook op de andere telefoon. Het protocol staat in
[`worker/README.md`](worker/README.md).

**Let op:** iedereen die het adres kent, kan meelezen en meeschrijven. Wil je
het dicht, zet dan `SLEUTEL` als secret op de Worker en hetzelfde woord als
`ROUTINE_KEY` in de app. Echt inloggen komt eraan; ook dat staat in de README
van de Worker.

## Hoe het in elkaar zit

```
ios/        de app, in Swift — zie ios/README.md
worker/     de achterkant: /api/*, in TypeScript — zie worker/README.md
backup.mjs  een reservekopie van het huis maken of terugzetten
wrangler.toml
```

De webversie en de React Native-versie zijn weg; de iOS-app en de Worker zijn
wat er is.

## Publiceren

De Worker draait bij Cloudflare. Elke push naar `main` draait de proeven en
rolt daarna uit via `.github/workflows/deploy.yml`; zelf kan het met
`npm run deploy`. De app gaat via Xcode, zie [`ios/README.md`](ios/README.md).

## Ontwerpen

De schermontwerpen staan als canvas op
[claude.ai](https://claude.ai/code/artifact/60939a36-177b-4690-ad4f-2b847ddff646).
