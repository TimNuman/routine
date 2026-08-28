import { useMemo } from 'react';
import { Text, View } from 'react-native';
import Animated, { FadeInDown, FadeOut } from 'react-native-reanimated';
import { KORT, SNEL, natikken } from '../onderdelen/beweging';
import { Glas } from '../onderdelen/Glas';
import { useNachtKleur } from '../onderdelen/nacht';
import { L } from '../onderdelen/letters';
import { maten, useMaten } from '../onderdelen/maten';
import { Rondje } from '../onderdelen/Rondje';
import { Scherm } from '../onderdelen/Scherm';
import { Segment } from '../onderdelen/Segment';
import { Voortgang } from '../onderdelen/Voortgang';
import { datumTekst, opDeze, ritmeBlokken, stapSleutel, wieDoetMee } from '../onderdelen/inhoud';
import { Agenda } from '../onderdelen/Agenda';
import { useGezin } from '../onderdelen/gezin';
import { vinkSleutel, type Vinkjes } from '../onderdelen/opslag';
import type { Inhoud, Ritme, Stap } from '../onderdelen/soorten';

export default function Ritmescherm() {
  const m = useMaten();
  const { inhoud, vinkjes, ritme, zetRitme, tik, nu } = useGezin();

  const blokken = useMemo(
    () => (inhoud ? ritmeBlokken(inhoud, ritme, nu).filter((b) => b.items.length) : []),
    [inhoud, ritme, nu],
  );

  const groepen = useMemo(() => {
    if (!inhoud) return [];
    return inhoud[ritme]
      .map((g) => ({ ...g, stappen: g.stappen.filter((s) => s.label && opDeze(s, nu)) }))
      .filter((g) => g.stappen.length);
  }, [inhoud, ritme, nu]);

  const deel = useMemo(() => {
    const uit: Record<string, { af: number; totaal: number }> = {};
    if (!inhoud) return uit;
    inhoud.mensen.forEach((p) => {
      let totaal = 0, af = 0;
      groepen.forEach((g) => g.stappen.forEach((s) => {
        if (!wieDoetMee(s, inhoud.mensen).some((x) => x.id === p.id)) return;
        totaal += 1;
        if (vinkjes[vinkSleutel(ritme, stapSleutel(s), p.id)]) af += 1;
      }));
      uit[p.id] = { af, totaal };
    });
    return uit;
  }, [inhoud, groepen, vinkjes, ritme]);

  // Staat er niets in de agenda, dan vervalt de kolom en krijgen de kaartjes
  // de volle breedte.
  const metZij = m.breed && blokken.length > 0;

  return (
    <Scherm
      titel={ritme === 'nacht' ? 'Avond' : 'Ochtend'}
      onder={datumTekst(nu)}
      midden={<Segment ritme={ritme} opKies={zetRitme} marge={m.breed ? 0 : 16} />}
    >
      {/* Eén kolom op een telefoon — voortgang, Vandaag, de stappen, Morgen —
          en twee zodra er ruimte is, met het weekritme ernaast. */}
      <View style={m.breed ? { flexDirection: 'row', alignItems: 'flex-start', gap: m.naast } : undefined}>
        <View style={m.breed ? { flex: 1, minWidth: 0, paddingTop: metZij ? 31 : 0 } : undefined}>
          {inhoud && <Voortgang mensen={inhoud.mensen} deel={deel} marge={m.breed ? 0 : 14} />}

          {!m.breed && inhoud && blokken.filter((b) => !b.later)
            .map((blok) => <Agenda key={blok.kop} blok={blok} mensen={inhoud.mensen} />)}

          {groepen.map((groep, gi) => (
            <Animated.View
              key={groep.groep + gi}
              entering={FadeInDown.duration(KORT.duration).delay(natikken(gi, 40))}
              exiting={FadeOut.duration(SNEL.duration)}
            >
              <View
                style={{ flexDirection: 'row', alignItems: 'baseline', gap: 12,
                         marginTop: 20, paddingHorizontal: m.insprong, paddingBottom: 10 }}
              >
                <Groepkop>{groep.groep}</Groepkop>
                {!!groep.tijd && <Groeptijd>{groep.tijd}</Groeptijd>}
              </View>
              {/* De ruimte tussen de kaartjes zit in de kaartjes zelf; de
                  rand eromheen wordt er weer afgehaald. */}
              <View
                style={{ flexDirection: 'row', flexWrap: 'wrap',
                         marginHorizontal: -m.tussen / 2, marginBottom: -m.tussen }}
              >
                {groep.stappen.map((stap, si) => (
                  <Kaartje
                    key={stap.label + si}
                    stap={stap}
                    inhoud={inhoud!}
                    ritme={ritme}
                    vinkjes={vinkjes}
                    opTik={tik}
                    maten={m}
                    vertraag={natikken(gi * 3 + si)}
                  />
                ))}
              </View>
            </Animated.View>
          ))}

          {!m.breed && inhoud && blokken.filter((b) => b.later)
            .map((blok) => <Agenda key={blok.kop} blok={blok} mensen={inhoud.mensen} />)}
        </View>

        {metZij && inhoud && (
          <View style={{ width: m.zijkolom, flexShrink: 0 }}>
            {blokken.map((blok, i) => (
              <Agenda key={blok.kop} blok={blok} mensen={inhoud.mensen} zij eerste={i === 0} />
            ))}
          </View>
        )}
      </View>
    </Scherm>
  );
}

