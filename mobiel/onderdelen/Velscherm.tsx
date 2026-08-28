// De zes bewerkschermen onder Instellingen. Ze werken allemaal op één losse
// kopie van de inhoud — het concept — en pas bij Gereed gaat die de database in.
import { useMemo, useRef, useState } from 'react';
import { Text, View } from 'react-native';
import Animated from 'react-native-reanimated';
import { Vel } from './Blad';
import { Dingblad } from './Dingblad';
import { Kindblad, kindGegevens, type Kindgegevens } from './Kindblad';
import { Glas } from './Glas';
import { Kaartknop } from './Kaartknop';
import { L } from './letters';
import { useNachtKleur } from './nacht';
import { Segment } from './Segment';
import { Bewerkkaart, Bewerkrij, Minknop, Notitie, Streepje, Toevoegrij, Veld } from './velden';
import { KLEUREN, aantalStappen, kenmerkenVan, lijstVan, tekst, tijdTekst } from './inhoud';
import { alsRuw, dagenTekst, kortDatum, naAvond, nieuwId, opgeschoond, type Ruw } from './schoon';
import { dingVan, haalDingWeg, type Ding, type Plek } from './ding';
import type { Inhoud, Persoon, Ritme } from './soorten';

export type Velsoort = 'kinderen' | 'dag' | 'nacht' | 'overzicht' | 'eenmalig' | 'algemeen';

const TITELS: Record<Velsoort, string> = {
  kinderen: 'Kinderen',
  dag: 'Ochtendritme',
  nacht: 'Avondritme',
  overzicht: 'Weekritme',
  eenmalig: 'Eenmalig',
  algemeen: 'Naam en tijden',
};

export function Velscherm({ soort, inhoud, opAf, opBewaar }: {
  soort: Velsoort; inhoud: Inhoud;
  opAf: () => void;
  opBewaar: (ruw: Ruw) => Promise<string | null>;
}) {
  const concept = useRef<Ruw>(alsRuw(inhoud));
  const [, herteken] = useState(0);
  const opnieuw = () => herteken((n) => n + 1);
  const [melding, zetMelding] = useState('');
  const [bezig, zetBezig] = useState(false);
  const [ritme, zetRitme] = useState<Ritme>(soort === 'nacht' ? 'nacht' : 'dag');
  const [blad, zetBlad] = useState<{ titel: string; plek: Plek | null; ding: Ding } | null>(null);
  const [kindblad, zetKindblad] = useState<{ titel: string; kind: Kindgegevens; nieuw: boolean } | null>(null);

  const c = concept.current;
  // De kinderen in dit scherm zijn die van het concept, niet die van de inhoud.
  const mensen: Persoon[] = useMemo(
    () => lijstVan<any>(c.mensen).map((p) => ({
      id: p.id, naam: tekst(p.naam), emoji: tekst(p.emoji, '🙂'),
      kleur: tekst(p.kleur, '#2FA37C'), kenmerken: kenmerkenVan(p.kenmerken),
    })),
    [c.mensen, blad, kindblad],
  );

  const wieVoorRij = (wie: unknown) => {
    const gekozen = lijstVan<string>(wie).map((id) => mensen.find((p) => p.id === id))
      .filter(Boolean) as Persoon[];
    return gekozen.length && gekozen.length < mensen.length ? gekozen : [];
  };

  const openDing = (titel: string, plek: Plek | null, begin: Partial<Ding>) => {
    zetBlad({ titel, plek, ding: { ...dingVan(c, plek), ...begin } });
  };

  const gereed = async () => {
    const nieuw = opgeschoond(c);
    if (!nieuw.mensen.length) return zetMelding('Er moet minstens één kind zijn.');
    if (!aantalStappen(nieuw.dag as any) && !aantalStappen(nieuw.nacht as any)) {
      return zetMelding('Er moet minstens één stap overblijven.');
    }
    zetBezig(true);
    const fout = await opBewaar(c);
    zetBezig(false);
    if (fout) zetMelding(fout); else opAf();
  };

  return (
    <>
      <Vel titel={TITELS[soort]} melding={melding} bezig={bezig} opAf={opAf} opGereed={gereed}>
        {soort === 'kinderen' && (
          <Kinderen
            c={c}
            opnieuw={opnieuw}
            zetMelding={zetMelding}
            opOpen={(kind, titel, nieuw) => zetKindblad({ titel, kind, nieuw })}
          />
        )}

        {(soort === 'dag' || soort === 'nacht') && (
          <Ritmevel
            c={c}
            ritme={ritme}
            zetRitme={zetRitme}
            opnieuw={opnieuw}
            wieVoorRij={wieVoorRij}
            openDing={openDing}
          />
        )}

        {soort === 'overzicht' && (
          <Weekvel c={c} opnieuw={opnieuw} wieVoorRij={wieVoorRij} openDing={openDing} />
        )}

        {soort === 'eenmalig' && (
          <Eenmaligvel c={c} opnieuw={opnieuw} wieVoorRij={wieVoorRij} openDing={openDing} />
        )}

        {soort === 'algemeen' && <Algemeenvel c={c} opnieuw={opnieuw} />}
      </Vel>

      {!!blad && (
        <Dingblad
          titel={blad.titel}
          ding={blad.ding}
          plek={blad.plek}
          bron={() => concept.current}
          mensen={mensen}
          opAf={() => zetBlad(null)}
          opBewaar={() => { zetBlad(null); opnieuw(); }}
        />
      )}

      {!!kindblad && (
        <Kindblad
          titel={kindblad.titel}
          kind={kindblad.kind}
          opAf={() => zetKindblad(null)}
          opBewaar={(nieuw) => {
            const lijst = c.mensen = lijstVan<any>(c.mensen);
            const bestaand = lijst.find((p) => p.id === nieuw.id);
            const velden = {
              naam: nieuw.naam, emoji: tekst(nieuw.emoji, '🙂'),
              kleur: tekst(nieuw.kleur, KLEUREN[lijst.length % KLEUREN.length]),
              kenmerken: uitParen(nieuw.paren),
            };
            if (bestaand) Object.assign(bestaand, velden);
            else if (tekst(nieuw.naam)) lijst.push({ id: nieuw.id, ...velden });
            zetKindblad(null);
            opnieuw();
          }}
        />
      )}
    </>
  );
}

