// De twee soorten schermen die eroverheen komen: een blad dat vanaf de onderkant
// omhoog komt (het formulier, de assistent) en een vel dat het hele scherm vult
// (de bewerkschermen onder Instellingen).
import { Modal, Pressable, ScrollView, Text, View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Animated, { FadeIn, FadeOut, SlideInDown, SlideOutDown } from 'react-native-reanimated';
import { Glas } from './Glas';
import { L } from './letters';
import { Melding } from './velden';
import { KORT } from './beweging';

const ORANJE = '#F2994A';

export function Blad({ titel, melding, knop, opAf, opKnop, bezig, children }: {
  titel: string; melding?: string; knop?: string;
  opAf: () => void; opKnop?: () => void; bezig?: boolean; children: React.ReactNode;
}) {
  const rand = useSafeAreaInsets();
  return (
    <Modal transparent animationType="none" visible onRequestClose={opAf}>
      <Animated.View entering={FadeIn.duration(KORT.duration)} exiting={FadeOut.duration(KORT.duration)}
                     style={{ position: 'absolute', inset: 0, backgroundColor: 'rgba(22,15,6,0.34)' } as any}>
        <Pressable style={{ flex: 1 }} onPress={opAf} accessibilityLabel="Sluiten" />
      </Animated.View>
      <Animated.View
        entering={SlideInDown.duration(220)}
        exiting={SlideOutDown.duration(160)}
        style={{ position: 'absolute', left: 0, right: 0, bottom: 0, maxHeight: '84%' }}
      >
        <View style={{ maxWidth: 520, width: '100%', alignSelf: 'center' }}>
          <Glas
            radius={30}
            zwevend
            inhoudStijl={{ borderBottomLeftRadius: 0, borderBottomRightRadius: 0,
                           paddingTop: 10, paddingHorizontal: 18, paddingBottom: rand.bottom + 18 }}
          >
            <View style={{ width: 44, height: 5, borderRadius: 99, alignSelf: 'center',
                           marginBottom: 10, backgroundColor: 'rgba(43,45,66,0.22)' }} />
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
              <Tekstknop opTik={opAf} uitlijn="flex-start">Annuleer</Tekstknop>
              <Text style={[L.bladkop, { flexShrink: 1 }]} numberOfLines={1}>{titel}</Text>
              <View style={{ flex: 1 }} />
            </View>
            {!!melding && <View style={{ marginTop: 12 }}><Melding>{melding}</Melding></View>}
            <ScrollView style={{ marginTop: 4 }} contentContainerStyle={{ paddingBottom: 8, paddingHorizontal: 2 }}>
              {children}
            </ScrollView>
            {!!knop && (
              <Pressable
                onPress={opKnop}
                disabled={bezig}
                style={{ marginTop: 14, paddingVertical: 15, borderRadius: 20,
                         backgroundColor: ORANJE, alignItems: 'center', opacity: bezig ? 0.45 : 1 }}
              >
                <Text style={[L.grootknop, { color: '#fff', fontSize: 17 }]}>{knop}</Text>
              </Pressable>
            )}
          </Glas>
        </View>
      </Animated.View>
    </Modal>
  );
}

export function Vel({ titel, melding, opAf, opGereed, bezig, children }: {
  titel: string; melding?: string; opAf: () => void; opGereed: () => void;
  bezig?: boolean; children: React.ReactNode;
}) {
  const rand = useSafeAreaInsets();
  return (
    <Modal transparent={false} animationType="slide" visible onRequestClose={opAf}>
      <View style={{ flex: 1 }}>
        <LinearGradient colors={['#FFE3B8', '#FFD9CE', '#D9E8F5']}
                        style={{ position: 'absolute', inset: 0 } as any} />
        <ScrollView
          contentContainerStyle={{ paddingTop: rand.top + 18, paddingBottom: rand.bottom + 30 }}
          stickyHeaderIndices={[0]}
        >
          <View style={{ maxWidth: 496, width: '100%', alignSelf: 'center', paddingHorizontal: 22 }}>
            <Glas
              radius={28}
              zwevend
              style={{ marginBottom: 18 }}
              inhoudStijl={{ flexDirection: 'row', alignItems: 'center', gap: 10,
                             paddingVertical: 14, paddingHorizontal: 18 }}
            >
              <Tekstknop opTik={opAf} uitlijn="flex-start">Annuleer</Tekstknop>
              <Text style={[L.bladkop, { flexShrink: 1 }]} numberOfLines={1}>{titel}</Text>
              <Tekstknop opTik={opGereed} uitlijn="flex-end" dik>{bezig ? 'Bezig…' : 'Gereed'}</Tekstknop>
            </Glas>
          </View>
          <View style={{ maxWidth: 520, width: '100%', alignSelf: 'center', paddingHorizontal: 22 }}>
            {!!melding && <Melding>{melding}</Melding>}
            {children}
          </View>
        </ScrollView>
      </View>
    </Modal>
  );
}

function Tekstknop({ children, opTik, uitlijn, dik = false }: {
  children: string; opTik: () => void; uitlijn: 'flex-start' | 'flex-end'; dik?: boolean;
}) {
  return (
    <Pressable onPress={opTik} style={{ flex: 1, alignItems: uitlijn, paddingVertical: 4 }}>
      <Text style={[L.tekstknop, dik ? { fontFamily: 'Baloo2_800ExtraBold' } : null]}>{children}</Text>
    </Pressable>
  );
}
