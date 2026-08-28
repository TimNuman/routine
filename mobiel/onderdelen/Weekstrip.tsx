// De week als strip bovenaan Deze week: een pijl terug, zeven dagen, een pijl
// verder. Vandaag heeft een ringetje, de gekozen dag een oranje bol.
import { Pressable, Text, View } from 'react-native';
import Svg, { Path } from 'react-native-svg';
import { Glas } from './Glas';
import { L } from './letters';
import { DAGEN, DAGLETTERS, datumTekst, datumVan, weekVan } from './inhoud';

const ORANJE = '#F2994A';
const ZACHT = '#5C5F7A';

export function Weekstrip({ nu, verschuiving, gekozen, opKies, opSchuif }: {
  nu: Date; verschuiving: number; gekozen: Date;
  opKies: (d: Date) => void; opSchuif: (weken: number) => void;
}) {
  const dagen = weekVan(nu, verschuiving);
  const vandaag = datumVan(nu);
  const staat = datumVan(gekozen);
  return (
    <Glas
      radius={24}
      style={{ marginTop: 16 }}
      inhoudStijl={{ flexDirection: 'row', alignItems: 'stretch', paddingVertical: 10, paddingHorizontal: 4 }}
    >
      <Pijl richting={-1} titel="Vorige week" opTik={() => opSchuif(-1)} />
      {dagen.map((d) => {
        const sleutel = datumVan(d);
        const aan = sleutel === staat;
        return (
          <Pressable
            key={sleutel}
            onPress={() => opKies(d)}
            accessibilityLabel={datumTekst(d)}
            accessibilityState={{ selected: aan }}
            style={{ flex: 1, alignItems: 'center', gap: 8 }}
          >
            <Text style={[L.wletter, { color: ZACHT }]}>{DAGLETTERS[DAGEN[d.getDay()]]}</Text>
            <View
              style={{
                width: 38, height: 38, borderRadius: 19,
                alignItems: 'center', justifyContent: 'center',
                backgroundColor: aan ? ORANJE : 'transparent',
                boxShadow: !aan && sleutel === vandaag
                  ? 'inset 0px 0px 0px 2px rgba(242,153,74,0.5)' : undefined,
              }}
            >
              <Text style={[L.wdag, { color: aan ? '#fff' : '#2B2D42' }]}>{d.getDate()}</Text>
            </View>
          </Pressable>
        );
      })}
      <Pijl richting={1} titel="Volgende week" opTik={() => opSchuif(1)} />
    </Glas>
  );
}

function Pijl({ richting, titel, opTik }: { richting: number; titel: string; opTik: () => void }) {
  return (
    <Pressable
      onPress={opTik}
      accessibilityRole="button"
      accessibilityLabel={titel}
      style={{ width: 26, alignItems: 'center', justifyContent: 'center', opacity: 0.65,
               transform: [{ scaleX: richting < 0 ? -1 : 1 }] }}
    >
      <Svg width={9} height={15} viewBox="0 0 9 15" fill="none" stroke={ZACHT}
           strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
        <Path d="M1.5 1.5 7 7.5l-5.5 6" />
      </Svg>
    </Pressable>
  );
}