function uitParen(paren: { sleutel: string; waarde: string }[]): Record<string, string> {
  const uit: Record<string, string> = {};
  paren.forEach((paar) => {
    const sleutel = tekst(paar.sleutel), waarde = tekst(paar.waarde);
    if (sleutel && waarde) uit[sleutel] = waarde;
  });
  return uit;
}

function Kinderen({ c, opnieuw, zetMelding, opOpen }: {
  c: Ruw; opnieuw: () => void; zetMelding: (m: string) => void;
  opOpen: (kind: Kindgegevens, titel: string, nieuw: boolean) => void;
}) {
  const mensen = c.mensen = lijstVan<any>(c.mensen);
  // Anders wijst een stap naar iemand die er niet meer is.
  const losmaken = (id: string) => {
    (['dag', 'nacht'] as const).forEach((r) => lijstVan<any>(c[r]).forEach((g) =>
      lijstVan<any>(g.stappen).forEach((s) => { s.wie = lijstVan<string>(s.wie).filter((x) => x !== id); })));
    [c.overzicht, c.events].forEach((lijst) => lijstVan<any>(lijst).forEach((item) => {
      item.wie = lijstVan<string>(item.wie).filter((x) => x !== id);
    }));
  };
  return (
    <>
      <Bewerkkaart>
        {mensen.map((persoon, i) => (
          <Bewerkrij
            key={persoon.id}
            eerste={i === 0}
            icoon={tekst(persoon.emoji, '🙂')}
            label={tekst(persoon.naam)}
            leeg="Naamloos"
            kleur={persoon.kleur}
            wegTitel="Kind verwijderen"
            opWeg={() => {
              if (mensen.length <= 1) return zetMelding('Er moet minstens één kind overblijven.');
              losmaken(persoon.id);
              mensen.splice(i, 1);
              zetMelding('');
              opnieuw();
            }}
            opOpenen={() => opOpen(kindGegevens({
              id: persoon.id, naam: tekst(persoon.naam), emoji: tekst(persoon.emoji, '🙂'),
              kleur: tekst(persoon.kleur, '#2FA37C'), kenmerken: kenmerkenVan(persoon.kenmerken),
            }), tekst(persoon.naam) || 'Kind', false)}
          />
        ))}
        <Toevoegrij
          opTik={() => opOpen({
            id: nieuwId(), naam: '', emoji: '🙂',
            kleur: KLEUREN[mensen.length % KLEUREN.length], paren: [],
          }, 'Nieuw kind', true)}
        >
          Kind toevoegen
        </Toevoegrij>
      </Bewerkkaart>
      <Notitie>
        Iedereen hier krijgt een eigen rondje bij elke stap. Namen wijzigen mag: de vinkjes
        blijven bij de juiste persoon.
      </Notitie>
    </>
  );
}

