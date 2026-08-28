import { BlurView } from 'expo-blur';
import { Platform, View, type ViewStyle } from 'react-native';
import Animated, { interpolateColor, useAnimatedStyle } from 'react-native-reanimated';
import { useNacht } from './nacht';

// Het melkglas uit de webversie: blur erachter, een oplichtend randje, een glans
// langs de boven- en onderkant, en een zachte schaduw eronder. Dat randje en die
// glans zijn wat het glas maakt; zonder die twee is het een grijs vlak.
//
// De kleur komt uit de laag hieronder en niet uit de blur. BlurView zet namelijk
// zijn eigen achtergrond neer — bij tint 'light' een bijna dekkende
// rgba(249,249,249,.78) — en dan is er van glas niets meer over. Op web zetten
// we daarom de backdrop-filter zelf, precies zoals de css doet.
const vullend = { position: 'absolute', left: 0, right: 0, top: 0, bottom: 0 } as const;

function Waas() {
  if (Platform.OS === 'web') {
    return <View style={[vullend, { backdropFilter: 'blur(44px) saturate(200%)' } as any]} />;
  }
  // Op een telefoon kan dat niet zelf; daar doet BlurView het, met een tint die
  // zo min mogelijk eigen kleur meebrengt. Niet op een toestel geprobeerd.
  return <BlurView intensity={40} tint="systemUltraThinMaterial" style={vullend} />;
}

export function Glas({ radius = 22, zwevend = false, style, inhoudStijl, children }: {
  radius?: number; zwevend?: boolean;
  style?: ViewStyle; inhoudStijl?: ViewStyle; children?: React.ReactNode;
}) {
  const nacht = useNacht();

  const schaduw = useAnimatedStyle(() => {
    const n = nacht.value;
    const r = Math.round(126 - 122 * n);
    const g = Math.round(84 - 78 * n);
    const b = Math.round(42 - 16 * n);
    return { boxShadow: `0px 16px 38px rgba(${r}, ${g}, ${b}, ${(0.16 + 0.3 * n).toFixed(3)})` };
  });

  const vlak = useAnimatedStyle(() => {
    const n = nacht.value;
    const boven = (0.9 - 0.68 * n).toFixed(3);
    const onder = (0.4 - 0.34 * n).toFixed(3);
    return {
      backgroundColor: interpolateColor(
        n, [0, 1],
        zwevend
          ? ['rgba(255,255,255,0.82)', 'rgba(255,255,255,0.13)']
          : ['rgba(255,255,255,0.62)', 'rgba(255,255,255,0.09)'],
      ),
      borderColor: interpolateColor(
        n, [0, 1], ['rgba(255,255,255,0.75)', 'rgba(255,255,255,0.14)'],
      ),
      boxShadow: `inset 0px 1px 0px rgba(255,255,255,${boven}), inset 0px -1px 0px rgba(255,255,255,${onder})`,
    };
  });

  return (
    <Animated.View style={[{ borderRadius: radius }, schaduw, style]}>
      <View style={{ borderRadius: radius, overflow: 'hidden' }}>
        <Waas />
        <Animated.View style={[{ borderRadius: radius, borderWidth: 1 }, vlak, inhoudStijl]}>
          {children}
        </Animated.View>
      </View>
    </Animated.View>
  );
}
