import { useMemo, useRef, useState } from 'react';
import { View } from 'react-native';
import Animated from 'react-native-reanimated';
import { Agenda, Blokkop } from '../onderdelen/Agenda';
import { Dingblad } from '../onderdelen/Dingblad';
import { Glas } from '../onderdelen/Glas';
import { Kaartknop } from '../onderdelen/Kaartknop';
import { L } from '../onderdelen/letters';
import { useNachtKleur } from '../onderdelen/nacht';
import { Scherm } from '../onderdelen/Scherm';
import { Weekstrip } from '../onderdelen/Weekstrip';
import { useGezin } from '../onderdelen/gezin';
import { datumTekst, datumVan, isAvond, itemsVan, lijstVan, weekVan } from '../onderdelen/inhoud';
import type { Blok } from '../onderdelen/inhoud';
import { alsRuw, type Ruw } from '../onderdelen/schoon';
import { dingVan, type Ding, type Plek } from '../onderdelen/ding';
import type { Agendaitem } from '../onderdelen/soorten';

export default function Weekscherm() {
  const { inhoud, nu, bewaar } = useGezin();
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

  // Vanaf deze pagina bewerk je buiten het bewerkscherm om, dus gaat de hele
  // inhoud in één keer terug de database in.
  const werk = useRef<Ruw | null>(null);
  const [blad, zetBlad] = useState<{ titel: string; plek: Plek | null; ding: Ding } | null>(null);
  const [bezig, zetBezig] = useState(false);

  const openDing = (item: Agendaitem | null) => {
    if (!inhoud) return;
    const ruw = alsRuw(inhoud);
    werk.current = ruw;
    const bijItem = item
      ? lijstVan<any>(ruw.events).find((e) => e.id === item.id)
      : null;
    const plek: Plek | null = bijItem ? { waar: 'event', item: bijItem } : null;
    zetBlad({
      titel: item ? (item.tekst || 'Iets eenmaligs') : 'Iets eenmaligs',
      plek,
      ding: plek
        ? dingVan(ruw, plek)
        : { ...dingVan(ruw, null), icoon: '🎉', wekelijks: false, taak: false, datum: datumVan(gekozen) },
    });
  };

  const bewaarBlad = async () => {
    if (!werk.current) return;
    zetBezig(true);
    const fout = await bewaar(werk.current);
    zetBezig(false);
    if (!fout) zetBlad(null);
  };

  const haalWeg = async () => {
    const ruw = werk.current;
    const plek = blad?.plek;
    if (!ruw || !plek || plek.waar !== 'event') return;
    ruw.events = lijstVan<any>(ruw.events).filter((e) => e.id !== plek.item.id);
    zetBezig(true);
    const fout = await bewaar(ruw);
    zetBezig(false);
    if (!fout) zetBlad(null);
  };

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
        <Agenda key={blok.kop} blok={blok} mensen={inhoud.mensen} opOpen={openDing} />
      ))}

      {inhoud && <Kaartknop plus opTik={() => openDing(null)}>Iets bijzonders toevoegen</Kaartknop>}

      {!!blad && inhoud && (
        <Dingblad
          titel={blad.titel}
          ding={blad.ding}
          plek={blad.plek}
          bron={() => werk.current!}
          mensen={inhoud.mensen}
          bezig={bezig}
          opAf={() => zetBlad(null)}
          opBewaar={bewaarBlad}
          opWeg={blad.plek ? haalWeg : undefined}
        />
      )}
    </Scherm>
  );
}

function Leeg({ children }: { children: string }) {
  const kleur = useNachtKleur('#5C5F7A', 'rgba(255,255,255,0.6)');
  return <Animated.Text style={[L.leeg, kleur]}>{children}</Animated.Text>;
}
