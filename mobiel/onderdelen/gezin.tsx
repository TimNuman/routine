// Alles wat elk scherm nodig heeft staat hier één keer: de inhoud, de vinkjes
// van vandaag en of het ochtend of avond is. Zo blijft de kleurovergang doorlopen
// als je van tabblad wisselt, en wordt de inhoud niet per scherm opnieuw gehaald.
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { useSharedValue, withTiming, Easing } from 'react-native-reanimated';
import { usePathname } from 'expo-router';
import { Nacht } from './nacht';
import { datumVan } from './inhoud';
import { bewaarConfig, haalInhoud, haalVinkjes, schrijfVink, vinkSleutel, type Vinkjes } from './opslag';
import { normaliseer } from './inhoud';
import { opgeschoond, type Ruw } from './schoon';
import type { Inhoud, Ritme } from './soorten';

type Gezinswaarde = {
  inhoud: Inhoud | null;
  fout: string;
  vinkjes: Vinkjes;
  ritme: Ritme;
  zetRitme: (r: Ritme) => void;
  tik: (sleutel: string) => void;
  // Bewaart de hele inhoud; geeft een reden terug als het misging, anders null.
  bewaar: (ruw: Ruw) => Promise<string | null>;
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

  const nu = useMemo(() => new Date(), []);
  const datum = datumVan(nu);

  // Het hele scherm verschiet in één beweging van ochtend naar avond, maar
  // alleen op de ritmepagina: de week en de instellingen blijven licht.
  const pad = usePathname();
  const avond = ritme === 'nacht' && pad === '/';
  const nacht = useSharedValue(0);
  useEffect(() => {
    nacht.value = withTiming(avond ? 1 : 0, { duration: 420, easing: Easing.inOut(Easing.quad) });
  }, [avond]);

  useEffect(() => {
    let weg = false;
    (async () => {
      try {
        const [c, v] = await Promise.all([haalInhoud(), haalVinkjes(datum)]);
        if (weg) return;
        zetInhoud(c);
        zetVinkjes(v);
        zetRitme(nu.getHours() >= c.avondVanaf ? 'nacht' : 'dag');
      } catch (err: any) {
        if (!weg) zetFout(err?.message || 'onbekend');
      }
    })();
    return () => { weg = true; };
  }, [datum]);

  // Meteen omzetten en pas daarna schrijven; mislukt dat, dan gaat hij terug.
  const tik = useCallback((sleutel: string) => {
    zetVinkjes((was) => {
      const aan = !was[sleutel];
      schrijfVink(datum, sleutel, aan).catch(() => {
        zetVinkjes((nu2) => ({ ...nu2, [sleutel]: !aan }));
      });
      return { ...was, [sleutel]: aan };
    });
  }, [datum]);

  const bewaar = useCallback(async (ruw: Ruw): Promise<string | null> => {
    const nieuw = opgeschoond(ruw);
    try {
      await bewaarConfig(nieuw);
    } catch (err: any) {
      return `Opslaan in de database lukte niet (${err?.message || 'onbekend'}).`;
    }
    zetInhoud(normaliseer(nieuw));
    return null;
  }, []);

  const waarde = useMemo(
    () => ({ inhoud, fout, vinkjes, ritme, zetRitme, tik, bewaar, nu, datum }),
    [inhoud, fout, vinkjes, ritme, tik, bewaar, nu, datum],
  );

  return (
    <Gezin.Provider value={waarde}>
      <Nacht.Provider value={nacht}>{children}</Nacht.Provider>
    </Gezin.Provider>
  );
}

export { vinkSleutel };
