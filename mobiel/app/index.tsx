import { useCallback, useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, ScrollView, Text, View, useWindowDimensions } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import Animated, {
  FadeInDown, FadeOut, LinearTransition, useAnimatedStyle, useSharedValue, withTiming, Easing,
} from 'react-native-reanimated';
import { KORT, SNEL, natikken } from '../onderdelen/beweging';
import { Glas } from '../onderdelen/Glas';
import { Nacht, useNachtKleur } from '../onderdelen/nacht';
import { L } from '../onderdelen/letters';
import { Rondje, Naampje } from '../onderdelen/Rondje';
import { Segment } from '../onderdelen/Segment';
import { Voortgang } from '../onderdelen/Voortgang';
import { datumVan, opDeze, stapSleutel, wieDoetMee } from '../onderdelen/inhoud';
import { haalInhoud, haalVinkjes, schrijfVink, vinkSleutel, type Vinkjes } from '../onderdelen/opslag';
import type { Inhoud, Ritme, Stap } from '../onderdelen/soorten';

const MAANDEN = ['januari','februari','maart','april','mei','juni','juli','augustus','september','oktober','november','december'];
const DAGNAMEN = ['zondag','maandag','dinsdag','woensdag','donderdag','vrijdag','zaterdag'];

export default function Ritmescherm() {
  const rand = useSafeAreaInsets();
  const { width } = useWindowDimensions();
  const perRij = width >= 1000 ? 5 : width >= 700 ? 4 : 3;

  const [inhoud, zetInhoud] = useState<Inhoud | null>(null);
  const [fout, zetFout] = useState('');
  const [vinkjes, zetVinkjes] = useState<Vinkjes>({});
  const [ritme, zetRitme] = useState<Ritme>('dag');

  const nu = useMemo(() => new Date(), []);
  const datum = datumVan(nu);

  // Het hele scherm verschiet in één beweging van ochtend naar avond.
  const nacht = useSharedValue(0);
  useEffect(() => {
    nacht.value = withTiming(ritme === 'nacht' ? 1 : 0, { duration: 420, easing: Easing.inOut(Easing.quad) });
  }, [ritme]);
  const donker = useAnimatedStyle(() => ({ opacity: nacht.value }));

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

  const groepen = useMemo(() => {
    if (!inhoud) return [];
    return inhoud[ritme]
      .map((g) => ({ ...g, stappen: g.stappen.filter((s) => s.label && opDeze(s, nu)) }))
      .filter((g) => g.stappen.length);
  }, [inhoud, ritme, nu]);

  const deel = useMemo(() => {
    const uit: Record<string, number> = {};
    if (!inhoud) return uit;
    inhoud.mensen.forEach((p) => {
      let totaal = 0, af = 0;
      groepen.forEach((g) => g.stappen.forEach((s) => {
        if (!wieDoetMee(s, inhoud.mensen).some((x) => x.id === p.id)) return;
        totaal += 1;
        if (vinkjes[vinkSleutel(ritme, stapSleutel(s), p.id)]) af += 1;
      }));
      uit[p.id] = totaal ? af / totaal : 0;
    });
    return uit;
  }, [inhoud, groepen, vinkjes, ritme]);

  const avond = ritme === 'nacht';
  const vul = { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 } as const;

  return (
    <Nacht.Provider value={nacht}>
    <View className="flex-1">
      <LinearGradient colors={['#FFE3B8', '#FFD9CE', '#D9E8F5']} style={vul} />
      <Animated.View style={[vul, donker]} pointerEvents="none">
        <LinearGradient colors={['#3B3F70', '#232645', '#171a33']} style={vul} />
      </Animated.View>
      <ScrollView
        contentContainerStyle={{ paddingTop: rand.top + 18, paddingBottom: rand.bottom + 40, paddingHorizontal: 16 }}
        contentInsetAdjustmentBehavior="automatic"
      >
        <Titel>{avond ? 'Avond' : 'Ochtend'}</Titel>
        <Onder>{`${DAGNAMEN[nu.getDay()]} ${nu.getDate()} ${MAANDEN[nu.getMonth()]}`}</Onder>

        <Segment ritme={ritme} opKies={zetRitme} />

        {!inhoud && !fout && <ActivityIndicator className="mt-10" color="#F2994A" />}
        {!!fout && (
          <Text className="mt-8 font-tekstdik text-[14px] text-rood">
            De inhoud laden lukte niet ({fout}).
          </Text>
        )}

        {inhoud && <Voortgang mensen={inhoud.mensen} deel={deel} />}

        {groepen.map((groep, gi) => (
          <Animated.View
            key={groep.groep + gi}
            entering={FadeInDown.duration(KORT.duration).delay(natikken(gi, 40))}
            exiting={FadeOut.duration(SNEL.duration)}
            layout={LinearTransition.duration(KORT.duration)}
            className="mt-6"
          >
            <View className="mb-2 flex-row items-baseline gap-2 px-1">
              <Groepkop>{groep.groep}</Groepkop>
              {!!groep.tijd && <Groeptijd>{groep.tijd}</Groeptijd>}
            </View>
            <View className="flex-row flex-wrap" style={{ marginHorizontal: -5 }}>
              {groep.stappen.map((stap, si) => (
                <Kaartje
                  key={stap.label + si}
                  stap={stap}
                  inhoud={inhoud!}
                  ritme={ritme}
                  vinkjes={vinkjes}
                  opTik={tik}
                  avond={avond}
                  breed={100 / perRij}
                  vertraag={natikken(gi * 3 + si)}
                />
              ))}
            </View>
          </Animated.View>
        ))}
      </ScrollView>
    </View>
    </Nacht.Provider>
  );
}

