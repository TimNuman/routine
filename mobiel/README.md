# De React Native versie

Een proef, geen vervanging. Eén scherm — het ritme — in Expo, om te zien of de
vormtaal en het gevoel overeind blijven voordat de rest volgt. De webversie in
`public/` doet gewoon zijn werk; deze staat ernaast op `/nieuw`.

## Wat erin zit

| | keuze |
|---|---|
| framework | Expo + Expo Router, `output: static` voor web |
| styling | NativeWind (Tailwind), tokens in `tailwind.config.js` |
| animatie | Reanimated 4 |
| opslag | dezelfde Firebase-REST als de webversie, in `onderdelen/opslag.ts` |

Geen componentenbibliotheek. De vormtaal is eigen werk en Tamagui of gluestack
zou je die laten terugvechten; wat je nodig hebt is een styling-systeem en goede
animaties.

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

## Wat het kost

De export is ongeveer 3,5 MB: 2,2 MB javascript en 1,2 MB lettertypes. De
webversie is één bestand van 120 KB. Dat is de prijs van React Native op web, en
het is goed om die te kennen voordat je verder gaat.

Let op bij de lettertypes: importeer ze per gewicht
(`@expo-google-fonts/baloo-2/700Bold/Baloo2_700Bold.ttf`) en niet via de
pakket-index, anders bundelt Metro alle gewichten van de hele familie mee. Dat
scheelde hier 3 MB.
