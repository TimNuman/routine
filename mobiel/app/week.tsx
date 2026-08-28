import { useMemo, useState } from 'react';
import { View } from 'react-native';
import Animated from 'react-native-reanimated';
import { Agenda, Blokkop } from '../onderdelen/Agenda';
import { Glas } from '../onderdelen/Glas';
import { L } from '../onderdelen/letters';
import { useNachtKleur } from '../onderdelen/nacht';
import { Scherm } from '../onderdelen/Scherm';
import { Weekstrip } from '../onderdelen/Weekstrip';
import { useGezin } from '../onderdelen/gezin';
import { datumTekst, datumVan, isAvond, itemsVan, weekVan } from '../onderdelen/inhoud';
import type { Blok } from '../onderdelen/inhoud';

export default function Weekscherm() {
  const { inhoud, nu } = useGezin();
  const [verschuiving, zetVerschuiving] = useState(0);
  const [gekozenDag, zetGekozenDag] = useState<string | null>(null);

  // De gekozen dag, of anders vandaag zolang die in beeld is; in een andere
  // week de maandag.
  const gekozen = useMemo(() => {
    const week = weekVan(nu, verschuiving);
    const staat = gekozenDag && week.find((d) => datumVan(d) === gekozenDag);
    return staat || week.find((d) => datumVan(d) === datumVan(nu)) || week[0];
  }, [nu, verschuiving, gekozenDag]);

  // Een week verder of terug, op dezelfde weekdag als waar je stond.
  const schuif = (weken: number) => {
    const nieuw = new Date(gekozen);
    nieuw.setDate(nieuw.getDate() + weken * 7);
    zetVerschuiving(verschuiving + weken);
    zetGekozenDag(datumVan(nieuw));
  };

  // Alleen de gekozen dag; morgen is hier één tik verder in de strip.
  const blokken: Blok[] = useMemo(() => {
    if (!inhoud) return [];
    const items = itemsVan(inhoud, gekozen);
    const vandaag = datumVan(gekozen) === datumVan(nu);
    return [
      { kop: 'Overdag', items: items.filter((i) => !isAvond(i, inhoud.avondVanaf)) },
      { kop: vandaag ? 'Vanavond' : "'s Avonds", items: items.filter((i) => isAvond(i, inhoud.avondVanaf)) },
    ].filter((b) => b.items.length);
  }, [inhoud, gekozen, nu]);

  return (
    <Scherm titel="Deze week" onder={datumTekst(gekozen)} smal>
      <Weekstrip
        nu={nu}
        verschuiving={verschuiving}
        gekozen={gekozen}
        opKies={(d) => zetGekozenDag(datumVan(d))}
        opSchuif={schuif}
      />

      {inhoud && !blokken.length && (
        <View>
          <Blokkop>Niks bijzonders</Blokkop>
          <Glas radius={26} inhoudStijl={{ paddingVertical: 28, paddingHorizontal: 20 }}>
            <Leeg>Deze dag staat er niets in de agenda.</Leeg>
          </Glas>
        </View>
      )}

      {inhoud && blokken.map((blok) => (
        <Agenda key={blok.kop} blok={blok} mensen={inhoud.mensen} />
      ))}
    </Scherm>
  );
}

function Leeg({ children }: { children: string }) {
  const kleur = useNachtKleur('#5C5F7A', 'rgba(255,255,255,0.6)');
  return <Animated.Text style={[L.leeg, kleur]}>{children}</Animated.Text>;
}
