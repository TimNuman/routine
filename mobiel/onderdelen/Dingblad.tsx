// Het blad dat één ding bewerkt — waar je het ook opent vandaan. De twee
// schakelaars bepalen wat er verder te kiezen valt.
import { createElement, useRef, useState } from 'react';
import { Platform, Pressable, Text, View } from 'react-native';
import { Blad } from './Blad';
import { Emojikiezer } from './Emojikiezer';
import { Chip, Chips, Emojiknop, Formkop, Notitie, Veld } from './velden';
import { L } from './letters';
import { WEEKDAGEN, lijstVan, tekst, uurUitTijd } from './inhoud';
import { eersteGroepnaam, verplaatsDing, type Ding, type Plek } from './ding';
import type { Ruw } from './schoon';
import type { Persoon, Ritme } from './soorten';

export function Dingblad({ titel, ding, plek, bron, mensen, bezig, opAf, opBewaar, opWeg }: {
  titel: string; ding: Ding; plek: Plek | null; bron: () => Ruw; mensen: Persoon[];
  bezig?: boolean;
  opAf: () => void;
  opBewaar: (g: Ding) => void;
  opWeg?: () => void;
}) {
  // Zoals in de webversie: de gegevens zijn één blok dat je aanpast, en het
  // scherm tekent zichzelf opnieuw. Zo springt de cursor niet weg bij het typen.
  const g = useRef<Ding>({ ...ding, dagen: [...ding.dagen], wie: [...ding.wie] });
  const [, herteken] = useState(0);
  const opnieuw = () => herteken((n) => n + 1);
  const [melding, zetMelding] = useState('');
  const [kiezer, zetKiezer] = useState(false);

  const avondVanaf = Number(bron().avondVanaf) || 15;

  const bewaar = () => {
    const fout = verplaatsDing(bron(), plek, g.current);
    if (fout) { zetMelding(fout); return; }
    opBewaar(g.current);
  };

  return (
    <>
      <Blad titel={titel} melding={melding} knop="Bewaar" bezig={bezig} opAf={opAf} opKnop={bewaar}>
        <Formkop eerste>Icoon en naam</Formkop>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
          <Emojiknop waarde={g.current.icoon} maat={52} opTik={() => zetKiezer(true)} />
          <Veld
            waarde={g.current.tekst}
            plaatshouder="Wat is er"
            opWijzig={(v) => { g.current.tekst = v; }}
          />
        </View>

        <Formkop>Hoe vaak</Formkop>
        <Chips>
          {([[true, '🔁 herhalen'], [false, '📌 één keer']] as const).map(([waarde, label]) => (
            <Chip
              key={label}
              label={label}
              aan={Boolean(g.current.wekelijks) === waarde}
              opTik={() => { g.current.wekelijks = waarde; opnieuw(); }}
            />
          ))}
        </Chips>

        {g.current.wekelijks ? (
          <>
            <Formkop>Op welke dagen</Formkop>
            <Chips>
              {WEEKDAGEN.map((dag) => (
                <Chip
                  key={dag}
                  label={dag}
                  breed={false}
                  aan={g.current.dagen.includes(dag)}
                  opTik={() => {
                    const i = g.current.dagen.indexOf(dag);
                    if (i >= 0) g.current.dagen.splice(i, 1); else g.current.dagen.push(dag);
                    opnieuw();
                  }}
                />
              ))}
            </Chips>
            {!g.current.dagen.length && <Notitie>Geen dag gekozen betekent: elke dag.</Notitie>}
          </>
        ) : (
          <>
            <Formkop>Op welke dag</Formkop>
            <Datumveld waarde={g.current.datum} opWijzig={(v) => { g.current.datum = v; opnieuw(); }} />
          </>
        )}

        <Formkop>Wat voor iets</Formkop>
        <Chips>
          {([[true, '✅ taak'], [false, '🗓️ agenda']] as const).map(([waarde, label]) => (
            <Chip
              key={label}
              label={label}
              aan={Boolean(g.current.taak) === waarde}
              opTik={() => {
                g.current.taak = waarde;
                if (waarde && !tekst(g.current.groep)) {
                  g.current.groep = eersteGroepnaam(bron(), g.current.ritme);
                }
                opnieuw();
              }}
            />
          ))}
        </Chips>

        {g.current.taak ? (
          <>
            <Formkop>In welk ritme</Formkop>
            <Chips>
              {([['dag', '☀️ ochtend'], ['nacht', '🌙 avond']] as const).map(([waarde, label]) => (
                <Chip
                  key={waarde}
                  label={label}
                  aan={g.current.ritme === waarde}
                  opTik={() => {
                    g.current.ritme = waarde as Ritme;
                    g.current.groep = eersteGroepnaam(bron(), waarde as Ritme);
                    opnieuw();
                  }}
                />
              ))}
            </Chips>

            <Formkop>Bij welk onderdeel</Formkop>
            <Chips>
              {lijstVan<any>(bron()[g.current.ritme]).filter((x) => tekst(x.groep)).map((x, i) => (
                <Chip
                  key={x.groep + i}
                  label={x.groep}
                  aan={g.current.groep === x.groep}
                  opTik={() => { g.current.groep = x.groep; opnieuw(); }}
                />
              ))}
            </Chips>
            <Notitie>
              Een taak wordt een kaartje tussen de stappen, met een rondje per kind om af te vinken.
              Een taak heeft geen eigen tijd — die hoort bij het onderdeel waar hij in staat.
            </Notitie>
          </>
        ) : (
          <>
            <Formkop>Hoe laat</Formkop>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
              <Veld soort="tijd" waarde={g.current.tijd} plaatshouder="van"
                    opWijzig={(v) => { g.current.tijd = v; opnieuw(); }} />
              <Text style={[L.rijdagen, { color: '#5C5F7A' }]}>–</Text>
              <Veld soort="tijd" waarde={g.current.tot} plaatshouder="tot"
                    opWijzig={(v) => { g.current.tot = v; opnieuw(); }} />
            </View>
            <Notitie>{tijduitleg(g.current, avondVanaf)}</Notitie>
          </>
        )}

        <Formkop>Voor wie</Formkop>
        <Chips>
          <Chip label="iedereen" aan={!g.current.wie.length}
                opTik={() => { g.current.wie = []; opnieuw(); }} />
          {mensen.map((persoon) => (
            <Chip
              key={persoon.id}
              label={`${persoon.emoji} ${persoon.naam || 'kind'}`}
              aan={g.current.wie.includes(persoon.id)}
              kleur={persoon.kleur}
              opTik={() => {
                const i = g.current.wie.indexOf(persoon.id);
                if (i >= 0) g.current.wie.splice(i, 1); else g.current.wie.push(persoon.id);
                opnieuw();
              }}
            />
          ))}
        </Chips>

        {!!opWeg && (
          <Pressable
            onPress={opWeg}
            accessibilityRole="button"
            style={{ marginTop: 18, paddingVertical: 13, borderRadius: 18, alignItems: 'center',
                     borderWidth: 1, borderColor: 'rgba(229,72,77,0.35)',
                     backgroundColor: 'rgba(229,72,77,0.10)' }}
          >
            <Text style={[L.grootknop, { color: '#E5484D', fontSize: 14.5 }]}>Verwijderen</Text>
          </Pressable>
        )}
      </Blad>

      {kiezer && (
        <Emojikiezer
          titel="Kies een icoon"
          huidig={g.current.icoon}
          opAf={() => zetKiezer(false)}
          opKlaar={(teken) => { g.current.icoon = teken; zetKiezer(false); opnieuw(); }}
        />
      )}
    </>
  );
}

