// De onderdelen waar de bewerkschermen uit bestaan: een invoerveld, chips om te
// kiezen, kopjes, notities en de regels in een bewerkkaart.
import { Pressable, Text, TextInput, View, type TextStyle } from 'react-native';
import Animated, { interpolateColor, useAnimatedStyle } from 'react-native-reanimated';
import { Glas } from './Glas';
import { useNacht, useNachtKleur } from './nacht';
import { L } from './letters';
import { zacht } from './inhoud';
import type { Persoon } from './soorten';

const ORANJE = '#F2994A';
const INKT = '#2B2D42';
const ZACHT = '#5C5F7A';

export function Formkop({ children, eerste = false }: { children: string; eerste?: boolean }) {
  const kleur = useNachtKleur(ZACHT, 'rgba(255,255,255,0.6)');
  return (
    <Animated.Text style={[L.formkop, { paddingTop: eerste ? 8 : 16 }, kleur]}>
      {children.toUpperCase()}
    </Animated.Text>
  );
}

export function Notitie({ children }: { children: string }) {
  const kleur = useNachtKleur(ZACHT, 'rgba(255,255,255,0.6)');
  return <Animated.Text style={[L.notitie, kleur]}>{children}</Animated.Text>;
}

export function Melding({ children }: { children: string }) {
  return (
    <View style={{ marginBottom: 14, paddingVertical: 11, paddingHorizontal: 14, borderRadius: 16,
                   backgroundColor: 'rgba(229,72,77,0.14)', borderWidth: 1,
                   borderColor: 'rgba(229,72,77,0.32)' }}>
      <Text style={[L.melding, { color: '#B0272C' }]}>{children}</Text>
    </View>
  );
}

export function Veld({ waarde, plaatshouder, opWijzig, soort = 'tekst', stijl }: {
  waarde: string; plaatshouder?: string; opWijzig: (v: string) => void;
  soort?: 'tekst' | 'tijd' | 'getal' | 'datum'; stijl?: TextStyle;
}) {
  const nacht = useNacht();
  const vlak = useAnimatedStyle(() => ({
    backgroundColor: interpolateColor(nacht.value, [0, 1], ['rgba(255,255,255,0.85)', 'rgba(255,255,255,0.10)']),
    borderColor: interpolateColor(nacht.value, [0, 1], ['rgba(43,45,66,0.14)', 'rgba(255,255,255,0.16)']),
    color: interpolateColor(nacht.value, [0, 1], [INKT, '#ffffff']),
  }));
  const smal = soort === 'tijd' ? { flexGrow: 0, flexShrink: 0, flexBasis: 126 }
    : soort === 'getal' ? { flexGrow: 0, flexShrink: 0, flexBasis: 84 }
    : { flex: 1, minWidth: 0 };
  return (
    <AnimatedInvoer
      value={waarde}
      placeholder={plaatshouder}
      placeholderTextColor="rgba(92,95,122,0.7)"
      onChangeText={opWijzig}
      inputMode={soort === 'getal' ? 'numeric' : 'text'}
      style={[
        { paddingVertical: 9, paddingHorizontal: soort === 'tijd' ? 6 : 12, borderRadius: 13, borderWidth: 1 },
        soort === 'tijd' || soort === 'getal'
          ? { fontFamily: 'Nunito_800ExtraBold', fontSize: 13, textAlign: 'center' }
          : { fontFamily: 'Baloo2_700Bold', fontSize: 16 },
        smal, vlak, stijl,
      ]}
    />
  );
}

const AnimatedInvoer = Animated.createAnimatedComponent(TextInput);

export function Chips({ children }: { children: React.ReactNode }) {
  return (
    <Glas radius={22} inhoudStijl={{ flexDirection: 'row', flexWrap: 'wrap', gap: 6, padding: 8 }}>
      {children}
    </Glas>
  );
}

