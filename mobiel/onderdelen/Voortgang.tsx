import { Text, View } from 'react-native';
import Animated, { interpolateColor, useAnimatedStyle, withTiming, Easing } from 'react-native-reanimated';
import { zacht } from './inhoud';
import { RUSTIG } from './beweging';
import { Glas } from './Glas';
import { useNacht, useNachtKleur } from './nacht';
import { L } from './letters';
import type { Persoon } from './soorten';

// Eén balkje per kind dat meeloopt met wat er af is.
export function Voortgang({ mensen, deel }: { mensen: Persoon[]; deel: Record<string, number> }) {
  return (
    <Glas radius={26} style={{ marginTop: 16 }} inhoudStijl={{ flexDirection: 'row' }}>
      {mensen.map((persoon, i) => (
        <Scheiding key={persoon.id} eerste={i === 0}>
          <View
            className="h-9 w-9 items-center justify-center rounded-full"
            style={{ backgroundColor: zacht(persoon.kleur, 0.18) }}
          >
            <Text style={{ fontSize: 19 }}>{persoon.emoji}</Text>
          </View>
          <View className="min-w-0 flex-1">
            <Naam>{persoon.naam}</Naam>
            <Goot>
              <Balk deel={deel[persoon.id] ?? 0} kleur={persoon.kleur} />
            </Goot>
          </View>
        </Scheiding>
      ))}
    </Glas>
  );
}

function Scheiding({ eerste, children }: { eerste: boolean; children: React.ReactNode }) {
  const nacht = useNacht();
  const rand = useAnimatedStyle(() => ({
    borderLeftColor: interpolateColor(nacht.value, [0, 1], ['rgba(0,0,0,0.05)', 'rgba(255,255,255,0.10)']),
  }));
  return (
    <Animated.View
      style={[{ flex: 1, flexDirection: 'row', alignItems: 'center', gap: 8, padding: 12,
                borderLeftWidth: eerste ? 0 : 1 }, eerste ? null : rand]}
    >
      {children}
    </Animated.View>
  );
}

function Naam({ children }: { children: string }) {
  const kleur = useNachtKleur('#2B2D42', '#ffffff');
  return <Animated.Text style={[L.naam, kleur]} numberOfLines={1}>{children}</Animated.Text>;
}

function Goot({ children }: { children: React.ReactNode }) {
  const nacht = useNacht();
  const vlak = useAnimatedStyle(() => ({
    backgroundColor: interpolateColor(nacht.value, [0, 1], ['rgba(0,0,0,0.07)', 'rgba(255,255,255,0.15)']),
  }));
  return (
    <Animated.View style={[{ marginTop: 4, height: 6, borderRadius: 3, overflow: 'hidden' }, vlak]}>
      {children}
    </Animated.View>
  );
}

function Balk({ deel, kleur }: { deel: number; kleur: string }) {
  // Een balk die naveert leest als 'bijna klaar, toch niet'; dus gewoon lopen.
  const stijl = useAnimatedStyle(() => ({
    width: withTiming(`${Math.round(deel * 100)}%`, { ...RUSTIG, easing: Easing.out(Easing.cubic) }),
  }));
  return <Animated.View style={[{ height: 6, borderRadius: 3, backgroundColor: kleur }, stijl]} />;
}
