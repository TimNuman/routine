// De lijst met instellingen: een tegel met een emoji, een titel met uitleg
// eronder, en een pijltje rechts.
import { Pressable, Text, View } from 'react-native';
import Animated, { interpolateColor, useAnimatedStyle } from 'react-native-reanimated';
import Svg, { Path } from 'react-native-svg';
import { Glas } from './Glas';
import { useNacht, useNachtKleur } from './nacht';
import { L } from './letters';

export function Lijst({ children }: { children: React.ReactNode }) {
  return <Glas radius={26} style={{ marginTop: 16 }} inhoudStijl={{ overflow: 'hidden' }}>{children}</Glas>;
}

export function Lijstrij({ icoon, titel, uitleg, eerste, rechts, opTik }: {
  icoon: string; titel: string; uitleg: string; eerste: boolean;
  rechts?: React.ReactNode; opTik: () => void;
}) {
  const nacht = useNacht();
  const streep = useAnimatedStyle(() => ({
    borderTopColor: interpolateColor(nacht.value, [0, 1], ['rgba(43,45,66,0.08)', 'rgba(255,255,255,0.10)']),
  }));
  const tegel = useAnimatedStyle(() => ({
    backgroundColor: interpolateColor(nacht.value, [0, 1], ['rgba(255,255,255,0.72)', 'rgba(255,255,255,0.10)']),
    borderColor: interpolateColor(nacht.value, [0, 1], ['rgba(255,255,255,0.9)', 'rgba(255,255,255,0.16)']),
  }));
  return (
    <Animated.View style={[{ borderTopWidth: eerste ? 0 : 1 }, eerste ? null : streep]}>
      <Pressable
        onPress={opTik}
        accessibilityRole="button"
        style={{ flexDirection: 'row', alignItems: 'center', gap: 12, padding: 14, minHeight: 62 }}
      >
        <Animated.View
          style={[{ width: 46, height: 46, borderRadius: 15, borderWidth: 1,
                    alignItems: 'center', justifyContent: 'center' }, tegel]}
        >
          <Text style={{ fontSize: 22, lineHeight: 26 }}>{icoon}</Text>
        </Animated.View>
        <View style={{ flex: 1, minWidth: 0 }}>
          <Titel>{titel}</Titel>
          <Uitleg>{uitleg}</Uitleg>
        </View>
        {rechts}
        <Pijl />
      </Pressable>
    </Animated.View>
  );
}

// De gezichtjes die bij Kinderen rechts meekijken, half over elkaar.
export function Gezichten({ mensen, zacht }: {
  mensen: { id: string; emoji: string; kleur: string }[];
  zacht: (hex: string, alpha: number) => string;
}) {
  return (
    <View style={{ flexDirection: 'row' }}>
      {mensen.slice(0, 4).map((p, i) => (
        <View
          key={p.id}
          style={{ width: 34, height: 34, borderRadius: 17, marginLeft: i ? -8 : 0,
                   alignItems: 'center', justifyContent: 'center',
                   backgroundColor: zacht(p.kleur, 0.18),
                   boxShadow: '0px 0px 0px 2px rgba(255,255,255,0.85)' }}
        >
          <Text style={{ fontSize: 19, lineHeight: 23 }}>{p.emoji}</Text>
        </View>
      ))}
    </View>
  );
}

function Titel({ children }: { children: string }) {
  const kleur = useNachtKleur('#2B2D42', '#ffffff');
  return <Animated.Text style={[L.lijsttitel, kleur]} numberOfLines={1}>{children}</Animated.Text>;
}

function Uitleg({ children }: { children: string }) {
  const kleur = useNachtKleur('#5C5F7A', 'rgba(255,255,255,0.6)');
  return <Animated.Text style={[L.lijstuitleg, kleur]} numberOfLines={1}>{children}</Animated.Text>;
}

function Pijl() {
  return (
    <View style={{ opacity: 0.6 }}>
      <Svg width={9} height={15} viewBox="0 0 9 15" fill="none" stroke="#5C5F7A"
           strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
        <Path d="M1.5 1.5 7 7.5l-5.5 6" />
      </Svg>
    </View>
  );
}