// 'stil' is voor een antwoord dat geen keuze is om naar toe te trekken, zoals
// 'geen van deze': wel gekozen, maar niet oranje.
export function Chip({ label, aan, kleur, breed = true, stil = false, opTik }: {
  label: string; aan: boolean; kleur?: string; breed?: boolean; stil?: boolean; opTik: () => void;
}) {
  const nacht = useNacht();
  const vlak = useAnimatedStyle(() => ({
    backgroundColor: interpolateColor(nacht.value, [0, 1], ['rgba(255,255,255,0.55)', 'rgba(255,255,255,0.08)']),
    borderColor: interpolateColor(nacht.value, [0, 1], ['rgba(255,255,255,0.7)', 'rgba(255,255,255,0.14)']),
  }));
  const uit = useNachtKleur(ZACHT, 'rgba(255,255,255,0.6)');
  const donker = useNachtKleur(INKT, '#ffffff');
  const vast = aan
    ? stil
      ? { backgroundColor: 'rgba(43,45,66,0.14)', borderColor: 'transparent' }
      : { backgroundColor: kleur || ORANJE, borderColor: kleur || ORANJE }
    : null;
  return (
    <Pressable
      onPress={opTik}
      accessibilityRole="button"
      accessibilityState={{ selected: aan }}
      style={breed ? { flexGrow: 1, flexShrink: 1, flexBasis: 'auto' } : { flex: 1, minWidth: 0 }}
    >
      <Animated.View
        style={[
          { paddingVertical: 9, paddingHorizontal: breed ? 14 : 2, borderRadius: 15,
            borderWidth: 1, alignItems: 'center' },
          aan ? null : vlak, vast,
        ]}
      >
        {aan && !stil
          ? <Text style={[L.chip, { color: '#fff' }]} numberOfLines={1}>{label}</Text>
          : <Animated.Text style={[L.chip, aan ? donker : uit]} numberOfLines={1}>{label}</Animated.Text>}
      </Animated.View>
    </Pressable>
  );
}

export function Emojiknop({ waarde, maat = 42, opTik }: {
  waarde: string; maat?: number; opTik: () => void;
}) {
  const nacht = useNacht();
  const vlak = useAnimatedStyle(() => ({
    backgroundColor: interpolateColor(nacht.value, [0, 1], ['rgba(255,255,255,0.72)', 'rgba(255,255,255,0.10)']),
    borderColor: interpolateColor(nacht.value, [0, 1], ['rgba(255,255,255,0.9)', 'rgba(255,255,255,0.16)']),
  }));
  return (
    <Pressable onPress={opTik} accessibilityRole="button" accessibilityLabel="Icoon">
      <Animated.View
        style={[{ width: maat, height: maat, borderRadius: maat / 2.9, borderWidth: 1,
                  alignItems: 'center', justifyContent: 'center' }, vlak]}
      >
        <Text style={{ fontSize: maat * 0.53, lineHeight: maat * 0.62 }}>{waarde}</Text>
      </Animated.View>
    </Pressable>
  );
}

export function Minknop({ titel, opTik }: { titel: string; opTik: () => void }) {
  return (
    <Pressable
      onPress={opTik}
      accessibilityRole="button"
      accessibilityLabel={titel}
      style={{ width: 28, height: 28, borderRadius: 14, backgroundColor: '#E5484D',
               alignItems: 'center', justifyContent: 'center' }}
    >
      <Text style={{ color: '#fff', fontSize: 19, lineHeight: 21 }}>−</Text>
    </Pressable>
  );
}

export function Bewerkkaart({ children }: { children: React.ReactNode }) {
  return <Glas radius={26} style={{ marginTop: 18 }} inhoudStijl={{ overflow: 'hidden' }}>{children}</Glas>;
}

export function Streepje() {
  const nacht = useNacht();
  const stijl = useAnimatedStyle(() => ({
    backgroundColor: interpolateColor(nacht.value, [0, 1], ['rgba(43,45,66,0.08)', 'rgba(255,255,255,0.10)']),
  }));
  return <Animated.View style={[{ height: 1 }, stijl]} />;
}