function Titel({ children }: { children: string }) {
  const kleur = useNachtKleur('#2B2D42', '#ffffff');
  return <Animated.Text style={[L.titel, kleur]}>{children}</Animated.Text>;
}

function Onder({ children }: { children: string }) {
  const kleur = useNachtKleur('#5C5F7A', 'rgba(255,255,255,0.7)');
  return <Animated.Text style={[L.onder, kleur]}>{children}</Animated.Text>;
}

function Groepkop({ children }: { children: string }) {
  const kleur = useNachtKleur('#2B2D42', '#ffffff');
  return <Animated.Text style={[L.groep, kleur]}>{children}</Animated.Text>;
}

function Groeptijd({ children }: { children: string }) {
  const kleur = useNachtKleur('#5C5F7A', 'rgba(255,255,255,0.6)');
  return <Animated.Text style={[L.groeptijd, kleur]}>{children}</Animated.Text>;
}

function Kaartje({ stap, inhoud, ritme, vinkjes, opTik, avond, breed, vertraag }: {
  stap: Stap; inhoud: Inhoud; ritme: Ritme; vinkjes: Vinkjes;
  opTik: (sleutel: string) => void; avond: boolean; breed: number; vertraag: number;
}) {
  const sleutel = stapSleutel(stap);
  const meedoen = wieDoetMee(stap, inhoud.mensen);
  return (
    <Animated.View
      entering={FadeInDown.duration(KORT.duration).delay(vertraag)}
      layout={LinearTransition.duration(KORT.duration)}
      style={{ width: `${breed}%`, paddingHorizontal: 5, paddingBottom: 10 }}
    >
      <Glas radius={22} inhoudStijl={{ alignItems: 'center', paddingHorizontal: 8, paddingTop: 14, paddingBottom: 12 }}>
        <Text style={{ fontSize: 34, lineHeight: 40 }}>{stap.icoon}</Text>
        <Taaknaam>{stap.label}</Taaknaam>
        <View className="mt-3 flex-row flex-wrap items-center justify-center gap-x-1.5 gap-y-1.5">
          {meedoen.map((persoon) => (
            <View key={persoon.id} className="items-center">
              <Rondje
                persoon={persoon}
                aan={Boolean(vinkjes[vinkSleutel(ritme, sleutel, persoon.id)])}
                avond={avond}
                opTik={() => opTik(vinkSleutel(ritme, sleutel, persoon.id))}
              />
              {meedoen.length <= 2 && <Naampje persoon={persoon} />}
            </View>
          ))}
        </View>
      </Glas>
    </Animated.View>
  );
}

function Taaknaam({ children }: { children: string }) {
  const kleur = useNachtKleur('#2B2D42', '#ffffff');
  return (
    <Animated.Text style={[L.taaknaam, kleur]} numberOfLines={2}>{children}</Animated.Text>
  );
}
