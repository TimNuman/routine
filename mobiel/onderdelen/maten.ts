// De webversie laat alles meegroeien zodra er ruimte is: grotere gezichtjes,
// een groter icoon, een hoger kaartje. Zonder dat blijft een kaartje op een
// breed scherm een klein plaatje in een grote lege doos.
export function maten(breedte: number) {
  const ruim = breedte >= 700;
  const krap = breedte < 360;
  return {
    perRij: breedte >= 1000 ? 5 : ruim ? 4 : 3,
    rondje: krap ? 34 : ruim ? 50 : 40,
    icoon: ruim ? 46 : 34,
    naam: ruim ? 15 : 13,
    hoog: ruim ? 172 : 142,
    gootje: krap ? 16 : ruim ? 26 : 20,
    // De webversie houdt de hele app op 1280 breed; daarboven wordt het geen
    // betere bladspiegel, alleen bredere kaartjes.
    maxBreed: 1280,
  };
}
