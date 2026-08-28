import { Pressable, Text, View } from 'react-native';
import Animated, { useAnimatedStyle, withSpring } from 'react-native-reanimated';
import { useState } from 'react';
import type { Ritme } from './soorten';

// De pil schuift naar de gekozen kant in plaats van te knipperen.
export function Segment({ ritme, avond, opKies }: {
  ritme: Ritme; avond?: boolean; opKies: (r: Ritme) => void;
}) {
  const [breedte, zetBreedte] = useState(0);
  const pil = useAnimatedStyle(() => ({
    transform: [{ translateX: withSpring(ritme === 'nacht' ? breedte / 2 : 0, { damping: 18, stiffness: 190 }) }],
  }));

  return (
    <View
      onLayout={(e) => zetBreedte(e.nativeEvent.layout.width - 8)}
      className={`mt-4 flex-row rounded-[22px] p-1 ${avond ? 'bg-white/10' : 'bg-white/45'}`}
    >
      {breedte > 0 && (
        <Animated.View
          style={[{ position: 'absolute', top: 4, left: 4, width: breedte / 2, height: 42, borderRadius: 19,
                    backgroundColor: avond ? 'rgba(255,255,255,0.92)' : '#fff' }, pil]}
        />
      )}
      {([['dag', 'ochtend'], ['nacht', 'avond']] as const).map(([waarde, label]) => (
        <Pressable key={waarde} onPress={() => opKies(waarde)} className="h-[42px] flex-1 items-center justify-center">
          <Text className={`font-rondje text-[15px] ${ritme === waarde ? 'text-inkt' : 'text-inkt-zacht'}`}>
            {label}
          </Text>
        </Pressable>
      ))}
    </View>
  );
}
