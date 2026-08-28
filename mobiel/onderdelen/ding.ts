// Alles in deze app is hetzelfde ding met twee schakelaars: herhaalt het zich of
// geldt het één dag, en is het een taak of iets voor de agenda. Die vier
// combinaties zijn precies de vier plekken waar iets kan staan:
//
//            herhalen             één keer
//   agenda   weekritme            een regel bij Vandaag
//   taak     stap met dagen       stap met een datum
//
// Eén formulier dus, en elk scherm opent het met een andere beginstand.
import { datumVan, lijstVan, tekst } from './inhoud';
import { dagenVan, isDatum, nieuwId, type Ruw } from './schoon';
import type { Ritme } from './soorten';

export type Ding = {
  icoon: string; tekst: string;
  wekelijks: boolean; taak: boolean;
  dagen: string[]; datum: string;
  tijd: string; tot: string;
  wie: string[]; ritme: Ritme; groep: string;
  avond?: boolean;
};

// Waar iets staat, in één beschrijving: 'overzicht' en 'event' wijzen een regel
// aan, 'stap' een kaartje in een onderdeel.
export type Plek =
  | { waar: 'overzicht'; item: any }
  | { waar: 'event'; item: any }
  | { waar: 'stap'; ritme: Ritme; groep: any; stap: any };

export function eersteGroepnaam(bron: Ruw, ritme: Ritme): string {
  const groepen = lijstVan<any>(bron[ritme]).filter((g) => tekst(g.groep));
  return groepen.length ? tekst(groepen[groepen.length - 1].groep) : '';
}

export function dingVan(bron: Ruw, plek: Plek | null): Ding {
  const leeg: Ding = {
    icoon: '📅', tekst: '', wekelijks: true, taak: false, dagen: [],
    datum: datumVan(new Date()), tijd: '', tot: '', wie: [],
    ritme: 'dag', groep: eersteGroepnaam(bron, 'dag'),
  };
  if (!plek) return leeg;
  if (plek.waar === 'stap') {
    const stap = plek.stap;
    return {
      ...leeg,
      icoon: stap.icoon, tekst: stap.label, taak: true,
      wekelijks: !isDatum(stap.datum),
      dagen: lijstVan<string>(stap.dagen),
      datum: isDatum(stap.datum) ? stap.datum : leeg.datum,
      wie: lijstVan<string>(stap.wie), ritme: plek.ritme, groep: tekst(plek.groep.groep),
    };
  }
  const item = plek.item;
  return {
    ...leeg,
    icoon: item.icoon, tekst: item.tekst, taak: false,
    wekelijks: plek.waar === 'overzicht',
    dagen: lijstVan<string>(item.dagen),
    datum: isDatum(item.datum) ? item.datum : leeg.datum,
    tijd: tekst(item.tijd), tot: tekst(item.tot), wie: lijstVan<string>(item.wie),
    avond: Boolean(item.avond),
  };
}

type Vanaf = { waar: 'stap'; groep: any; index: number }
  | { waar: 'event' | 'overzicht'; index: number } | null;

// Geeft terug waar het vandaan kwam, zodat het op dezelfde plek in de lijst
// terug kan; anders springt alles wat je bewerkt naar onderen.
export function haalDingWeg(bron: Ruw, plek: Plek | null): Vanaf {
  if (!plek) return null;
  if (plek.waar === 'stap') {
    let vanaf: Vanaf = null;
    lijstVan<any>(bron[plek.ritme]).forEach((groep) => {
      const stappen = lijstVan<any>(groep.stappen);
      const i = stappen.indexOf(plek.stap);
      if (i >= 0) {
        vanaf = { waar: 'stap', groep, index: i };
        groep.stappen = stappen.filter((x) => x !== plek.stap);
      } else {
        groep.stappen = stappen;
      }
    });
    return vanaf;
  }
  if (plek.waar === 'event') {
    const lijst = lijstVan<any>(bron.events);
    const i = lijst.findIndex((e) => e.id === plek.item.id);
    bron.events = lijst.filter((e) => e.id !== plek.item.id);
    return i >= 0 ? { waar: 'event', index: i } : null;
  }
  const lijst = lijstVan<any>(bron.overzicht);
  const i = lijst.indexOf(plek.item);
  bron.overzicht = lijst.filter((x) => x !== plek.item);
  return i >= 0 ? { waar: 'overzicht', index: i } : null;
}

// Terug op zijn oude plek als het in dezelfde lijst blijft, anders achteraan.
function voegIn(lijst: unknown, nieuw: any, vanaf: Vanaf, zelfdeLijst: boolean) {
  const uit = lijstVan<any>(lijst);
  if (vanaf && zelfdeLijst) uit.splice(Math.min(vanaf.index, uit.length), 0, nieuw);
  else uit.push(nieuw);
  return uit;
}

export function zetDingNeer(bron: Ruw, g: Ding, id: string, vanaf: Vanaf) {
  if (g.taak) {
    const groepen = bron[g.ritme] = lijstVan<any>(bron[g.ritme]);
    let doel = groepen.find((x) => tekst(x.groep) === tekst(g.groep)) || groepen[groepen.length - 1];
    if (!doel) {
      doel = { groep: tekst(g.groep, 'Erbij'), tijd: '', stappen: [] };
      groepen.push(doel);
    }
    doel.stappen = voegIn(doel.stappen, {
      icoon: tekst(g.icoon, '⭐'), label: tekst(g.tekst),
      dagen: g.wekelijks ? dagenVan(g.dagen) : [],
      datum: g.wekelijks ? '' : tekst(g.datum),
      wie: lijstVan<string>(g.wie),
    }, vanaf, Boolean(vanaf && vanaf.waar === 'stap' && (vanaf as any).groep === doel));
    return;
  }
  if (g.wekelijks) {
    bron.overzicht = voegIn(bron.overzicht, {
      icoon: tekst(g.icoon, '📅'), tekst: tekst(g.tekst),
      tijd: tekst(g.tijd), tot: tekst(g.tot),
      dagen: dagenVan(g.dagen), wie: lijstVan<string>(g.wie),
    }, vanaf, Boolean(vanaf && vanaf.waar === 'overzicht'));
    return;
  }
  bron.events = voegIn(bron.events, {
    id: id || nieuwId(),
    icoon: tekst(g.icoon, '🎉'), tekst: tekst(g.tekst),
    tijd: tekst(g.tijd), tot: tekst(g.tot),
    datum: tekst(g.datum), wie: lijstVan<string>(g.wie),
  }, vanaf, Boolean(vanaf && vanaf.waar === 'event'));
}

// Eerst weghalen waar het stond, dan neerzetten waar het nu hoort. Zo is een
// weekregel die een kaartje wordt gewoon één beweging.
export function verplaatsDing(bron: Ruw, plek: Plek | null, g: Ding): string | null {
  if (!tekst(g.tekst)) return 'Vul een naam in.';
  if (!g.wekelijks && !isDatum(g.datum)) return 'Vul een datum in, of zet hem op herhalen.';
  const id = plek && plek.waar === 'event' ? plek.item.id : nieuwId();
  const vanaf = haalDingWeg(bron, plek);
  zetDingNeer(bron, g, id, vanaf);
  return null;
}
