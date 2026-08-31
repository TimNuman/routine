# De iOS-versie

Dezelfde app in Swift en SwiftUI: dezelfde drie schermen, dezelfde vormtaal en
dezelfde achterkant. Niets is nagebouwd op een eigen server — hij praat met
`/api/opslag` en `/api/lees` op de Worker uit deze repo, dus wat je op de
telefoon afvinkt staat een seconde later ook in de browser.

Naast `mobiel/` (React Native) is dit de tweede proef, om te zien wat het glas,
het ritme en de stroom doen als er geen laag javascript meer tussen zit.

## Draaien

Je hebt een Mac met Xcode 16 of nieuwer nodig; het project gebruikt de
gesynchroniseerde mappen die Xcode 16 introduceerde, zodat er niets in het
projectbestand hoeft bij te werken als er een bestand bij komt.

1. Zet in [`Dagritme/Config.swift`](Dagritme/Config.swift) het adres
   van je eigen Worker:

   ```swift
   static let defaultURL = "https://routine.jouwnaam.workers.dev"
   ```

   Liever niet in de code? Vul dan `ROUTINE_URL` in [`Info.plist`](Info.plist);
   die wint als hij gevuld is.
2. Open `ios/Dagritme.xcodeproj`, kies bij *Signing & Capabilities* je eigen team
   (het bundel-id `app.dagritme` is hetzelfde als in `mobiel/app.json`) en druk
   op ⌘R.

Tegen `wrangler dev` op de laptop draaien kan ook: zet dan
`http://<het-ip-van-je-laptop>:8787` als adres. `localhost` werkt niet op een
toestel, en op de simulator alleen omdat die dezelfde machine is.
`NSAllowsLocalNetworking` staat daarvoor al in `Info.plist`.

Staat er een `SLEUTEL` als secret bij de Worker, zet hem dan bij
`defaultKey` of in `ROUTINE_KEY`. Hij gaat mee als
`X-Routine-Sleutel`-kopje — ook bij de WebSocket, want buiten een browser mag dat
gewoon.

## Hoe het in elkaar zit

```
Dagritme/
  Config.swift         waar de Worker staat
  Core/                de logica, één op één uit mobiel/onderdelen
  Style/               kleuren, letters, maten, timing, het glas
  Components/          de losse stukken van de schermen
  Screens/             ritme, week, instellingen
  Fonts/               Baloo 2 en Nunito, bijgeknipt tot Latijn
Driver/                de app aansturen zonder handen — zie onderaan
```

`Core/` kent geen SwiftUI: dat is dezelfde bewerking als in de react
native-versie, alleen dan in Swift. Wat eruit komt is `Content` — de gladgestreken
vorm waar de schermen mee werken.

| | keuze |
|---|---|
| schermen | SwiftUI, iOS 17 en hoger |
| toestand | één `@Observable` klasse (`Core/Household.swift`) in de omgeving |
| opslag | `URLSession` naar `/api/opslag`, met `URLSessionWebSocketTask` voor de stroom |
| bewerken | `List` met `.swipeActions` en `.onMove`; de rest van de app is eigen glas |
| animatie | gewone SwiftUI-animaties, timing in `Style/Motion.swift` |

### Twee dingen die anders moesten

**Los zand wordt eerst een `Json`.** Javascript kan zomaar in een object kijken;
Swift niet. `Core/Json.swift` is die tussenstap: een waarde die opneemt wat er
uit het huis komt — een lijst die eigenlijk een woordenboek is, een getal dat als
tekst is bewaard — zodat `Content.swift` daarna precies dezelfde regels kan
toepassen als de webversie.

**Het concept bestaat uit klassen, de rest uit structs.** Een bewerkscherm werkt
op een losse kopie en moet één regel kunnen aanwijzen — *deze stap, in deze
groep* — om hem daarna ergens anders neer te zetten. Met waarden zou dat een
rijtje volgnummers worden dat bij elke wijziging verschuift; met verwijzingen
(`Core/Draft.swift`) blijft het gewoon dat ene ding, net als in javascript. Wat
de schermen tonen is wél gewone waarde-code.

## Het glas

`Style/Glass.swift` is de vertaling van `.glas` uit de webversie, met dezelfde val
erin als bij React Native: **het materiaal is voor de blur, niet voor de kleur.**
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

## Lettertypes

`Fonts/` bevat dezelfde bijgeknipte bestanden als `mobiel/assets/fonts/`,
gemaakt door `mobiel/lettertypes.mjs`. Ze staan in `UIAppFonts` in `Info.plist`;
in de code gaan ze op hun PostScript-naam (`Baloo2-ExtraBold`, niet de
bestandsnaam).

De maten staan vast in plaats van mee te groeien met de tekstinstelling van de
telefoon: de kaartjes zijn krap, en een naam die twee keer zo groot wordt valt er
uit. Dat is dezelfde keuze als op web, en het is wel iets om te weten.

## De app aansturen

`Driver/` is een tweede doel in hetzelfde project: een UI-test die de app opstart
en er tikken en vegen in doet. Niet om iets te bewijzen — er staat geen enkele
verwachting in — maar om te kúnnen kijken. Animaties bouwen die je niet kunt zien
is gokken, en dat bleek: de vonkjes bij het afvinken zaten verstopt achter het
gezichtje, en dat komt uit geen compiler en geen log.

```bash
xcodebuild test -project Dagritme.xcodeproj -scheme Dagritme \
  -destination 'id=<simulator>'
```

Zonder meer draait het plan in [`Driver/plan.json`](Driver/plan.json): opstarten, de
drie schermen langs door te vegen, en van elk een afdruk. Wil je iets anders, wijs
dan een eigen plan aan — het `TEST_RUNNER_`-voorvoegsel valt er onderweg af:

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
  *Straks* in [`worker/README.md`](../worker/README.md).

Wat er wél is en in `mobiel/` niet: een echte datumkiezer, trek-om-te-verversen,
en een app-icoon dat uit dezelfde `icon.svg` komt als de webversie.
