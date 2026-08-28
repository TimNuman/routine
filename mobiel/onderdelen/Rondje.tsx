import { Pressable, Text, View } from 'react-native';
import Animated, {
  useAnimatedStyle, useSharedValue, withSequence, withSpring, withTiming,
} from 'react-native-reanimated';
import { useEffect } from 'react';
import { zacht } from './inhoud';
import type { Persoon } from './soorten';

const VEER = { damping: 13, stiffness: 220, mass: 0.6 };

// Het gezichtje dat je aantikt. Aanzetten geeft een kort zwelletje en de ring
// vult zich; uitzetten loopt dezelfde weg terug. Alles op de ui-draad, dus het
// blijft soepel terwijl de schrijfactie nog onderweg is.
export function Rondje({ persoon, aan, avond, opTik }: {
  persoon: Persoon; aan: boolean; avond?: boolean; opTik: () => void;
}) {
  const vulling = useSharedValue(aan ? 1 : 0);
  const maat = useSharedValue(1);
  const ingedrukt = useSharedValue(0);

  useEffect(() => {
    vulling.value = withSpring(aan ? 1 : 0, VEER);
    if (aan) maat.value = withSequence(withSpring(1.18, { damping: 8, stiffness: 300 }), withSpring(1, VEER));
  }, [aan]);

  const ring = useAnimatedStyle(() => ({
    transform: [{ scale: maat.value * (1 - ingedrukt.value * 0.08) }],
    borderColor: vulling.value > 0.5
      ? persoon.kleur
      : (avond ? 'rgba(255,255,255,0.18)' : 'rgba(43,45,66,0.14)'),
    borderWidth: 2 + vulling.value,
  }));

  const gezicht = useAnimatedStyle(() => ({
    opacity: 1 - vulling.value,
    transform: [{ scale: 1 - vulling.value * 0.35 }, { rotate: `${vulling.value * -25}deg` }],
  }));

  const vink = useAnimatedStyle(() => ({
    opacity: vulling.value,
    transform: [{ scale: 0.5 + vulling.value * 0.5 }],
  }));

  return (
    <Pressable
      onPressIn={() => { ingedrukt.value = withTiming(1, { duration: 90 }); }}
      onPressOut={() => { ingedrukt.value = withTiming(0, { duration: 160 }); }}
      onPress={opTik}
      hitSlop={6}
      accessibilityRole="checkbox"
      accessibilityState={{ checked: aan }}
      accessibilityLabel={persoon.naam}
    >
      <Animated.View
        style={[{ width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center',
                  backgroundColor: zacht(persoon.kleur, 0.16) }, ring]}
      >
        <Animated.View style={[{ position: 'absolute' }, gezicht]}>
          <Text style={{ fontSize: 21 }}>{persoon.emoji}</Text>
        </Animated.View>
        <Animated.View
          style={[{ position: 'absolute', width: 26, height: 26, borderRadius: 13,
                    alignItems: 'center', justifyContent: 'center', backgroundColor: persoon.kleur }, vink]}
        >
          <Text style={{ color: '#fff', fontSize: 15, fontWeight: '900', lineHeight: 18 }}>✓</Text>
        </Animated.View>
      </Animated.View>
    </Pressable>
  );
}

export function Naampje({ persoon, avond }: { persoon: Persoon; avond?: boolean }) {
  return (
    <View>
      <Text
        className={`font-tekstdik text-[11px] ${avond ? 'text-white/60' : 'text-inkt-zacht'}`}
        numberOfLines={1}
      >
        {persoon.naam}
      </Text>
    </View>
  );
}