function Ritmevel({ c, ritme, zetRitme, opnieuw, wieVoorRij, openDing }: {
  c: Ruw; ritme: Ritme; zetRitme: (r: Ritme) => void; opnieuw: () => void;
  wieVoorRij: (wie: unknown) => Persoon[];
  openDing: (titel: string, plek: Plek | null, begin: Partial<Ding>) => void;
}) {
  const groepen = c[ritme] = lijstVan<any>(c[ritme]);
  return (
    <>
      <Segment ritme={ritme} opKies={zetRitme} marge={0} />
      {groepen.map((groep, gi) => {
        const stappen = groep.stappen = lijstVan<any>(groep.stappen);
        // Een stap met een datum hoort maar op één plek thuis: bij Eenmalig.
        const vast = stappen.filter((s: any) => !s.datum);
        const eenmalig = stappen.length - vast.length;
        return (
          <Bewerkkaart key={gi}>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8,
                           paddingVertical: 10, paddingHorizontal: 12 }}>
              <Minknop titel="Groep verwijderen" opTik={() => { groepen.splice(gi, 1); opnieuw(); }} />
              <Veld waarde={tekst(groep.groep)} plaatshouder="Groep"
                    opWijzig={(v) => { groep.groep = v; }} />
              <Veld soort="tijd" waarde={tekst(groep.tijd)} plaatshouder="tijd"
                    opWijzig={(v) => { groep.tijd = v; }} />
            </View>
            <Streepje />
            {vast.map((stap: any, i: number) => (
              <Bewerkrij
                key={i}
                eerste={i === 0}
                icoon={tekst(stap.icoon, '⭐')}
                label={tekst(stap.label)}
                leeg="Naamloze stap"
                dagen={dagenTekst(stap.dagen)}
                wie={wieVoorRij(stap.wie)}
                wegTitel="Stap verwijderen"
                opWeg={() => { stappen.splice(stappen.indexOf(stap), 1); opnieuw(); }}
                opOpenen={() => openDing(tekst(stap.label) || 'Stap',
                  { waar: 'stap', ritme, groep, stap }, {})}
              />
            ))}
            {!!eenmalig && (
              <Kaartnoot>
                {eenmalig === 1
                  ? 'Hier staat ook één ding voor één dag; dat bewerk je bij Eenmalig.'
                  : `Hier staan ook ${eenmalig} dingen voor één dag; die bewerk je bij Eenmalig.`}
              </Kaartnoot>
            )}
            <Toevoegrij
              opTik={() => openDing('Nieuwe stap', null,
                { icoon: '⭐', taak: true, ritme, groep: tekst(groep.groep) })}
            >
              Stap toevoegen
            </Toevoegrij>
          </Bewerkkaart>
        );
      })}
      <Kaartknop
        plus
        opTik={() => { groepen.push({ groep: 'Nieuwe groep', tijd: '', stappen: [] }); opnieuw(); }}
      >
        Groep toevoegen
      </Kaartknop>
    </>
  );
}

function Weekvel({ c, opnieuw, wieVoorRij, openDing }: {
  c: Ruw; opnieuw: () => void; wieVoorRij: (wie: unknown) => Persoon[];
  openDing: (titel: string, plek: Plek | null, begin: Partial<Ding>) => void;
}) {
  const items = c.overzicht = lijstVan<any>(c.overzicht);
  const vanaf = Number(c.avondVanaf) || 15;
  return (
    <Bewerkkaart>
      {items.map((item, i) => (
        <Bewerkrij
          key={i}
          eerste={i === 0}
          icoon={tekst(item.icoon, '📅')}
          label={tekst(item.tekst)}
          leeg="Naamloos"
          tijd={(naAvond(item, vanaf) ? '🌙 ' : '') + tijdTekst(item)}
          dagen={dagenTekst(item.dagen)}
          wie={wieVoorRij(item.wie)}
          // Een tijdvak, de dagen én wie het betreft passen niet naast de naam.
          tweeregels
          wegTitel="Verwijderen"
          opWeg={() => { items.splice(i, 1); opnieuw(); }}
          opOpenen={() => openDing(tekst(item.tekst) || 'Item', { waar: 'overzicht', item }, {})}
        />
      ))}
      <Toevoegrij opTik={() => openDing('Nieuw item', null, { icoon: '📅', wekelijks: true, taak: false })}>
        Item toevoegen
      </Toevoegrij>
    </Bewerkkaart>
  );
}

