# De iOS-versie

De app, in Swift en SwiftUI. Niets is nagebouwd op een eigen server: hij praat
met `/api/v2/storage` en `/api/v2/read` op de Worker uit deze repo, dus wat je
op de ene telefoon afvinkt staat een seconde later ook op de andere.

## Draaien

Je hebt een Mac met Xcode 16 of nieuwer nodig; het project gebruikt de
gesynchroniseerde mappen die Xcode 16 introduceerde, zodat er niets in het
projectbestand hoeft bij te werken als er een bestand bij komt. Wil je de
menubalk van vloeibaar glas zien, dan bouw je met Xcode 26 (de iOS 26-sdk); met
een oudere sdk of op een ouder toestel is het dezelfde balk in het oude jasje.

1. Zet in [`Dagritme/Config.swift`](Dagritme/Config.swift) het adres
   van je eigen Worker:

   ```swift
   static let defaultURL = "https://routine.jouwnaam.workers.dev"
   ```

   Liever niet in de code? Vul dan `ROUTINE_URL` in [`Info.plist`](Info.plist);
   die wint als hij gevuld is.
2. Open `ios/Dagritme.xcodeproj`, kies bij *Signing & Capabilities* je eigen team
   (het bundel-id is `app.dagritme`) en druk
   op ⌘R.

Tegen `wrangler dev` op de laptop draaien kan ook: zet dan
`http://<het-ip-van-je-laptop>:8787` als adres. `localhost` werkt niet op een
toestel, en op de simulator alleen omdat die dezelfde machine is.
`NSAllowsLocalNetworking` staat daarvoor al in `Info.plist`.

## Inloggen

De app opent met een inlogscherm: Apple, Google, of *zonder account verder*.

- **Apple** gaat via `SignInWithAppleButton`. Daarvoor is een betaald
  Apple Developer-account nodig: een persoonlijk (gratis) team mag de
  capability niet, en de build faalt dan. Daarom staat
  `Dagritme/Dagritme.entitlements` er wel, maar is hij nog niet aan het
  target gekoppeld. Zodra het account er is: *Signing & Capabilities → +
  Sign in with Apple* (dat zet `CODE_SIGN_ENTITLEMENTS` op dat bestand). Tot
  die tijd ziet `Core/Capabilities.swift` in het profiel dat de entitlement
  ontbreekt en laat de knop weg.
- **Google** gaat zonder hun sdk: `Core/GoogleSignIn.swift` doet de
  OAuth-dans met PKCE in een `ASWebAuthenticationSession`. Het client-id staat
  als `GOOGLE_CLIENT_ID` in `Info.plist`, met het omgekeerde id als
  URL-schema erbij. Een iOS-client heeft geen geheim.
- **Zonder account** is de oude weg: het ene huis uit de Worker, met
  `ROUTINE_KEY` als `X-Routine-Key`-kopje als daar een `SLEUTEL` staat.

Wat er terugkomt bewaart `Core/Session.swift` in de sleutelhanger: de
access-token (een uur), de refresh-token (90 dagen, eenmalig te gebruiken),
wie je bent en het huis dat de server bij het inloggen aanmaakt. Elk verzoek
dat een 401 krijgt ruilt de refresh-token één keer in en probeert het opnieuw;
de WebSocket verbindt gewoon opnieuw met het nieuwe token. Uitloggen staat
onderaan *Instellingen*.

**Ouders en verzorgers** (ook onder *Instellingen*, `Components/FamilySheet.swift`): wie er
in het huis zit, elk met een gezicht, een kleur en de naam die de kinderen
gebruiken (papa, oma); je eigen regel aanraken opent dat blad. *Maak een
code* geeft een code van een week die één keer werkt, met een deelknop; *Ik
heb een code* is de andere kant, en daarna laat de app het huis van de ander
zien. Wie het huis begon veegt de anderen weg.

De deelknop stuurt een link, `https://<worker>/join/ABCD-EFGH`. Die pagina
opent `routines://join/…` (het URL-schema staat in `Info.plist`); de app
onthoudt de code (`Session.handle`) en biedt hem aan: op het inlogscherm als
melding, en ingelogd als blad met één knop *Doe mee*. Met een betaald
developer-account komt daar *Associated Domains* bij
(`applinks:routine.tim-numan.workers.dev`, staat al in het
entitlements-bestand) en opent de https-link de app rechtstreeks.

De Driver start de app met `SESSION=legacy`, dus zonder inlogscherm; zet
`TEST_RUNNER_DRIVER_SESSION=fresh` om dat scherm wel te zien.

## Hoe het in elkaar zit

