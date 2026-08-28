import { useEffect, useLayoutEffect, useState } from 'react';
import { useWindowDimensions } from 'react-native';

// Precies de drie grenzen uit de webversie: onder 360 wordt alles krapper,
// vanaf 700 past er een maatje groter bij, en vanaf 1000 komt het weekritme
// als kolom ernaast te staan.
export function maten(breedte: number) {
  const krap = breedte <= 360;
  const ruim = breedte >= 700;
  const breed = breedte >= 1000;
  return {
    breed,
    // De kolom ernaast, even breed als de menubalk op web, met dezelfde goot.
    zijkolom: 372,
    naast: 26,
    // Alles springt overal even ver in, zodat kopjes en de eerste emoji
    // op één lijn staan.
    insprong: 16,
    gootje: krap ? 16 : breed ? 26 : 22,
    bovenaan: breed ? 22 : 42,
    onderaan: breed ? 40 : 132,
    // Het kaartraster: drie op een rij op een telefoon, vijf zodra er ruimte is.
    perRij: ruim ? 5 : 3,
    tussen: ruim ? 14 : 10,
    kaartX: ruim ? 10 : 6,
    kaartY: ruim ? 10 : 8,
    kaartGat: ruim ? 6 : 5,
    hoog: ruim ? 172 : 142,
    icoon: ruim ? 46 : 36,
    naam: ruim ? 15 : 13,
    rondje: krap ? 34 : ruim ? 50 : 40,
    gezicht: krap ? 30 : ruim ? 44 : 34,
    teken: krap ? 19 : ruim ? 27 : 21,
    // De webversie houdt de hele app op 1280 breed; daarboven wordt het geen
    // betere bladspiegel, alleen bredere kaartjes.
    maxBreed: 1280,
  };
}

// Bij het uitgeven maakt Expo eerst een statische pagina, en daar is nog geen
// venster: die pagina wordt dus als smal scherm getekend. Meten we hier bij de
// eerste tekening al echt, dan wijkt die af van de HTML en laat React de HTML
// staan — de indeling blijft dan voorgoed hangen op die van een telefoon.
// Dus meten we pas ná het aankoppelen, nog vóór de eerste schilderbeurt.
const naTeken = typeof window === 'undefined' ? useEffect : useLayoutEffect;

export function useMaten() {
  const venster = useWindowDimensions();
  const [breedte, zetBreedte] = useState(0);
  naTeken(() => { zetBreedte(venster.width); }, [venster.width]);
  return maten(breedte);
}
