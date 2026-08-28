// Het blad waar je een bericht in plakt. Vier standen: plakken, even lezen,
// een vraag terug, en de voorstellen om over te nemen.
import { useRef, useState } from 'react';
import { Pressable, Text, TextInput, View } from 'react-native';
import Animated, { interpolateColor, useAnimatedStyle } from 'react-native-reanimated';
import Svg, { Path } from 'react-native-svg';
import { Blad } from './Blad';
import { Dingblad } from './Dingblad';
import { Glas } from './Glas';
import { Chip, Chips, Formkop, Notitie, Streepje } from './velden';
import { L } from './letters';
import { useNacht, useNachtKleur } from './nacht';
import { DAGNAMEN, MAANDEN, datumVan, lijstVan, tekst, tijdTekst } from './inhoud';
import { alsRuw, dagenTekst, alsDatum, type Ruw } from './schoon';
import { eersteGroepnaam, zetDingNeer, type Ding } from './ding';
import { Uitleesfout, alBekend, schoonVoorstel, vraagAssistent, type Vraag, type Voorstel } from './assistent';
import type { Inhoud, Persoon } from './soorten';

const MAX_VRAGEN = 2;   // daarna raadt hij liever dan nog eens te vragen

type Stap = 'plakken' | 'bezig' | 'vraag' | 'voorstellen' | 'niets';

