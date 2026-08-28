// Een brede knop op glas, zoals 'Iets bijzonders toevoegen' onder de agenda.
import { Pressable, Text, View } from 'react-native';
import Animated from 'react-native-reanimated';
import { Glas } from './Glas';
import { useNachtKleur } from './nacht';
import { L } from './letters';

export function Kaartknop({ teken, plus = false, children, opTik }: {
  teken?: string; plus?: boolean; children: string; opTik: () => void;
}) {
  return (
    <Glas radius={22} style={{ marginTop: 14 }}>
      <Pressable
        onPress={opTik}
        accessibilityRole="button"
        style={{ flexDirection: 'row', alignItems: 'center', gap: 10,
                 paddingVertical: 15, paddingHorizontal: 16 }}
      >
        {plus ? (
          <View style={{ width: 28, height: 28, borderRadius: 14, backgroundColor: '#34C759',
                         alignItems: 'center', justifyContent: 'center' }}>
            <Text style={{ color: '#fff', fontSize: 19, lineHeight: 22 }}>+</Text>
          </View>
        ) : (
          <Text style={{ width: 28, textAlign: 'center', fontSize: 20, lineHeight: 23 }}>{teken}</Text>
        )}
        <Opschrift>{children}</Opschrift>
      </Pressable>
    </Glas>
  );
}

function Opschrift({ children }: { children: string }) {
  const kleur = useNachtKleur('#5C5F7A', 'rgba(255,255,255,0.6)');
  return <Animated.Text style={[L.kaartknop, kleur]}>{children}</Animated.Text>;
}
