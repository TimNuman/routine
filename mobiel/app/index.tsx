import { useCallback, useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, ScrollView, Text, View, useWindowDimensions } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import Animated, { FadeInDown, FadeOut, LinearTransition } from 'react-native-reanimated';
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

  return (
    <View className="flex-1">
      <LinearGradient
        colors={avond ? ['#3B3F70', '#232645', '#171a33'] : ['#FFE3B8', '#FFD9CE', '#D9E8F5']}
        style={{ position: 'absolute', inset: 0 as any, top: 0, left: 0, right: 0, bottom: 0 }}
      />
      <ScrollView
        contentContainerStyle={{ paddingTop: rand.top + 18, paddingBottom: rand.bottom + 40, paddingHorizontal: 16 }}
        contentInsetAdjustmentBehavior="automatic"
      >
        <Text className={`font-rond text-[40px] leading-[46px] ${avond ? 'text-white' : 'text-inkt'}`}>
          {avond ? 'Avond' : 'Ochtend'}
        </Text>
        <Text className={`font-tekstdik text-[15px] ${avond ? 'text-white/70' : 'text-inkt-zacht'}`}>
          {DAGNAMEN[nu.getDay()]} {nu.getDate()} {MAANDEN[nu.getMonth()]}
        </Text>

        <Segment ritme={ritme} avond={avond} opKies={zetRitme} />

        {!inhoud && !fout && <ActivityIndicator className="mt-10" color="#F2994A" />}
        {!!fout && (
          <Text className="mt-8 font-tekstdik text-[14px] text-rood">
            De inhoud laden lukte niet ({fout}).
          </Text>
        )}

        {inhoud && <Voortgang mensen={inhoud.mensen} deel={deel} avond={avond} />}

        {groepen.map((groep, gi) => (
          <Animated.View
            key={groep.groep + gi}
            entering={FadeInDown.delay(60 + gi * 70).springify().damping(18)}
            exiting={FadeOut.duration(140)}
            layout={LinearTransition.springify().damping(20)}
            className="mt-6"
          >
            <View className="mb-2 flex-row items-baseline gap-2 px-1">
              <Text className={`font-rond text-[19px] ${avond ? 'text-white' : 'text-inkt'}`}>{groep.groep}</Text>
              {!!groep.tijd && (
                <Text className={`font-tekstdik text-[13px] ${avond ? 'text-white/60' : 'text-inkt-zacht'}`}>
                  {groep.tijd}
                </Text>
              )}
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
                  vertraag={80 + gi * 70 + si * 35}
                />
              ))}
            </View>
          </Animated.View>
        ))}
      </ScrollView>
    </View>
  );
}

function Kaartje({ stap, inhoud, ritme, vinkjes, opTik, avond, breed, vertraag }: {
  stap: Stap; inhoud: Inhoud; ritme: Ritme; vinkjes: Vinkjes;
  opTik: (sleutel: string) => void; avond: boolean; breed: number; vertraag: number;
}) {
  const sleutel = stapSleutel(stap);
  const meedoen = wieDoetMee(stap, inhoud.mensen);
  return (
    <Animated.View
      entering={FadeInDown.delay(vertraag).springify().damping(16)}
      layout={LinearTransition.springify().damping(20)}
      style={{ width: `${breed}%`, paddingHorizontal: 5, paddingBottom: 10 }}
    >
      <View className={`items-center rounded-[26px] px-2 pb-3 pt-4 ${avond ? 'bg-white/[0.10]' : 'bg-white/60'}`}>
        <Text style={{ fontSize: 34, lineHeight: 40 }}>{stap.icoon}</Text>
        <Text
          className={`mt-1 text-center font-rondje text-[13px] leading-[16px] ${avond ? 'text-white' : 'text-inkt'}`}
          numberOfLines={2}
        >
          {stap.label}
        </Text>
        <View className="mt-3 flex-row flex-wrap items-center justify-center gap-x-1.5 gap-y-1.5">
          {meedoen.map((persoon) => (
            <View key={persoon.id} className="items-center">
              <Rondje
                persoon={persoon}
                aan={Boolean(vinkjes[vinkSleutel(ritme, sleutel, persoon.id)])}
                avond={avond}
                opTik={() => opTik(vinkSleutel(ritme, sleutel, persoon.id))}
              />
              {meedoen.length <= 2 && <Naampje persoon={persoon} avond={avond} />}
            </View>
          ))}
        </View>
      </View>
    </Animated.View>
  );
}