export function Assistentblad({ inhoud, opAf, opBewaar }: {
  inhoud: Inhoud;
  opAf: () => void;
  opBewaar: (ruw: Ruw) => Promise<string | null>;
}) {
  const [stap, zetStap] = useState<Stap>('plakken');
  const [melding, zetMelding] = useState('');
  const bericht = useRef('');
  const ronde = useRef(0);
  const vragen = useRef(0);
  const [vraag, zetVraag] = useState<Vraag | null>(null);
  const antwoord = useRef<Record<string, string[]>>({});
  const [items, zetItems] = useState<Voorstel[]>([]);
  const [keuze, zetKeuze] = useState<boolean[]>([]);
  const [bewerk, zetBewerk] = useState<number | null>(null);
  const [, herteken] = useState(0);
  const opnieuw = () => herteken((n) => n + 1);
  const werk = useRef<Ruw | null>(null);

  const lees = async () => {
    zetMelding('');
    zetStap('bezig');
    let uit: any;
    try {
      uit = await vraagAssistent({
        tekst: bericht.current,
        vandaag: datumVan(new Date()),
        ronde: ronde.current + 1,
        kinderen: inhoud.mensen.map((p) => ({ id: p.id, naam: p.naam, kenmerken: p.kenmerken })),
      });
    } catch (err: any) {
      zetStap('plakken');
      zetMelding(err instanceof Uitleesfout && err.vanServer
        ? err.message
        : `Het uitlezen lukte niet (${err?.message || 'onbekend'}).`);
      return;
    }
    ronde.current += 1;
    const soort = tekst(uit?.type);
    const opties = lijstVan<any>(uit?.opties).map((o) => tekst(o)).filter(Boolean);
    if (soort === 'vraag' && opties.length && vragen.current < MAX_VRAGEN) {
      vragen.current += 1;
      antwoord.current = {};
      zetVraag({
        sleutel: tekst(uit.sleutel, 'kenmerk'),
        vraag: tekst(uit.vraag, 'Waar hoort dit bij?'),
        opties,
        meerkeuze: Boolean(uit.meerkeuze),
      });
      zetStap('vraag');
      return;
    }
    const gevonden = lijstVan<any>(uit?.items)
      .map((r) => schoonVoorstel(r, inhoud.mensen))
      .filter(Boolean) as Voorstel[];
    zetItems(gevonden);
    zetKeuze(gevonden.map(() => true));
    zetStap(gevonden.length ? 'voorstellen' : 'niets');
  };

  // Het antwoord op een vraag is een kenmerk van het kind en gaat meteen mee de
  // database in — dan hoeft het de volgende keer niet nog eens gevraagd.
  const bewaarAntwoorden = async (): Promise<boolean> => {
    if (!vraag) return true;
    const ruw = alsRuw(inhoud);
    let iets = false;
    lijstVan<any>(ruw.mensen).forEach((persoon) => {
      const gekozen = lijstVan<string>(antwoord.current[persoon.id]).map((x) => tekst(x)).filter(Boolean);
      persoon.kenmerken = { ...(persoon.kenmerken || {}) };
      if (gekozen.length) { persoon.kenmerken[vraag.sleutel] = gekozen.join(', '); iets = true; }
      else delete persoon.kenmerken[vraag.sleutel];
    });
    if (!iets) return true;
    const fout = await opBewaar(ruw);
    if (fout) { zetMelding(fout); return false; }
    return true;
  };

  const verder = async () => {
    if (stap === 'niets') { zetStap('plakken'); return; }
    if (stap === 'plakken') {
      if (!tekst(bericht.current)) return zetMelding('Plak eerst een bericht.');
      return lees();
    }
    if (stap === 'vraag') {
      if (!(await bewaarAntwoorden())) return;
      return lees();
    }
    const gekozen = items.filter((_, i) => keuze[i]);
    if (!gekozen.length) return zetMelding('Kies er minstens één.');
    const ruw = alsRuw(inhoud);
    gekozen.forEach((item) => { if (!alBekend(ruw, item)) zetDingNeer(ruw, item, '', null); });
    const fout = await opBewaar(ruw);
    if (fout) zetMelding(fout); else opAf();
  };

  const knop = stap === 'bezig' ? 'Even lezen…'
    : stap === 'niets' ? 'Opnieuw proberen'
    : stap === 'vraag' ? 'Ga verder'
    : stap === 'voorstellen'
      ? (keuze.filter(Boolean).length === 1
        ? 'Zet er 1 in de app'
        : `Zet er ${keuze.filter(Boolean).length} in de app`)
      : 'Lees uit';

  const titel = stap === 'bezig' ? 'Even lezen'
    : stap === 'niets' ? 'Niets gevonden'
    : stap === 'vraag' ? 'Even iets vragen'
    : stap === 'voorstellen' ? 'Dit haalde ik eruit'
    : 'Typ of plak iets';

  return (
    <>
      <Blad
        titel={titel}
        melding={melding}
        knop={knop}
        bezig={stap === 'bezig' || (stap === 'voorstellen' && !keuze.some(Boolean))}
        opAf={opAf}
        opKnop={verder}
      >
        {stap === 'plakken' && (
          <>
            <Formkop eerste>De tekst</Formkop>
            <Plakvak waarde={bericht.current} opWijzig={(v) => { bericht.current = v; }} />
            <Notitie>
              Wat elke week terugkomt gaat naar het weekritme, wat één dag geldt naar Eenmalig.
              Er wordt ook meegedacht: bij een verjaardag hoort een cadeautje op tijd.
              Alleen wat je hier typt gaat mee, plus de voornamen van de kinderen.
            </Notitie>
          </>
        )}

        {stap === 'bezig' && <Bezig>Even kijken wat erin staat…</Bezig>}

        {stap === 'niets' && (
          <Bezig>
            Hier kon ik niets uithalen dat in de app hoort. Probeer het wat concreter, of plak er meer bij.
          </Bezig>
        )}

        {stap === 'vraag' && !!vraag && (
          <>
            <Formkop eerste>Vraag</Formkop>
            <Notitie>{vraag.vraag}</Notitie>
            {inhoud.mensen.map((persoon) => (
              <Vraagkind
                key={persoon.id}
                persoon={persoon}
                vraag={vraag}
                gekozen={lijstVan<string>(antwoord.current[persoon.id])}
                opKies={(optie) => {
                  const nu = lijstVan<string>(antwoord.current[persoon.id]);
                  const i = nu.indexOf(optie);
                  if (i >= 0) nu.splice(i, 1);
                  else if (vraag.meerkeuze) nu.push(optie);
                  else nu.splice(0, nu.length, optie);
                  antwoord.current[persoon.id] = nu;
                  opnieuw();
                }}
                opGeen={() => { antwoord.current[persoon.id] = []; opnieuw(); }}
              />
            ))}
            <Notitie>Wat je kiest blijft bij het kind staan, dus dit hoeft maar één keer.</Notitie>
          </>
        )}

        {stap === 'voorstellen' && (
          <>
            <Formkop eerste>Voorstellen</Formkop>
            <Glas radius={22} style={{ marginTop: 4 }} inhoudStijl={{ overflow: 'hidden' }}>
              {items.map((item, i) => (
                <View key={i}>
                  {i > 0 && <Streepje />}
                  <Vondst
                    item={item}
                    aan={Boolean(keuze[i])}
                    mensen={inhoud.mensen}
                    opVink={() => zetKeuze(keuze.map((k, j) => (j === i ? !k : k)))}
                    opOpen={() => { werk.current = alsRuw(inhoud); zetBewerk(i); }}
                  />
                </View>
              ))}
            </Glas>
            <Notitie>
              Tik het vinkje weg wat je niet wilt, en de regel zelf om hem aan te passen.
              Wat aangevinkt blijft staan gaat in één keer de app in.
            </Notitie>
          </>
        )}
      </Blad>

      {/* Een voorstel is nog niets; je kunt het hier nog helemaal omgooien —
          ook van eenmalig naar herhalend, of van agenda naar taak. */}
      {bewerk !== null && (
        <Dingblad
          titel={items[bewerk].tekst || 'Voorstel'}
          ding={{
            ...items[bewerk],
            groep: tekst(items[bewerk].groep) || eersteGroepnaam(werk.current!, items[bewerk].ritme),
          }}
          plek={null}
          bron={() => werk.current!}
          mensen={inhoud.mensen}
          opAf={() => zetBewerk(null)}
          opBewaar={(g: Ding) => {
            const bron = tekst(items[bewerk].bron);
            zetItems(items.map((x, j) => (j === bewerk ? { ...g, bron } : x)));
            zetKeuze(keuze.map((k, j) => (j === bewerk ? true : k)));
            zetBewerk(null);
          }}
        />
      )}
    </>
  );
}

