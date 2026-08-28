// Het zwevende menu, net als op web: op een telefoon over de inhoud heen
// onderaan, op een breed scherm rechts in de kopregel. De kleur klapt om in
// plaats van mee te verschieten — dat doet de webversie ook.
import { Pressable, Text, View } from 'react-native';
import { usePathname, useRouter } from 'expo-router';
import Svg, { Circle, Path, Rect } from 'react-native-svg';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Glas } from './Glas';
import { useGezin } from './gezin';
import { L } from './letters';

const ORANJE = '#F2994A';

type Pad = '/' | '/week' | '/instellingen';
type Tab = { pad: Pad; naam: string; teken: 'ritme' | 'week' | 'tandwiel' };

const TABS: Tab[] = [
  { pad: '/', naam: 'Ritme', teken: 'ritme' },
  { pad: '/week', naam: 'Deze week', teken: 'week' },
  { pad: '/instellingen', naam: 'Instellingen', teken: 'tandwiel' },
];

export function Tabbalk({ breed }: { breed: boolean }) {
  const rand = useSafeAreaInsets();
  const router = useRouter();
  const hier = usePathname();
  // Niet naar het ritme kijken maar naar het scherm: op de week en de
  // instellingen is het licht, ook als het avondritme aanstaat.
  const { avond } = useGezin();
  const rustig = avond ? 'rgba(255,255,255,0.55)' : 'rgba(43,45,66,0.52)';

  const balk = (
    <Glas radius={breed ? 26 : 34} zwevend inhoudStijl={{ flexDirection: 'row', gap: 4, padding: breed ? 4 : 5 }}>
      {TABS.map((tab) => {
        const aan = hier === tab.pad;
        return (
          <Pressable
            key={tab.pad}
            onPress={() => { if (!aan) router.replace(tab.pad); }}
            accessibilityRole="tab"
            accessibilityState={{ selected: aan }}
            style={{
              flex: 1, alignItems: 'center', justifyContent: 'center',
              flexDirection: breed ? 'row' : 'column', gap: breed ? 7 : 2,
              paddingVertical: breed ? 8 : 7, borderRadius: 20,
              backgroundColor: aan ? 'rgba(242,153,74,0.16)' : 'transparent',
              boxShadow: aan ? 'inset 0px 0px 0px 1px rgba(242,153,74,0.28)' : undefined,
            }}
          >
            <Teken soort={tab.teken} kleur={aan ? ORANJE : rustig} maat={breed ? 19 : 23} />
            <Text style={[breed ? L.tabbreed : L.tab, { color: aan ? ORANJE : rustig }]}>{tab.naam}</Text>
          </Pressable>
        );
      })}
    </Glas>
  );

  if (breed) return balk;
  return (
    <View
      pointerEvents="box-none"
      style={{ position: 'absolute', left: 14, right: 14, bottom: rand.bottom + 18, zIndex: 40 }}
    >
      <View style={{ maxWidth: 492, width: '100%', alignSelf: 'center' }}>{balk}</View>
    </View>
  );
}

// Dezelfde lijnen en dikte als de svg's in de webversie.
function Teken({ soort, kleur, maat }: { soort: Tab['teken']; kleur: string; maat: number }) {
  return (
    <Svg viewBox="0 0 24 24" width={maat} height={maat} fill="none" stroke={kleur}
         strokeWidth={1.9} strokeLinecap="round" strokeLinejoin="round">
      {soort === 'ritme' && (
        <>
          <Path d="M4 6h2.5M4 12h2.5M4 18h2.5" />
          <Path d="M10.5 6H20M10.5 12H20M10.5 18H20" />
        </>
      )}
      {soort === 'week' && (
        <>
          <Rect x={3.5} y={5} width={17} height={15.5} rx={4} />
          <Path d="M3.5 10h17M8.5 3.2v3.4M15.5 3.2v3.4" />
        </>
      )}
      {soort === 'tandwiel' && (
        <>
          <Circle cx={12} cy={12} r={3.2} />
          <Path d="M12 3.2v2.2M12 18.6V20.8M20.8 12h-2.2M5.4 12H3.2M17.3 6.7l-1.5 1.5M8.2 15.8l-1.5 1.5M17.3 17.3l-1.5-1.5M8.2 8.2 6.7 6.7" />
        </>
      )}
    </Svg>
  );
}
