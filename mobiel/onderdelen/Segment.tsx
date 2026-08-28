import { Pressable, View } from 'react-native';
import Animated, { interpolateColor, useAnimatedStyle, withSpring } from 'react-native-reanimated';
import { useState } from 'react';
import { VEER } from './beweging';
import { Glas } from './Glas';
import { useNacht, useNachtKleur } from './nacht';
import { L } from './letters';
import type { Ritme } from './soorten';

// De pil schuift naar de gekozen kant in plaats van te knipperen.
export function Segment({ ritme, opKies, marge = 16 }: {
  ritme: Ritme; opKies: (r: Ritme) => void; marge?: number;
}) {
  const [breedte, zetBreedte] = useState(0);
  const nacht = useNacht();

  const pil = useAnimatedStyle(() => ({
    transform: [{ translateX: withSpring(ritme === 'nacht' ? breedte / 2 : 0, VEER) }],
    backgroundColor: interpolateColor(nacht.value, [0, 1], ['#ffffff', 'rgba(255,255,255,0.92)']),
  }));

  return (
    <Glas radius={19} style={{ marginTop: marge }} inhoudStijl={{ flexDirection: 'row', padding: 4 }}>
      <View
        onLayout={(e) => zetBreedte(e.nativeEvent.layout.width)}
        style={{ position: 'absolute', left: 4, right: 4, top: 4, bottom: 4 }}
      />
      {breedte > 0 && (
        <Animated.View
          style={[{ position: 'absolute', top: 4, left: 4, width: breedte / 2, height: 42, borderRadius: 15,
                    boxShadow: '0px 3px 10px rgba(0,0,0,0.10)' }, pil]}
        />
      )}
      {([['dag', 'ochtend'], ['nacht', 'avond']] as const).map(([waarde, label]) => (
        <Pressable
          key={waarde}
          onPress={() => opKies(waarde)}
          accessibilityRole="button"
          accessibilityState={{ selected: ritme === waarde }}
          className="h-[42px] flex-1 items-center justify-center"
        >
          <Knop actief={ritme === waarde}>{label}</Knop>
        </Pressable>
      ))}
    </Glas>
  );
}

function Knop({ actief, children }: { actief: boolean; children: string }) {
  const kleur = useNachtKleur(actief ? '#2B2D42' : '#5C5F7A', actief ? '#2B2D42' : 'rgba(255,255,255,0.62)');
  return <Animated.Text style={[L.knop, kleur]}>{children}</Animated.Text>;
}