function Plakvak({ waarde, opWijzig }: { waarde: string; opWijzig: (v: string) => void }) {
  const nacht = useNacht();
  const vlak = useAnimatedStyle(() => ({
    backgroundColor: interpolateColor(nacht.value, [0, 1], ['rgba(255,255,255,0.85)', 'rgba(255,255,255,0.10)']),
    borderColor: interpolateColor(nacht.value, [0, 1], ['rgba(43,45,66,0.14)', 'rgba(255,255,255,0.16)']),
    color: interpolateColor(nacht.value, [0, 1], ['#2B2D42', '#ffffff']),
  }));
  return (
    <AnimatedInvoer
      multiline
      defaultValue={waarde}
      onChangeText={opWijzig}
      placeholder={'Plak een mail of appje, of typ het gewoon:\n\niedere dinsdag om 18:00 tennis Emma'}
      placeholderTextColor="rgba(92,95,122,0.7)"
      style={[{ minHeight: 148, padding: 12, borderRadius: 16, borderWidth: 1,
                fontFamily: 'Nunito_700Bold', fontSize: 14, lineHeight: 20 }, vlak]}
    />
  );
}

const AnimatedInvoer = Animated.createAnimatedComponent(TextInput);

function Bezig({ children }: { children: string }) {
  const kleur = useNachtKleur('#5C5F7A', 'rgba(255,255,255,0.6)');
  return (
    <Animated.Text style={[L.bezig, kleur]}>{children}</Animated.Text>
  );
}

function Vraagkind({ persoon, vraag, gekozen, opKies, opGeen }: {
  persoon: Persoon; vraag: Vraag; gekozen: string[];
  opKies: (optie: string) => void; opGeen: () => void;
}) {
  const kleur = useNachtKleur('#2B2D42', '#ffffff');
  return (
    <View style={{ paddingTop: 10, paddingBottom: 2 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8,
                     paddingHorizontal: 6, paddingBottom: 7 }}>
        <Text style={{ fontSize: 19, lineHeight: 23 }}>{persoon.emoji}</Text>
        <Animated.Text style={[L.vraagnaam, kleur]}>{persoon.naam}</Animated.Text>
      </View>
      <Chips>
        {vraag.opties.map((optie) => (
          <Chip
            key={optie}
            label={optie}
            aan={gekozen.includes(optie)}
            kleur={persoon.kleur}
            opTik={() => opKies(optie)}
          />
        ))}
        {/* 'Geen van deze' is een antwoord, geen keuze om naar toe te trekken. */}
        <Chip label="geen van deze" aan={!gekozen.length} stil opTik={opGeen} />
      </Chips>
    </View>
  );
}