```
Dagritme/
  Config.swift         waar de Worker staat
  Localizable.xcstrings  de teksten; nl nu, de/da/en straks
  Core/                de logica: inhoud, opslag, de assistent
  Style/               kleuren, letters, maten, timing, het glas
  Components/          de losse stukken van de schermen
  Screens/             ritme, week, instellingen
  Fonts/               Baloo 2 en Nunito, bijgeknipt tot Latijn
maestro/               de stromen die de app aansturen — zie onderaan
Driver/                afdrukken en opnames — zie onderaan
```

`Core/` kent geen SwiftUI: dat is dezelfde bewerking als in de react
native-versie, alleen dan in Swift. Wat eruit komt is `Content` — de gladgestreken
vorm waar de schermen mee werken.

| | keuze |
|---|---|
| schermen | SwiftUI, iOS 17 en hoger |
| toestand | één `@Observable` klasse (`Core/Household.swift`) in de omgeving |
| opslag | `URLSession` naar `/api/v2/storage`, met `URLSessionWebSocketTask` voor de stroom |
| bewerken | `List` met `.swipeActions` en `.onMove`; de rest van de app is eigen glas |
| bladeren | de menubalk van iOS zelf (`TabView`); binnen het ritme schuift de schakelaar ochtend en avond langs (`Components/Slide.swift`); op de dagen van de weekstrook bladert een veeg door de weken |
| animatie | gewone SwiftUI-animaties, timing in `Style/Motion.swift` |

### Twee dingen die anders moesten

**Los zand wordt eerst een `Json`.** Javascript kan zomaar in een object kijken;
Swift niet. `Core/Json.swift` is die tussenstap: een waarde die opneemt wat er
uit het huis komt — een lijst die eigenlijk een woordenboek is, een getal dat als
tekst is bewaard — zodat `Content.swift` daarna precies dezelfde regels kan
toepassen.

**Het concept bestaat uit klassen, de rest uit structs.** Een bewerkscherm werkt
op een losse kopie en moet één regel kunnen aanwijzen — *deze stap, in deze
groep* — om hem daarna ergens anders neer te zetten. Met waarden zou dat een
rijtje volgnummers worden dat bij elke wijziging verschuift; met verwijzingen
(`Core/Draft.swift`) blijft het gewoon dat ene ding, net als in javascript. Wat
de schermen tonen is wél gewone waarde-code.

## De menubalk

Onderaan staat de balk van iOS zelf — een gewone `TabView` met drie
`tabItem`s in `Components/Screen.swift`. Op iOS 26 is dat de zwevende balk van
vloeibaar glas die je ook in de App Store en Signal ziet, met alles wat daarbij
hoort zonder dat de app er iets voor doet: het glas dat meekleurt met wat
eronder scrolt, en de veeg over de balk waarmee je van tabblad naar tabblad
schuift. Op een ouder toestel is het dezelfde balk in het oude jasje.

Daarmee is de eigen balk weg, en met hem de veeg over de hele bladzijde: van
tabblad wisselen doe je op de balk. Binnen het ritme blijft de schakelaar
boven de kaartjes ochtend en avond langs schuiven — dat is dezelfde schuif als
altijd (`Components/Slide.swift`), alleen niet meer met een vinger op de
bladzijde.

De bladzijden hangen niet meer onder één hemel: `Screen` zet zijn eigen `Sky`
en de twee wegzakkende randen neer, want de balk van het toestel staat tussen
de app en de bladzijden in. Onderaan houdt iOS zelf ruimte vrij voor de balk;
`Metrics.bottomPad` is alleen nog wat er daarboven bij komt. Gaat er een blad
open, dan gaat de balk weg met `.toolbar(.hidden, for: .tabBar)`.

## Het glas

`Style/Glass.swift` is het glas, met één val erin: **het materiaal is voor de
blur, niet voor de kleur.**
`.ultraThinMaterial` brengt zijn eigen grijs mee; gebruik je dat als vulling, dan
worden de kaartjes vlakke dozen. De kleur komt daarom uit het palet eronder.

| css | hier |
|---|---|
| `backdrop-filter: blur(44px)` | `RoundedRectangle().fill(.ultraThinMaterial)` |
| `background: rgba(255,255,255,.62)` | een tweede vlak in de kleur uit `Palette` |
| `border: 1px rgba(255,255,255,.75)` | `strokeBorder`, met een verloop erin |
| `inset 0 1px 0` / `inset 0 -1px 0` | boven- en onderkant van datzelfde verloop |
| `0 16px 38px rgba(126,84,42,.16)` | `.shadow(radius: 19, y: 16)` |

De overgang van ochtend naar avond is één vlag in het palet. SwiftUI kan kleuren
zelf tussenstanden geven, dus één `.animation(Motion.night, value: evening)`
bovenin `RootScreen` laat het hele scherm in dezelfde 420 ms omgaan — daar is
geen gedeelde waarde per onderdeel voor nodig zoals in Reanimated.