// De tijd bepaalt of iets bij Overdag of bij Vanavond komt te staan; dat is
// beter uit te leggen dan het te laten zien nadat je hebt bewaard.
function tijduitleg(g: Ding, vanaf: number): string {
  const uur = uurUitTijd(g.tijd);
  if (uur === null) {
    return g.avond
      ? `Zonder tijd blijft dit bij Vanavond staan, zoals het was. Vul een tijd in vanaf ${vanaf}:00 om dat zo te houden.`
      : `Zonder tijd komt dit bij Overdag te staan. Vanaf ${vanaf}:00 gaat het naar Vanavond.`;
  }
  return uur >= vanaf
    ? `Komt bij Vanavond te staan — dat begint om ${vanaf}:00.`
    : `Komt bij Overdag te staan; vanaf ${vanaf}:00 zou het Vanavond zijn.`;
}

// Op web is er een echte datumkiezer; op een telefoon voorlopig een veld.
function Datumveld({ waarde, opWijzig }: { waarde: string; opWijzig: (v: string) => void }) {
  if (Platform.OS === 'web') {
    return createElement('input', {
      type: 'date',
      value: waarde,
      onChange: (e: any) => opWijzig(e.target.value),
      style: {
        width: '100%', boxSizing: 'border-box',
        font: '800 14px Nunito_800ExtraBold, sans-serif',
        color: '#2B2D42', padding: '9px 12px', borderRadius: 13,
        border: '1px solid rgba(43,45,66,0.14)', background: 'rgba(255,255,255,0.85)',
      },
    });
  }
  return <Veld waarde={waarde} plaatshouder="jjjj-mm-dd" opWijzig={opWijzig} />;
}