function Eenmaligvel({ c, opnieuw, wieVoorRij, openDing }: {
  c: Ruw; opnieuw: () => void; wieVoorRij: (wie: unknown) => Persoon[];
  openDing: (titel: string, plek: Plek | null, begin: Partial<Ding>) => void;
}) {
  const dingen: { soort: 'event' | 'stap'; datum: string; item?: any; ritme?: Ritme; groep?: any; stap?: any }[] = [];
  lijstVan<any>(c.events).filter((e) => e.datum)
    .forEach((item) => dingen.push({ soort: 'event', datum: item.datum, item }));
  (['dag', 'nacht'] as Ritme[]).forEach((ritme) => lijstVan<any>(c[ritme]).forEach((groep) =>
    lijstVan<any>(groep.stappen).forEach((stap) => {
      if (stap.datum) dingen.push({ soort: 'stap', datum: stap.datum, ritme, groep, stap });
    })));
  dingen.sort((a, b) => a.datum.localeCompare(b.datum)
    || tekst(a.item?.tijd).localeCompare(tekst(b.item?.tijd)));

  return (
    <>
      {dingen.length ? (
        <Bewerkkaart>
          {dingen.map((ding, i) => {
            const isEvent = ding.soort === 'event';
            const bron = isEvent ? ding.item : ding.stap;
            const plek: Plek = isEvent
              ? { waar: 'event', item: ding.item }
              : { waar: 'stap', ritme: ding.ritme!, groep: ding.groep, stap: ding.stap };
            const naam = tekst(isEvent ? bron.tekst : bron.label);
            return (
              <Bewerkrij
                key={i}
                eerste={i === 0}
                icoon={tekst(bron.icoon, '📌')}
                label={naam}
                leeg="Naamloos"
                tijd={kortDatum(ding.datum)}
                extra={isEvent
                  ? tijdTekst(bron)
                  : '✅ ' + (ding.ritme === 'dag' ? '☀️ ' : '🌙 ') + tekst(ding.groep.groep, 'ritme')}
                wie={wieVoorRij(bron.wie)}
                tweeregels
                wegTitel="Verwijderen"
                opWeg={() => { haalDingWeg(c, plek); opnieuw(); }}
                opOpenen={() => openDing(naam || 'Iets eenmaligs', plek, {})}
              />
            );
          })}
        </Bewerkkaart>
      ) : (
        <Glas radius={26} style={{ marginTop: 18 }}
              inhoudStijl={{ paddingVertical: 28, paddingHorizontal: 20 }}>
          <Leeg>Er staat niets op een datum.</Leeg>
        </Glas>
      )}

      <Kaartknop plus opTik={() => openDing('Iets eenmaligs', null,
        { icoon: '🎉', wekelijks: false, taak: false })}>
        Iets eenmaligs toevoegen
      </Kaartknop>

      <Notitie>
        Alles wat maar één dag geldt staat hier, en alleen hier. Een taak wordt die dag een kaartje
        tussen de stappen, in het onderdeel dat je kiest; agenda is een regel bij Vandaag en Deze
        week. Wat geweest is verdwijnt vanzelf bij het eerstvolgende bewaren.
      </Notitie>
    </>
  );
}

function Algemeenvel({ c, opnieuw }: { c: Ruw; opnieuw: () => void }) {
  return (
    <>
      <Bewerkkaart>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10,
                       paddingVertical: 8, paddingHorizontal: 12, minHeight: 58 }}>
          <Text style={{ fontSize: 24, width: 46, textAlign: 'center', lineHeight: 29 }}>🏡</Text>
          <Veld waarde={tekst(c.titel)} plaatshouder="Naam van de app"
                opWijzig={(v) => { c.titel = v; }} />
        </View>
        <Streepje />
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10,
                       paddingVertical: 8, paddingHorizontal: 12, minHeight: 58 }}>
          <Text style={{ fontSize: 24, width: 46, textAlign: 'center', lineHeight: 29 }}>🌙</Text>
          <Rijnaam>Avond begint om</Rijnaam>
          <Veld soort="getal" waarde={String(c.avondVanaf)} plaatshouder="15"
                opWijzig={(v) => { c.avondVanaf = v; }} />
        </View>
      </Bewerkkaart>
      <Notitie>Open je de app na dit uur, dan staat het avondritme meteen klaar.</Notitie>
    </>
  );
}

function Kaartnoot({ children }: { children: string }) {
  const kleur = useNachtKleur('#5C5F7A', 'rgba(255,255,255,0.6)');
  return (
    <View>
      <Streepje />
      <Animated.Text style={[L.rijdagen, kleur,
        { fontSize: 12.5, lineHeight: 17, paddingVertical: 9, paddingHorizontal: 14 }]}>
        {children}
      </Animated.Text>
    </View>
  );
}

function Rijnaam({ children }: { children: string }) {
  const kleur = useNachtKleur('#2B2D42', '#ffffff');
  return <Animated.Text style={[L.rijlabel, kleur, { flex: 1, minWidth: 0 }]}>{children}</Animated.Text>;
}

function Leeg({ children }: { children: string }) {
  const kleur = useNachtKleur('#5C5F7A', 'rgba(255,255,255,0.6)');
  return <Animated.Text style={[L.leeg, kleur]}>{children}</Animated.Text>;
}