De maten groeien mee met het scherm (`Style/Metrics.swift`), met dezelfde drie
grenzen als op web: krapper onder 360, een maatje groter vanaf 700, en vanaf 1000
komt het weekritme als kolom ernaast — dat is een iPad in liggende stand.

## Talen

De app begint in het Nederlands, maar niets zit er meer aan vast. Alle tekst die
je op het scherm ziet loopt via `String(localized:)` of via `Text(...)` — dat
laatste vertaalt SwiftUI zelf — en komt samen in
[`Dagritme/Localizable.xcstrings`](Dagritme/Localizable.xcstrings). Duits, Deens
en Engels staan al als taal bij het project; in de cataloguseditor van Xcode vul
je ze in.

Wat VoiceOver voorleest zit daar in dezelfde catalogus bij, onder sleutels die
met `a11y.` beginnen (zie [`Dagritme/Core/Strings.swift`](Dagritme/Core/Strings.swift)).
De namen waarop de Maestro-stromen aanwijzen zijn iets anders: die zijn Engels,
worden nooit voorgelezen en vertalen dus niet mee.

Dagen en maanden komen uit de kalender van het toestel, niet uit een lijstje —
`dateText` en `shortDate` gebruiken `Date.formatted`, en de letters boven de
weekstrip komen uit `veryShortStandaloneWeekdaySymbols`. Een Deense telefoon
krijgt daardoor Deense dagnamen zonder dat er iets vertaald hoeft te worden. De
codes die over de lijn gaan (`mon`, `tue`, …) staan daar los van en veranderen
niet mee.

De uitlezer krijgt de taal mee in het verzoek en schrijft zijn voorstellen in
die taal terug; het systeemprompt zelf blijft Nederlands, want dat is een
instructie aan het model en geen tekst voor de ouder.

**Eén ding vertaalt met opzet niet.** `stepKey` maakt van de naam van een stap
de sleutel waaronder het vinkje in het huis staat, en vouwt daarvoor met een
vaste `nl_NL`. Dat is geen slordigheid maar juist wat de sleutel stabiel houdt —
zou hij de taal van het toestel volgen, dan verschoof de sleutel per telefoon.
Wel iets om te weten: letters die geen samenstelling zijn (ø, æ, å, ß) vallen
eruit in plaats van dat ze worden omgeschreven, dus een Deens huis krijgt
sleutels met gaten. Werkt prima, maar het is het opruimen waard voordat er
Deense gezinnen bij komen — en dat kan alleen samen met een verhuizing van de
bestaande sleutels.

## Lettertypes

`Fonts/` bevat bijgeknipte lettertypes (alleen de tekens die de app gebruikt).
Ze staan in `UIAppFonts` in `Info.plist`;
in de code gaan ze op hun PostScript-naam (`Baloo2-ExtraBold`, niet de
bestandsnaam).

De maten staan vast in plaats van mee te groeien met de tekstinstelling van de
telefoon: de kaartjes zijn krap, en een naam die twee keer zo groot wordt valt er
uit. Dat is dezelfde keuze als op web, en het is wel iets om te weten.

## De app aansturen

