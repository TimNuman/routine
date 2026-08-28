import { Text, View } from 'react-native';
import Animated, { interpolateColor, useAnimatedStyle, withTiming, Easing } from 'react-native-reanimated';
import { zacht } from './inhoud';
import { RUSTIG } from './beweging';
import { Glas } from './Glas';
import { useNacht, useNachtKleur } from './nacht';
import { L } from './letters';
import type { Persoon } from './soorten';

// Eén balkje per kind dat meeloopt met wat er af is. Vanaf drie kinderen naast
// elkaar wordt het te smal: dan twee per regel, net als op web.
export function Voortgang({ mensen, deel, marge }: {
  mensen: Persoon[]; deel: Record<string, { af: number; totaal: number }>; marge: number;
}) {
  const velen = mensen.length > 2;
  return (
    <Glas
      radius={26}
      style={{ marginTop: marge }}
      inhoudStijl={{ flexDirection: 'row', flexWrap: velen ? 'wrap' : 'nowrap' }}
    >
      {mensen.map((persoon, i) => (
        <Scheiding
          key={persoon.id}
          links={velen ? i % 2 === 1 : i > 0}
          boven={velen && i >= 2}
          breedte={velen ? '50%' : undefined}
        >
          <View
            style={{ width: 46, height: 46, borderRadius: 23, alignItems: 'center',
                     justifyContent: 'center', backgroundColor: zacht(persoon.kleur, 0.18) }}
          >
            <Text style={{ fontSize: 26, lineHeight: 30 }}>{persoon.emoji}</Text>
          </View>
          <View style={{ flex: 1, minWidth: 0 }}>
            <View style={{ flexDirection: 'row', alignItems: 'baseline', justifyContent: 'space-between', gap: 6 }}>
              <Naam>{persoon.naam}</Naam>
              <Telling>{`${deel[persoon.id]?.af ?? 0}/${deel[persoon.id]?.totaal ?? 0}`}</Telling>
            </View>
            <Goot>
              <Balk
                deel={deel[persoon.id]?.totaal ? deel[persoon.id].af / deel[persoon.id].totaal : 0}
                kleur={persoon.kleur}
              />
            </Goot>
          </View>
        </Scheiding>
      ))}
    </Glas>
  );
}

function Scheiding({ links, boven, breedte, children }: {
  links: boolean; boven: boolean; breedte?: '50%'; children: React.ReactNode;
}) {
  const nacht = useNacht();
  const rand = useAnimatedStyle(() => {
    const kleur = interpolateColor(nacht.value, [0, 1], ['rgba(0,0,0,0.05)', 'rgba(255,255,255,0.10)']);
    return { borderLeftColor: kleur, borderTopColor: kleur };
  });
  return (
    <Animated.View
      style={[
        { flexDirection: 'row', alignItems: 'center', gap: 11,
          paddingVertical: 13, paddingHorizontal: 14, minWidth: 0,
          borderLeftWidth: links ? 1 : 0, borderTopWidth: boven ? 1 : 0 },
        breedte ? { width: breedte } : { flex: 1 },
        links || boven ? rand : null,
      ]}
    >
      {children}
    </Animated.View>
  );
}

function Naam({ children }: { children: string }) {
  const kleur = useNachtKleur('#2B2D42', '#ffffff');
  return (
    <Animated.Text style={[L.naam, kleur, { flexShrink: 1 }]} numberOfLines={1}>{children}</Animated.Text>
  );
}

function Telling({ children }: { children: string }) {
  const kleur = useNachtKleur('#5C5F7A', 'rgba(255,255,255,0.6)');
  return <Animated.Text style={[L.telling, kleur]}>{children}</Animated.Text>;
}

function Goot({ children }: { children: React.ReactNode }) {
  const nacht = useNacht();
  const vlak = useAnimatedStyle(() => ({
    backgroundColor: interpolateColor(nacht.value, [0, 1], ['rgba(43,45,66,0.10)', 'rgba(255,255,255,0.14)']),
  }));
  return (
    <Animated.View style={[{ marginTop: 6, height: 7, borderRadius: 99, overflow: 'hidden' }, vlak]}>
      {children}
    </Animated.View>
  );
}

function Balk({ deel, kleur }: { deel: number; kleur: string }) {
  // Een balk die naveert leest als 'bijna klaar, toch niet'; dus gewoon lopen.
  const stijl = useAnimatedStyle(() => ({
    width: withTiming(`${Math.round(deel * 100)}%`, { ...RUSTIG, easing: Easing.out(Easing.cubic) }),
  }));
  return <Animated.View style={[{ height: 7, borderRadius: 99, backgroundColor: kleur }, stijl]} />;
}
