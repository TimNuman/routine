import { Text, View } from 'react-native';
import Animated, { interpolateColor, useAnimatedStyle } from 'react-native-reanimated';
import { Glas } from './Glas';
import { useNacht, useNachtKleur } from './nacht';
import { L } from './letters';
import { tijdTekst, type Blok } from './inhoud';
import type { Agendaitem, Persoon } from './soorten';

// Het weekritme naast de stappen: wat er die dag verder nog is. Een eenmalig
// ding krijgt een oranje randje links, zodat het opvalt tussen het vaste.
// In de kolom ernaast staan ze gewoon onder elkaar: de eerste ligt gelijk met
// de kaartjes, wat erna komt krijgt er ruimte boven. De streep boven Morgen is
// daar niet nodig, die scheidt op een telefoon de stappen van wat er morgen is.
export function Agenda({ blok, mensen, zij = false, eerste = false }: {
  blok: Blok; mensen: Persoon[]; zij?: boolean; eerste?: boolean;
}) {
  if (!blok.items.length) return null;
  const later = !!blok.later && !zij;
  return (
    <View style={{ marginTop: zij ? (eerste ? 0 : 22) : blok.later ? 26 : 0, paddingTop: later ? 22 : 0 }}>
      {later && <Stippellijn />}
      <Blokkop marge={zij ? 0 : 22}>{blok.kop}</Blokkop>
      <Glas radius={26} inhoudStijl={{ overflow: 'hidden' }}>
        {blok.items.map((item, i) => (
          <View key={item.tekst + i}>
            {i > 0 && <Streep />}
            <Rij item={item} mensen={mensen} />
          </View>
        ))}
      </Glas>
    </View>
  );
}

function Rij({ item, mensen }: { item: Agendaitem; mensen: Persoon[] }) {
  const nacht = useNacht();
  const gekozen = item.wie.map((id) => mensen.find((p) => p.id === id)).filter(Boolean) as Persoon[];
  const wanneer = tijdTekst(item);

  const bijzonder = useAnimatedStyle(() => ({
    backgroundColor: interpolateColor(nacht.value, [0, 1], ['rgba(242,153,74,0.13)', 'rgba(242,153,74,0.16)']),
  }));

  return (
    <Animated.View
      style={[
        { flexDirection: 'row', alignItems: 'flex-start', gap: 12, paddingVertical: 12,
          paddingHorizontal: 16, minHeight: 54 },
        item.bijzonder ? bijzonder : null,
        item.bijzonder ? { borderLeftWidth: 3, borderLeftColor: '#F2994A' } : null,
      ]}
    >
      <Text style={{ fontSize: 24, width: 30, textAlign: 'center', lineHeight: 29 }}>{item.icoon}</Text>
      <View style={{ flex: 1, minWidth: 0 }}>
        <Naam>{item.tekst}</Naam>
        {(gekozen.length > 0 && gekozen.length < mensen.length) || !!wanneer ? (
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 7, flexWrap: 'wrap', marginTop: 5 }}>
            {gekozen.length > 0 && gekozen.length < mensen.length
              && gekozen.map((p) => <Merk key={p.id} persoon={p} />)}
            {!!wanneer && <Tijd>{wanneer}</Tijd>}
          </View>
        ) : null}
      </View>
    </Animated.View>
  );
}

// Wie het betreft, als gekleurd label — alleen als het niet voor iedereen is.
function Merk({ persoon }: { persoon: Persoon }) {
  return (
    <View
      style={{ flexDirection: 'row', alignItems: 'center', gap: 4, paddingLeft: 3, paddingRight: 9,
               paddingVertical: 3, borderRadius: 999, backgroundColor: persoon.kleur }}
    >
      <View
        style={{ width: 19, height: 19, borderRadius: 10, backgroundColor: 'rgba(255,255,255,0.28)',
                 alignItems: 'center', justifyContent: 'center' }}
      >
        <Text style={{ fontSize: 11 }}>{persoon.emoji}</Text>
      </View>
      <Text style={[L.merk, { color: '#fff' }]}>{persoon.naam}</Text>
    </View>
  );
}

function Blokkop({ children, marge }: { children: string; marge: number }) {
  const kleur = useNachtKleur('#2B2D42', '#ffffff');
  return (
    <Animated.Text
      style={[L.blokkop, { marginTop: marge, paddingHorizontal: 16, paddingBottom: 9 }, kleur]}
    >
      {children}
    </Animated.Text>
  );
}

function Naam({ children }: { children: string }) {
  const kleur = useNachtKleur('#2B2D42', '#ffffff');
  return <Animated.Text style={[L.agendanaam, kleur]}>{children}</Animated.Text>;
}

function Tijd({ children }: { children: string }) {
  const kleur = useNachtKleur('#5C5F7A', 'rgba(255,255,255,0.6)');
  return <Animated.Text style={[L.agendatijd, kleur]}>{children}</Animated.Text>;
}

function Streep() {
  const nacht = useNacht();
  const stijl = useAnimatedStyle(() => ({
    backgroundColor: interpolateColor(nacht.value, [0, 1], ['rgba(43,45,66,0.08)', 'rgba(255,255,255,0.10)']),
  }));
  return <Animated.View style={[{ height: 1, marginHorizontal: 16 }, stijl]} />;
}

// Morgen zakt op een telefoon onder de stappen, met een streep ertussen.
function Stippellijn() {
  const nacht = useNacht();
  const stijl = useAnimatedStyle(() => ({
    borderTopColor: interpolateColor(nacht.value, [0, 1], ['rgba(43,45,66,0.12)', 'rgba(255,255,255,0.14)']),
  }));
  return (
    <Animated.View
      style={[{ position: 'absolute', left: 0, right: 0, top: 0, borderTopWidth: 1, borderStyle: 'dashed' }, stijl]}
    />
  );
}
