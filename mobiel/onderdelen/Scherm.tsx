// Het kader dat elke pagina deelt: de lucht erachter, de kopregel en het menu.
// De avondkleuren horen alleen bij het ritme, dus de andere pagina's blijven
// licht — net als op web, waar body.nacht alleen op die pagina staat.
import { ActivityIndicator, ScrollView, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import Animated, { useAnimatedStyle } from 'react-native-reanimated';
import { L } from './letters';
import { useMaten } from './maten';
import { useNacht, useNachtKleur } from './nacht';
import { Tabbalk } from './Tabbalk';
import { useGezin } from './gezin';

const vul = { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 } as const;

export function Scherm({ titel, onder, midden, smal = false, children }: {
  titel: string; onder: string; midden?: React.ReactNode;
  smal?: boolean; children: React.ReactNode;
}) {
  const rand = useSafeAreaInsets();
  const m = useMaten();
  const nacht = useNacht();
  const { inhoud, fout } = useGezin();
  const donker = useAnimatedStyle(() => ({ opacity: nacht.value }));

  return (
    <View style={{ flex: 1 }}>
      <LinearGradient colors={['#FFE3B8', '#FFD9CE', '#D9E8F5']} style={vul} />
      <Animated.View style={[vul, donker]} pointerEvents="none">
        <LinearGradient colors={['#3B3F70', '#232645', '#171a33']} style={vul} />
      </Animated.View>

      {/* De insprong boven en onder rekenen we zelf. Staat de scrollweergave op
          'automatic', dan telt iOS de veilige rand er nog een keer bij op en
          begint de titel een statusbalk te laag; op web merk je daar niets van. */}
      <ScrollView
        contentContainerStyle={{
          paddingTop: rand.top + m.bovenaan, paddingBottom: rand.bottom + m.onderaan,
          paddingHorizontal: m.gootje, maxWidth: m.maxBreed, width: '100%', alignSelf: 'center',
        }}
        contentInsetAdjustmentBehavior="never"
      >
        {/* Alle tekst springt evenveel in als de inhoud van een kaart, zodat
            titel, kopjes en de eerste emoji op één lijn staan. Is er ruimte,
            dan staan de schakelaar en het menu naast de titel. */}
        <View style={m.breed ? { flexDirection: 'row', alignItems: 'center', gap: 24, paddingBottom: 4 } : undefined}>
          <View style={{ paddingLeft: m.insprong, flex: m.breed ? 1 : undefined, minWidth: 0 }}>
            <Titel>{titel}</Titel>
            <Onder>{onder}</Onder>
          </View>
          {!!midden && (
            <View style={m.breed ? { position: 'absolute', left: '50%', width: 250, marginLeft: -125 } : undefined}>
              {midden}
            </View>
          )}
          {m.breed && <View style={{ width: m.zijkolom, flexShrink: 0 }}><Tabbalk breed /></View>}
        </View>

        {!inhoud && !fout && <ActivityIndicator style={{ marginTop: 40 }} color="#F2994A" />}
        {!!fout && (
          <Text style={{ marginTop: 32, fontFamily: 'Nunito_800ExtraBold', fontSize: 14, color: '#E5484D' }}>
            De inhoud laden lukte niet ({fout}).
          </Text>
        )}

        {/* De week en de instellingen lezen als een lijst; die blijven smal,
            ook al is het scherm breed. */}
        <View style={smal && m.breed ? { maxWidth: 640, width: '100%' } : undefined}>
          {children}
        </View>
      </ScrollView>

      {!m.breed && <Tabbalk breed={false} />}
    </View>
  );
}

function Titel({ children }: { children: string }) {
  const kleur = useNachtKleur('#2B2D42', '#ffffff');
  return <Animated.Text style={[L.titel, kleur]}>{children}</Animated.Text>;
}

function Onder({ children }: { children: string }) {
  const kleur = useNachtKleur('#5C5F7A', 'rgba(255,255,255,0.7)');
  return <Animated.Text style={[L.onder, kleur]}>{children}</Animated.Text>;
}
