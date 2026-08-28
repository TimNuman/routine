// Alles wat elk scherm nodig heeft staat hier één keer: de inhoud, de vinkjes
// van vandaag en of het ochtend of avond is. Zo blijft de kleurovergang doorlopen
// als je van tabblad wisselt, en wordt de inhoud niet per scherm opnieuw gehaald.
//
// De stroom blijft openstaan zolang de app open is: wat er op een andere telefoon
// gebeurt komt hier binnen en staat meteen in beeld.
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import { useSharedValue, withTiming, Easing } from 'react-native-reanimated';
import { usePathname } from 'expo-router';
import { Nacht } from './nacht';
import { datumVan, normaliseer } from './inhoud';
import { opgeschoond, type Ruw } from './schoon';
import {
  bewaarConfig, haalInhoud, haalVinkjes, schrijfVink, vinkSleutel, volg, wisRitme,
  type Bericht, type Vinkjes,
} from './opslag';
import type { Inhoud, Ritme } from './soorten';

type Gezinswaarde = {
  inhoud: Inhoud | null;
  fout: string;
  vinkjes: Vinkjes;
  ritme: Ritme;
  // Of het scherm nú donker is. Dat is niet hetzelfde als ritme: het avondritme
  // kleurt alleen die pagina, de week en de instellingen blijven licht.
  avond: boolean;
  zetRitme: (r: Ritme) => void;
  tik: (sleutel: string) => void;
  // Bewaart de hele inhoud; geeft een reden terug als het misging, anders null.
  bewaar: (ruw: Ruw) => Promise<string | null>;
  // Alle vinkjes van dit ritme weg — opnieuw beginnen.
  wis: () => void;
  nu: Date;
  datum: string;
};

const Gezin = createContext<Gezinswaarde | null>(null);

export function useGezin(): Gezinswaarde {
  const waarde = useContext(Gezin);
  if (!waarde) throw new Error('useGezin buiten Gezinshuis');
  return waarde;
}

export function Gezinshuis({ children }: { children: React.ReactNode }) {
  const [inhoud, zetInhoud] = useState<Inhoud | null>(null);
  const [fout, zetFout] = useState('');
  const [vinkjes, zetVinkjes] = useState<Vinkjes>({});
  const [ritme, zetRitme] = useState<Ritme>('dag');
  // Blijft de app een nacht openstaan, dan hoort hij morgen de volgende dag te
  // laten zien. De datum is genoeg; op de minuut hoeft niets bij te werken.
  const [nu, zetNu] = useState(() => new Date());
  const datum = datumVan(nu);
  const gekozen = useRef(false);   // heeft iemand zelf al ochtend/avond gekozen?

  // Het hele scherm verschiet in één beweging van ochtend naar avond, maar
  // alleen op de ritmepagina: de week en de instellingen blijven licht.
  const pad = usePathname();
  const avond = ritme === 'nacht' && pad === '/';
  const nacht = useSharedValue(0);
  useEffect(() => {
    nacht.value = withTiming(avond ? 1 : 0, { duration: 420, easing: Easing.inOut(Easing.quad) });
  }, [avond]);

  useEffect(() => {
    const klok = setInterval(() => {
      const straks = new Date();
      if (datumVan(straks) !== datumVan(nu)) zetNu(straks);
    }, 30000);
    return () => clearInterval(klok);
  }, [nu]);

  // Eerst ophalen zodat er meteen iets staat, en daarna meeluisteren.
  useEffect(() => {
    let weg = false;
    (async () => {
      try {
        const [c, v] = await Promise.all([haalInhoud(), haalVinkjes(datum)]);
        if (weg) return;
        zetInhoud(c);
        zetVinkjes(v);
        if (!gekozen.current) zetRitme(new Date().getHours() >= c.avondVanaf ? 'nacht' : 'dag');
      } catch (err: any) {
        if (!weg) zetFout(err?.message || 'onbekend');
      }
    })();
    return () => { weg = true; };
  }, [datum]);

  const stroom = useRef<ReturnType<typeof volg> | null>(null);
  useEffect(() => {
    const s = volg(datum, (b: Bericht) => {
      if (b.soort === 'begin') {
        zetFout('');
        if (b.inhoud) zetInhoud(normaliseer(b.inhoud));
        zetVinkjes(b.vinkjes || {});
      } else if (b.soort === 'inhoud') {
        if (b.inhoud) zetInhoud(normaliseer(b.inhoud));
      } else if (b.soort === 'vink') {
        zetVinkjes((was) => {
          const uit = { ...was };
          if (b.aan) uit[b.sleutel] = true; else delete uit[b.sleutel];
          return uit;
        });
      } else if (b.soort === 'ritme') {
        zetVinkjes((was) => {
          const uit: Vinkjes = {};
          Object.keys(was).forEach((s) => { if (!s.startsWith(b.ritme + '/')) uit[s] = was[s]; });
          return uit;
        });
      }
    });
    stroom.current = s;
    return () => { s.stop(); stroom.current = null; };
  }, []);

  useEffect(() => { stroom.current?.kijkNaar(datum); }, [datum]);

  // Meteen omzetten en pas daarna schrijven; mislukt dat, dan gaat hij terug.
  const tik = useCallback((sleutel: string) => {
    zetVinkjes((was) => {
      const aan = !was[sleutel];
      schrijfVink(datum, sleutel, aan).catch(() => {
        zetVinkjes((nu2) => {
          const uit = { ...nu2 };
          if (!aan) uit[sleutel] = true; else delete uit[sleutel];
          return uit;
        });
      });
      const uit = { ...was };
      if (aan) uit[sleutel] = true; else delete uit[sleutel];
      return uit;
    });
  }, [datum]);

  const wis = useCallback(() => {
    zetVinkjes((was) => {
      const uit: Vinkjes = {};
      Object.keys(was).forEach((s) => { if (!s.startsWith(ritme + '/')) uit[s] = was[s]; });
      return uit;
    });
    wisRitme(datum, ritme).catch(() => {});
  }, [datum, ritme]);

  const bewaar = useCallback(async (ruw: Ruw): Promise<string | null> => {
    const nieuw = opgeschoond(ruw);
    try {
      await bewaarConfig(nieuw);
    } catch (err: any) {
      return `Opslaan lukte niet (${err?.message || 'onbekend'}).`;
    }
    zetInhoud(normaliseer(nieuw));
    return null;
  }, []);

  const kies = useCallback((r: Ritme) => { gekozen.current = true; zetRitme(r); }, []);

  const waarde = useMemo(
    () => ({ inhoud, fout, vinkjes, ritme, avond, zetRitme: kies, tik, bewaar, wis, nu, datum }),
    [inhoud, fout, vinkjes, ritme, avond, kies, tik, bewaar, wis, nu, datum],
  );

  return (
    <Gezin.Provider value={waarde}>
      <Nacht.Provider value={nacht}>{children}</Nacht.Provider>
    </Gezin.Provider>
  );
}

export { vinkSleutel };
