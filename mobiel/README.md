# De React Native versie

Een proef, geen vervanging. Eén scherm — het ritme — in Expo, om te zien of de
vormtaal en het gevoel overeind blijven voordat de rest volgt. De webversie in
`public/` doet gewoon zijn werk; deze staat ernaast op `/nieuw`.

## Wat erin zit

| | keuze |
|---|---|
| framework | Expo + Expo Router, `output: static` voor web |
| styling | NativeWind (Tailwind), tokens in `tailwind.config.js` |
| animatie | Reanimated 4, timings in `onderdelen/beweging.ts` |
| opslag | dezelfde Firebase-REST als de webversie, in `onderdelen/opslag.ts` |

Geen componentenbibliotheek. De vormtaal is eigen werk en Tamagui of gluestack
zou je die laten terugvechten; wat je nodig hebt is een styling-systeem en goede
animaties.

## Hoe het beweegt

Alle timing staat in `onderdelen/beweging.ts`, want anders loopt het uit elkaar.
De regel: snel klaar en nauwelijks doorschieten. Een veer die naschommelt voelt
traag, ook als hij kort is — het oog wacht tot hij stilstaat.

| | |
|---|---|
| aantikken indrukken | 60 ms |
| gezichtje kleurt bij | 110 ms |
| segment, layout | veer die in ~150 ms staat, damping 26 |
| voortgangsbalk | 220 ms, ease-out; een balk die naveert leest als 'bijna klaar, toch niet' |
| kaartjes binnen | 160 ms, 22 ms na elkaar, hoogstens 220 ms wachten |

Eén plek mag wippen: het pop-je als jij iets afvinkt. Dat is het moment waar het
leuk mag zijn; de rest hoort onzichtbaar te zijn.

## Draaien

```bash
cd mobiel
npm install
npm run web          # http://localhost:8081
npm run bouw         # exporteert naar ../public/nieuw
```

Wijs hem naar een andere database met een `.env` ernaast:

```
EXPO_PUBLIC_OPSLAG_URL=http://127.0.0.1:8899
EXPO_PUBLIC_GEZIN=proef
```

Later op een iPhone: `npx expo start` en de Expo Go-app, of `eas build` voor een
echte build. Dat is nog niet geprobeerd — er is hier geen Mac en geen toestel.

## Wat er nog niet is

- **Live-sync.** De webversie luistert met `EventSource` naar Firebase; dat
  bestaat niet in React Native. Lezen en schrijven werkt, maar een vinkje van de
  andere telefoon komt hier pas binnen na herladen. Dit is de reden dat de opslag
  achter `/api` moet — zie `worker/README.md`.
- **De andere schermen.** Deze week, Instellingen, het formulier, de assistent.
- **Melkglas.** De kaarten zijn nu halfdoorzichtig wit; echte blur vraagt om
  `expo-blur` (BlurView), dat op web `backdrop-filter` gebruikt.

## Lettertypes

`assets/fonts/` bevat bijgeknipte versies, gemaakt door `lettertypes.mjs`:

```bash
npm run lettertypes
```

Dat is nodig omdat Google de complete familie levert. Baloo 2 heeft het hele
Devanagari-schrift aan boord (1585 glyphs), Nunito het Cyrillische (1098); deze
app schrijft alleen Latijn. Bijknippen scheelt bijna een megabyte:

| | van Google | bijgeknipt |
|---|---|---|
| Baloo 2 Bold | 410 KB | 43 KB |
| Baloo 2 ExtraBold | 410 KB | 43 KB |
| Nunito Bold | 129 KB | 35 KB |
| Nunito ExtraBold | 129 KB | 35 KB |
| **totaal** | **1,1 MB** | **155 KB** |

Op web doet Google dit zelf — de `<link>` in `public/index.html` levert een woff2
met alleen de latin-slice. Een app op een telefoon heeft een echt bestand nodig
en kan dat niet, dus doen we het hier.

Twee dingen die makkelijk misgaan: importeer per gewicht en niet via de
pakket-index, anders bundelt Metro alle gewichten mee; en de pakketten zelf zijn
`devDependencies`, want alleen het knipscript heeft ze nodig.

## Wat het kost

De export is ongeveer 2,6 MB, waarvan 2,2 MB javascript. De webversie is één
bestand van 120 KB — plus lettertypes van Google, die daar niet in meetellen.
Dat verschil is de prijs van React Native op web, en het is goed om die te kennen
voordat je verder gaat.
