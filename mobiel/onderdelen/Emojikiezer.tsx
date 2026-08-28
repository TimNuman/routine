// De emojikiezer: een voorbeeld, de groepen als chips en een raster om uit te
// kiezen. Hij opent op de groep waar het huidige teken in staat.
import { useState } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import Animated, { interpolateColor, useAnimatedStyle } from 'react-native-reanimated';
import { Blad } from './Blad';
import { Chip } from './velden';
import { EMOJI } from './emoji';
import { useNacht } from './nacht';

const GROEPEN = Object.keys(EMOJI);

function groepVan(teken: string): string {
  return GROEPEN.find((naam) => EMOJI[naam].includes(teken)) || GROEPEN[0];
}

export function Emojikiezer({ titel, huidig, opAf, opKlaar }: {
  titel: string; huidig: string; opAf: () => void; opKlaar: (teken: string) => void;
}) {
  const [waarde, zetWaarde] = useState(huidig || '⭐');
  const [groep, zetGroep] = useState(() => groepVan(huidig || '⭐'));
  const nacht = useNacht();
  const vlak = useAnimatedStyle(() => ({
    backgroundColor: interpolateColor(nacht.value, [0, 1], ['rgba(255,255,255,0.72)', 'rgba(255,255,255,0.10)']),
    borderColor: interpolateColor(nacht.value, [0, 1], ['rgba(255,255,255,0.9)', 'rgba(255,255,255,0.16)']),
  }));

  return (
    <Blad titel={titel} knop="Gereed" opAf={opAf} opKnop={() => opKlaar(waarde)}>
      <Animated.View
        style={[{ width: 78, height: 78, borderRadius: 39, borderWidth: 1, alignSelf: 'center',
                  marginTop: 12, marginBottom: 14, alignItems: 'center', justifyContent: 'center' }, vlak]}
      >
        <Text style={{ fontSize: 40, lineHeight: 47 }}>{waarde}</Text>
      </Animated.View>

      <ScrollView horizontal showsHorizontalScrollIndicator={false}
                  contentContainerStyle={{ gap: 6, paddingBottom: 12 }}>
        {GROEPEN.map((naam) => (
          <View key={naam}>
            <Chip label={naam} aan={naam === groep} breed opTik={() => zetGroep(naam)} />
          </View>
        ))}
      </ScrollView>

      <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginHorizontal: -4 }}>
        {(EMOJI[groep] || []).map((teken, i) => (
          <View key={teken + i} style={{ width: '16.666%', padding: 4 }}>
            <Pressable onPress={() => zetWaarde(teken)} accessibilityRole="button" accessibilityLabel={teken}>
              <Animated.View
                style={[{ aspectRatio: 1, borderRadius: 999, borderWidth: 1,
                          alignItems: 'center', justifyContent: 'center',
                          boxShadow: teken === waarde ? '0px 0px 0px 2.5px #F2994A' : undefined }, vlak]}
              >
                <Text style={{ fontSize: 25, lineHeight: 30 }}>{teken}</Text>
              </Animated.View>
            </Pressable>
          </View>
        ))}
      </View>
    </Blad>
  );
}
