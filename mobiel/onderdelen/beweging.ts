// Alle timing op één plek, zodat het overal hetzelfde aanvoelt.
//
// De regel: snel klaar en nauwelijks doorschieten. Een veer die naschommelt
// voelt traag, ook als hij kort is — het oog wacht tot hij stilstaat. Dus hoge
// stijfheid, veel demping, en alleen op het moment van aantikken een wipje.

export const SNEL = { duration: 110 };
export const KORT = { duration: 160 };
export const RUSTIG = { duration: 220 };

// Komt in ~150 ms tot stilstand zonder zichtbaar na te veren.
export const VEER = { damping: 26, stiffness: 420, mass: 0.5 };

// Het enige plekje waar het mag wippen: het pop-je bij het afvinken.
export const WIP = { damping: 11, stiffness: 700, mass: 0.4 };

// Kaartjes komen na elkaar binnen, maar met een korte tik ertussen en een
// plafond — anders zit je te wachten tot de onderste er is.
export function natikken(i: number, stap = 22, hoogste = 220) {
  return Math.min(i * stap, hoogste);
}