export function Toevoegrij({ children, opTik }: { children: string; opTik: () => void }) {
  const kleur = useNachtKleur(ZACHT, 'rgba(255,255,255,0.6)');
  return (
    <View>
      <Streepje />
      <Pressable
        onPress={opTik}
        accessibilityRole="button"
        style={{ flexDirection: 'row', alignItems: 'center', gap: 10,
                 paddingVertical: 11, paddingHorizontal: 12 }}
      >
        <View style={{ width: 28, height: 28, borderRadius: 14, backgroundColor: '#34C759',
                       alignItems: 'center', justifyContent: 'center' }}>
          <Text style={{ color: '#fff', fontSize: 19, lineHeight: 21 }}>+</Text>
        </View>
        <Animated.Text style={[L.toevoeg, kleur]}>{children}</Animated.Text>
      </Pressable>
    </View>
  );
}

// Eén regel in een bewerkkaart: weghalen links, de rest opent het formulier.
export function Bewerkrij({ icoon, label, leeg, tijd, dagen, extra, wie, kleur, eerste,
                            tweeregels = false, wegTitel, opWeg, opOpenen }: {
  icoon: string; label: string; leeg: string;
  tijd?: string; dagen?: string; extra?: string; wie?: Persoon[]; kleur?: string;
  eerste: boolean; tweeregels?: boolean;
  wegTitel: string; opWeg: () => void; opOpenen: () => void;
}) {
  const meta = [tijd, dagen, extra].filter(Boolean) as string[];
  const heeftMeta = meta.length > 0 || (wie && wie.length > 0) || !!kleur;
  return (
    <View>
      {!eerste && <Streepje />}
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10,
                     paddingVertical: 8, paddingHorizontal: 12, minHeight: 58 }}>
        <Minknop titel={wegTitel} opTik={opWeg} />
        <Pressable
          onPress={opOpenen}
          accessibilityRole="button"
          style={{ flex: 1, minWidth: 0, flexDirection: 'row', alignItems: 'center',
                   gap: 10, flexWrap: tweeregels ? 'wrap' : 'nowrap',
                   paddingVertical: 6, rowGap: 3 }}
        >
          <Emojiknop waarde={icoon} opTik={opOpenen} />
          <Rijlabel leeg={!label} tweeregels={tweeregels}>{label || leeg}</Rijlabel>
          {heeftMeta && (
            <View
              style={{ flexDirection: 'row', alignItems: 'center', gap: 8,
                       ...(tweeregels
                         ? { flexGrow: 1, flexShrink: 1, flexBasis: '100%', paddingLeft: 52 }
                         : { flexShrink: 0 }) }}
            >
              {meta.map((t) => <Rijdagen key={t}>{t}</Rijdagen>)}
              {!!wie?.length && (
                <View style={{ flexDirection: 'row' }}>
                  {wie.map((p, i) => (
                    <View
                      key={p.id}
                      style={{ width: 24, height: 24, borderRadius: 12, marginLeft: i ? -7 : 0,
                               alignItems: 'center', justifyContent: 'center',
                               backgroundColor: zacht(p.kleur, 0.22),
                               boxShadow: '0px 0px 0px 2px rgba(255,255,255,0.85)' }}
                    >
                      <Text style={{ fontSize: 13, lineHeight: 16 }}>{p.emoji}</Text>
                    </View>
                  ))}
                </View>
              )}
              {!!kleur && <View style={{ width: 16, height: 16, borderRadius: 8, backgroundColor: kleur }} />}
            </View>
          )}
        </Pressable>
      </View>
    </View>
  );
}

function Rijlabel({ children, leeg, tweeregels }: {
  children: string; leeg: boolean; tweeregels: boolean;
}) {
  const kleur = useNachtKleur(leeg ? ZACHT : INKT, leeg ? 'rgba(255,255,255,0.6)' : '#ffffff');
  return (
    <Animated.Text
      numberOfLines={1}
      style={[L.rijlabel, kleur,
        tweeregels ? { flexGrow: 1, flexShrink: 1, flexBasis: 100 } : { flex: 1, minWidth: 0 }]}
    >
      {children}
    </Animated.Text>
  );
}

function Rijdagen({ children }: { children: string }) {
  const kleur = useNachtKleur(ZACHT, 'rgba(255,255,255,0.6)');
  return <Animated.Text style={[L.rijdagen, kleur]} numberOfLines={1}>{children}</Animated.Text>;
}
