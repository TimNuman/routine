import { Pressable, Text } from 'react-native';
import Animated, {
  interpolateColor, useAnimatedStyle, useSharedValue, withSequence, withSpring, withTiming,
} from 'react-native-reanimated';
import { useEffect, useRef } from 'react';
import { zacht } from './inhoud';
import { SNEL, VEER, WIP } from './beweging';
import { useNacht, useNachtKleur } from './nacht';
import { L } from './letters';
import type { Persoon } from './soorten';

const GROEN = '#34C759';

// Precies zoals de webversie: het gezichtje staat er altijd, maar grijs en
// flauw zolang het niet af is. Afvinken geeft het zijn kleur terug en zet er
// een groene ring omheen. Geen vinkje dat het gezicht wegduwt.
export function Rondje({ persoon, aan, maat = 40, gezicht: gezichtMaat = 34, teken = 21, opTik }: {
  persoon: Persoon; aan: boolean; maat?: number; gezicht?: number; teken?: number; opTik: () => void;
}) {

  const nacht = useNacht();
  const vol = useSharedValue(aan ? 1 : 0);
  const ingedrukt = useSharedValue(0);
  const pop = useSharedValue(1);
  const eerste = useRef(true);

  useEffect(() => {
    vol.value = withTiming(aan ? 1 : 0, SNEL);
    // Alleen bij het aanzetten een wipje, en alleen als jij het aanzet — niet
    // bij het eerste tekenen van het scherm.
    if (aan && !eerste.current) {
      pop.value = withSequence(withSpring(1.16, WIP), withSpring(1, VEER));
    }
    eerste.current = false;
  }, [aan]);

  const heel = useAnimatedStyle(() => ({
    transform: [{ scale: pop.value * (1 - ingedrukt.value * 0.1) }],
  }));

  // De ring ligt eromheen en zet zich er in één beweging omheen.
  const ring = useAnimatedStyle(() => ({
    opacity: vol.value,
    transform: [{ scale: 0.9 + vol.value * 0.1 }],
  }));

  // Het randje in de uit-stand verschiet mee met de avond, net als het glas.
  const gezicht = useAnimatedStyle(() => ({
    opacity: 0.4 + vol.value * 0.6,
    borderColor: interpolateColor(
      nacht.value, [0, 1],
      [`rgba(43,45,66,${0.14 * (1 - vol.value)})`, `rgba(255,255,255,${0.18 * (1 - vol.value)})`],
    ),
  }));

  return (
    <Pressable
      onPressIn={() => { ingedrukt.value = withTiming(1, { duration: 60 }); }}
      onPressOut={() => { ingedrukt.value = withSpring(0, VEER); }}
      onPress={opTik}
      hitSlop={4}
      accessibilityRole="checkbox"
      accessibilityState={{ checked: aan }}
      accessibilityLabel={persoon.naam}
    >
      <Animated.View style={[{ width: maat, height: maat, alignItems: 'center', justifyContent: 'center' }, heel]}>
        <Animated.View
          pointerEvents="none"
          style={[{
            position: 'absolute',
            width: gezichtMaat + 5, height: gezichtMaat + 5, borderRadius: (gezichtMaat + 5) / 2,
            borderWidth: 2.5, borderColor: GROEN,
            boxShadow: '0px 4px 10px rgba(0,0,0,0.16)',
          }, ring]}
        />
        <Animated.View
          style={[{
            width: gezichtMaat, height: gezichtMaat, borderRadius: gezichtMaat / 2,
            alignItems: 'center', justifyContent: 'center', borderWidth: 1.5,
            backgroundColor: zacht(persoon.kleur, 0.16),
          }, gezicht]}
        >
          {/* filter bestaat sinds de nieuwe architectuur ook op een telefoon;
              valt hij weg, dan blijft de doorzichtigheid het verschil dragen. */}
          <Text style={{ fontSize: teken, lineHeight: teken * 1.15, filter: aan ? undefined : 'grayscale(1)' } as any}>
            {persoon.emoji}
          </Text>
        </Animated.View>
      </Animated.View>
    </Pressable>
  );
}

export function Naampje({ persoon }: { persoon: Persoon }) {
  const kleur = useNachtKleur('#5C5F7A', 'rgba(255,255,255,0.6)');
  return <Animated.Text style={[L.kindnaam, kleur]} numberOfLines={1}>{persoon.naam}</Animated.Text>;
}