function Vondst({ item, aan, mensen, opVink, opOpen }: {
  item: Voorstel; aan: boolean; mensen: Persoon[];
  opVink: () => void; opOpen: () => void;
}) {
  const nacht = useNacht();
  const vak = useAnimatedStyle(() => ({
    backgroundColor: aan ? '#F2994A'
      : interpolateColor(nacht.value, [0, 1], ['rgba(255,255,255,0.72)', 'rgba(255,255,255,0.10)']),
    borderColor: aan ? '#F2994A'
      : interpolateColor(nacht.value, [0, 1], ['rgba(255,255,255,0.9)', 'rgba(255,255,255,0.16)']),
  }));
  const wanneer = item.wekelijks ? (dagenTekst(item.dagen) || 'elke dag') : langeDatum(item.datum);
  const namen = item.wie.map((id) => mensen.find((p) => p.id === id)).filter(Boolean).map((p) => p!.naam);
  const soort = item.taak
    ? '✅ ' + (item.ritme === 'nacht' ? '🌙 ' : '☀️ ') + tekst(item.groep, 'ritme')
    : item.wekelijks ? 'elke week' : '';
  const meta = [wanneer, tijdTekst(item), namen.length ? namen.join(' en ') : 'iedereen', soort]
    .filter(Boolean).join(' · ');

  return (
    <View style={{ flexDirection: 'row', alignItems: 'flex-start' }}>
      <Pressable
        onPress={opVink}
        accessibilityRole="checkbox"
        accessibilityState={{ checked: aan }}
        accessibilityLabel={aan ? 'Niet overnemen' : 'Wel overnemen'}
        style={{ paddingTop: 12, paddingBottom: 12, paddingLeft: 13, paddingRight: 4 }}
      >
        <Animated.View
          style={[{ width: 23, height: 23, borderRadius: 8, borderWidth: 1.5, marginTop: 2,
                    alignItems: 'center', justifyContent: 'center' }, vak]}
        >
          {aan && <Text style={{ color: '#fff', fontSize: 13, lineHeight: 16 }}>✓</Text>}
        </Animated.View>
      </Pressable>
      <Pressable
        onPress={opOpen}
        accessibilityRole="button"
        style={{ flex: 1, minWidth: 0, flexDirection: 'row', alignItems: 'flex-start', gap: 11,
                 paddingVertical: 12, paddingRight: 13, paddingLeft: 9 }}
      >
        <Text style={{ fontSize: 24, lineHeight: 28 }}>{item.icoon}</Text>
        <View style={{ flex: 1, minWidth: 0 }}>
          <Vondstnaam>{item.tekst}</Vondstnaam>
          {!!meta && <Vondstmeta>{meta}</Vondstmeta>}
          {!!item.bron && <Vondstbron>{`„${item.bron}”`}</Vondstbron>}
        </View>
        <View style={{ alignSelf: 'center', opacity: 0.5 }}>
          <Svg width={9} height={15} viewBox="0 0 9 15" fill="none" stroke="#5C5F7A"
               strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
            <Path d="M1.5 1.5 7 7.5l-5.5 6" />
          </Svg>
        </View>
      </Pressable>
    </View>
  );
}

function langeDatum(waarde: string): string {
  const d = alsDatum(waarde);
  return d ? `${DAGNAMEN[d.getDay()]} ${d.getDate()} ${MAANDEN[d.getMonth()]}` : '';
}

function Vondstnaam({ children }: { children: string }) {
  const kleur = useNachtKleur('#2B2D42', '#ffffff');
  return <Animated.Text style={[L.vondstnaam, kleur]}>{children}</Animated.Text>;
}

function Vondstmeta({ children }: { children: string }) {
  const kleur = useNachtKleur('#5C5F7A', 'rgba(255,255,255,0.6)');
  return <Animated.Text style={[L.vondstmeta, kleur]}>{children}</Animated.Text>;
}

function Vondstbron({ children }: { children: string }) {
  const kleur = useNachtKleur('#5C5F7A', 'rgba(255,255,255,0.6)');
  return <Animated.Text style={[L.vondstbron, kleur]}>{children}</Animated.Text>;
}
