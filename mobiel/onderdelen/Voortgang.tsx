import { Text, View } from 'react-native';
import Animated, { useAnimatedStyle, withTiming, Easing } from 'react-native-reanimated';
import { zacht } from './inhoud';
import { RUSTIG } from './beweging';
import type { Persoon } from './soorten';

// Eén balkje per kind dat meeloopt met wat er af is.
export function Voortgang({ mensen, deel, avond }: {
  mensen: Persoon[]; deel: Record<string, number>; avond?: boolean;
}) {
  return (
    <View className={`mt-4 flex-row overflow-hidden rounded-[26px] ${avond ? 'bg-white/10' : 'bg-white/45'}`}>
      {mensen.map((persoon, i) => (
        <View
          key={persoon.id}
          className={`flex-1 flex-row items-center gap-2 p-3 ${i ? (avond ? 'border-l border-white/10' : 'border-l border-black/5') : ''}`}
        >
          <View
            className="h-9 w-9 items-center justify-center rounded-full"
            style={{ backgroundColor: zacht(persoon.kleur, 0.18) }}
          >
            <Text style={{ fontSize: 19 }}>{persoon.emoji}</Text>
          </View>
          <View className="min-w-0 flex-1">
            <Text
              className={`font-rondje text-[13px] ${avond ? 'text-white' : 'text-inkt'}`}
              numberOfLines={1}
            >
              {persoon.naam}
            </Text>
            <View className={`mt-1 h-[6px] overflow-hidden rounded-full ${avond ? 'bg-white/15' : 'bg-black/[0.07]'}`}>
              <Balk deel={deel[persoon.id] ?? 0} kleur={persoon.kleur} />
            </View>
          </View>
        </View>
      ))}
    </View>
  );
}

function Balk({ deel, kleur }: { deel: number; kleur: string }) {
  // Een balk die naveert leest als 'bijna klaar, toch niet'; dus gewoon lopen.
  const stijl = useAnimatedStyle(() => ({
    width: withTiming(`${Math.round(deel * 100)}%`, { ...RUSTIG, easing: Easing.out(Easing.cubic) }),
  }));
  return <Animated.View style={[{ height: 6, borderRadius: 3, backgroundColor: kleur }, stijl]} />;
}