[Maestro](https://maestro.mobile.dev) doet het echte werk: een stroom is een
paar regels yaml, hij wacht zelf tot iets er staat, en hij wijst elementen aan
op hun naam in plaats van op een plek op het scherm. Daardoor blijft een stroom
kloppen als er iets verschuift.

```bash
curl -Ls "https://get.maestro.mobile.dev" | bash   # of: brew tap mobile-dev-inc/tap && brew install maestro
maestro test ios/maestro                     # alles
maestro test ios/maestro/smoke.yaml          # één stroom
maestro test --include-tags smoke ios/maestro
maestro studio                # klik je een stroom bij elkaar, met de boom erbij
```

De stromen staan in [`maestro/`](maestro):

| | wat het doet |
|---|---|
| `smoke.yaml` | de drie schermen langs, met een afdruk van elk |
| `morning-evening.yaml` | de schakelaar heen en terug |
| `tick-a-step.yaml` | een rondje afvinken en weer uitzetten |
| `add-something.yaml` | het formulier openen, invullen en annuleren |

Ze wijzen aan op `accessibilityIdentifier`, en die staan overal waar je op kunt
tikken: `segment.night`, `ring.<stap>.<kind>`,
`settings.children`, `sheet.cancel`, `week.addOneOff`. Die namen zijn Engels en
worden nooit voorgelezen — ze horen bij de code. Wat VoiceOver zegt staat er
apart naast, in het Nederlands, en gaat mee in de vertaling.

Eén ding heeft geen identifier: de menubalk onderaan is die van iOS zelf, en
daar valt er geen op te plakken. De stromen wijzen hem aan op wat erop staat —
`tapOn: "^Ritme$"`, `"^Deze week$"`, `"^Instellingen$"` — met de haakjes erbij,
zodat `Ritme` niet ook `Dagritme` op het instellingenscherm raakt.

Let op: `tick-a-step.yaml` en `add-something.yaml` draaien tegen het echte huis.
De eerste zet een vinkje en haalt het weer weg, de tweede annuleert het
formulier — maar reken erop dat een stroom die je zelf schrijft wél iets
achterlaat.

### Afdrukken en opnames

`Driver/` blijft ernaast staan voor wat Maestro niet doet: een opname van de
beweging zelf. Animaties bouwen die je niet kunt zien is gokken, en dat bleek —
de vonkjes bij het afvinken zaten verstopt achter het gezichtje, en dat komt uit
geen compiler en geen log.

```bash
xcodebuild test -project Dagritme.xcodeproj -scheme Dagritme \
  -destination 'id=<simulator>'
```

Zonder meer draait het plan in [`Driver/plan.json`](Driver/plan.json). Wil je
iets anders, wijs dan een eigen plan aan — het `TEST_RUNNER_`-voorvoegsel valt
er onderweg af:

```bash
TEST_RUNNER_DRIVER_PLAN=/pad/plan.json \
TEST_RUNNER_DRIVER_SHOTS=/pad/naar/map xcodebuild test ...
```

De plaatsen in een plan lopen van 0 tot 1 over de breedte en de hoogte. Zo reken
je ze uit een schermafdruk zonder de puntmaten van dat ene toestel te kennen, en
blijft een plan kloppen op een andere simulator. De afdrukken hangen altijd aan
de uitslag; met `DRIVER_SHOTS` komen ze ook als los bestand op schijf, en dan kun
je ze met gewone gereedschappen vergelijken:

```bash
ffmpeg -i voor.png -i na.png -filter_complex psnr -f null -   # inf = gelijk
```

Eén ding kan de UI-test niet: snel achter elkaar tikken. Vóór elke tik wacht
hij tot de app stilstaat, dus een tweede tik komt altijd pas ná de schuif. Voor
precies dat geval voert de app zelf een rijtje tikken uit als `DRIVER_SCRIPT`
gezet is — de test geeft hem door als `SCRIPT` — en dan zie je wel wat er
gebeurt als iemand midden in een overgang alweer ergens anders heen wil:

```bash
TEST_RUNNER_DRIVER_SCRIPT="wait 4, week, wait 0.15, instellingen, wait 2, ritme, avond" \
xcodebuild test ...
```

De stappen zijn `wait <s>`, `ritme`, `week`, `instellingen`, `ochtend`, `avond`,
`vink` (het eerste vinkje van het eerste kind omzetten — let op, dat schrijft naar
het echte huis) en `herlaad` (alsof de app wakker wordt).
In een plan kunnen ook `home` (naar het beginscherm) en `activate` (terug naar de
app) staan, om slapen en wakker worden na te spelen.
Verder `tapId` (tik op een `accessibilityIdentifier`, en anders op wat er
staat — zo komt de menubalk van iOS ook aan de beurt) en `type` (typ in het veld
dat de focus heeft).
Neem het op met `xcrun simctl io <simulator> recordVideo` en trek er beelden uit;
de opname heeft geen vaste beeldsnelheid, dus zet hem eerst om (`ffmpeg -vf
fps=30`) voordat je op beeldnummer zoekt.

Bewegen zie je zo natuurlijk niet. Daarvoor loopt er een opname naast:

```bash
xcrun simctl io <simulator> recordVideo --codec h264 uit.mp4 &
```

De simulator neemt variabel op — tijdens beweging zo'n 75 beelden per seconde —
dus een animatie van 300 ms levert twintig bruikbare frames. Met `tblend` erover
vind je waar er iets gebeurt en hoe lang het duurt, en `tile` maakt er een
filmstrip van die je in één keer kunt bekijken.

## Wat er nog niet is

- **Op een echt toestel geprobeerd.** In de simulator wel, met `Driver/` erbij, maar
  een simulator kent geen trilling en geen trage verbinding. Reken erop dat het
  eerste kwartier op een iPhone nog een paar dingen rechtzet.
- **Aanmelden.** Wie het adres kent, kan meelezen en meeschrijven; `SLEUTEL` is
  een drempel, geen slot. Voor een app in een store is dat te weinig — zie
  *Wie mag erbij* in [`worker/README.md`](../worker/README.md).
