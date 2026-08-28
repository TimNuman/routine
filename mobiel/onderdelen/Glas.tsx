import { BlurView } from 'expo-blur';
import { View, type ViewStyle } from 'react-native';
import Animated, { interpolateColor, useAnimatedStyle } from 'react-native-reanimated';
import { useNacht } from './nacht';

// Het melkglas uit de webversie: een doorschijnend vlak met blur erachter, een
// oplichtend randje, een glans langs de boven- en onderkant, en een zachte
// schaduw eronder. Dat randje en die glans zijn wat het glas maakt — zonder
// die twee is het gewoon een grijs vlak.
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
        [zwevend ? 'rgba(255,255,255,0.82)' : 'rgba(255,255,255,0.62)', 'rgba(255,255,255,0.09)'],
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
        {/* intensity is 0-100 en komt op web uit op ongeveer een vijfde in px;
            de webversie blurt 44px, dus hier zo hoog als het kan. */}
        <BlurView intensity={100} tint="light" style={{ position: 'absolute', left: 0, right: 0, top: 0, bottom: 0 }} />
        <Animated.View style={[{ borderRadius: radius, borderWidth: 1 }, vlak, inhoudStijl]}>
          {children}
        </Animated.View>
      </View>
    </Animated.View>
  );
}