function Groepkop({ children }: { children: string }) {
  const kleur = useNachtKleur('#2B2D42', '#ffffff');
  return <Animated.Text style={[L.groep, kleur]}>{children}</Animated.Text>;
}

function Groeptijd({ children }: { children: string }) {
  const kleur = useNachtKleur('#5C5F7A', 'rgba(255,255,255,0.6)');
  return <Animated.Text style={[L.groeptijd, kleur]}>{children}</Animated.Text>;
}

function Kaartje({ stap, inhoud, ritme, vinkjes, opTik, maten: m, vertraag }: {
  stap: Stap; inhoud: Inhoud; ritme: Ritme; vinkjes: Vinkjes;
  opTik: (sleutel: string) => void; maten: ReturnType<typeof maten>; vertraag: number;
}) {
  const sleutel = stapSleutel(stap);
  const meedoen = wieDoetMee(stap, inhoud.mensen);
  return (
    <Animated.View
      entering={FadeInDown.duration(KORT.duration).delay(vertraag)}
      style={{ width: `${100 / m.perRij}%`, paddingHorizontal: m.tussen / 2, paddingBottom: m.tussen }}
    >
      <Glas
        radius={22}
        inhoudStijl={{
          alignItems: 'center', gap: m.kaartGat,
          paddingHorizontal: m.kaartX, paddingVertical: m.kaartY,
          minHeight: m.hoog,
        }}
      >
        {/* Emoji en naam staan samen midden in de kaart: de vrije ruimte valt
            boven de emoji en onder de naam, want de rondjes staan vast. */}
        <Text style={{ fontSize: m.icoon, lineHeight: m.icoon * 1.15, marginTop: 'auto' }}>{stap.icoon}</Text>
        <Taaknaam maat={m.naam}>{stap.label}</Taaknaam>
        {/* De rondjes zakken naar de onderkant, zodat elk kaartje er hetzelfde
            uitziet ongeacht hoe lang de naam is. */}
        <View style={{ marginTop: 'auto', alignSelf: 'stretch', flexDirection: 'row', flexWrap: 'wrap',
                       alignItems: 'center', justifyContent: 'center', columnGap: 2, rowGap: 2 }}>
          {meedoen.map((persoon) => (
            <Rondje
              key={persoon.id}
              persoon={persoon}
              aan={Boolean(vinkjes[vinkSleutel(ritme, sleutel, persoon.id)])}
              maat={m.rondje}
              gezicht={m.gezicht}
              teken={m.teken}
              opTik={() => opTik(vinkSleutel(ritme, sleutel, persoon.id))}
            />
          ))}
        </View>
      </Glas>
    </Animated.View>
  );
}

function Taaknaam({ children, maat }: { children: string; maat: number }) {
  const kleur = useNachtKleur('#2B2D42', '#ffffff');
  return (
    <Animated.Text style={[L.taaknaam, { fontSize: maat, lineHeight: maat * 1.2 }, kleur]} numberOfLines={2}>
      {children}
    </Animated.Text>
  );
}
