// Eén kind bewerken: gezicht, naam, kleur en wat we verder van hem weten.
import { useRef, useState } from 'react';
import { Pressable, View } from 'react-native';
import { Blad } from './Blad';
import { Emojikiezer } from './Emojikiezer';
import { Bewerkkaart, Chips, Emojiknop, Formkop, Minknop, Notitie, Streepje, Toevoegrij, Veld } from './velden';
import { KLEUREN } from './inhoud';
import type { Persoon } from './soorten';

export type Kindgegevens = {
  id: string; naam: string; emoji: string; kleur: string;
  paren: { sleutel: string; waarde: string }[];
};

export function kindGegevens(persoon: Persoon): Kindgegevens {
  return {
    id: persoon.id, naam: persoon.naam, emoji: persoon.emoji, kleur: persoon.kleur,
    paren: Object.entries(persoon.kenmerken || {}).map(([sleutel, waarde]) => ({ sleutel, waarde })),
  };
}

export function Kindblad({ titel, kind, opAf, opBewaar }: {
  titel: string; kind: Kindgegevens;
  opAf: () => void; opBewaar: (k: Kindgegevens) => void;
}) {
  const g = useRef<Kindgegevens>({ ...kind, paren: kind.paren.map((p) => ({ ...p })) });
  const [, herteken] = useState(0);
  const opnieuw = () => herteken((n) => n + 1);
  const [kiezer, zetKiezer] = useState(false);

  return (
    <>
      <Blad titel={titel} knop="Bewaar" opAf={opAf} opKnop={() => opBewaar(g.current)}>
        <Formkop eerste>Gezicht en naam</Formkop>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
          <Emojiknop waarde={g.current.emoji} maat={52} opTik={() => zetKiezer(true)} />
          <Veld waarde={g.current.naam} plaatshouder="Naam" opWijzig={(v) => { g.current.naam = v; }} />
        </View>

        <Formkop>Kleur</Formkop>
        <Chips>
          {KLEUREN.map((kleur) => (
            <Pressable
              key={kleur}
              onPress={() => { g.current.kleur = kleur; opnieuw(); }}
              accessibilityLabel="Kleur"
              style={{ flexGrow: 1, flexShrink: 1, flexBasis: 'auto' }}
            >
              <View
                style={{ minHeight: 34, borderRadius: 15, backgroundColor: kleur, borderWidth: 1,
                         borderColor: kleur,
                         boxShadow: g.current.kleur === kleur ? '0px 0px 0px 2.5px #2B2D42' : undefined }}
              />
            </Pressable>
          ))}
        </Chips>
        <Notitie>Naam wijzigen mag: de vinkjes blijven bij de juiste persoon.</Notitie>

        {/* Wat een bericht van school of de club nodig heeft om bij het juiste
            kind uit te komen. Meestal vult dit zich vanzelf: de assistent
            vraagt ernaar zodra hij het in een bericht tegenkomt. */}
        <Formkop>Wat we verder weten</Formkop>
        <Bewerkkaart>
          {g.current.paren.map((paar, i) => (
            <View key={i}>
              {i > 0 && <Streepje />}
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10,
                             paddingVertical: 8, paddingHorizontal: 12, minHeight: 58 }}>
                <Minknop titel="Kenmerk verwijderen"
                         opTik={() => { g.current.paren.splice(i, 1); opnieuw(); }} />
                <Veld waarde={paar.sleutel} plaatshouder="waarvan" opWijzig={(v) => { paar.sleutel = v; }} />
                <Veld waarde={paar.waarde} plaatshouder="welke" opWijzig={(v) => { paar.waarde = v; }} />
              </View>
            </View>
          ))}
          <Toevoegrij opTik={() => { g.current.paren.push({ sleutel: '', waarde: '' }); opnieuw(); }}>
            Kenmerk toevoegen
          </Toevoegrij>
        </Bewerkkaart>
        <Notitie>
          Bijvoorbeeld schoolgroep 1-2B, of team JO9-3. Daarmee weet de app bij wie een bericht
          van school of de club hoort.
        </Notitie>
      </Blad>

      {kiezer && (
        <Emojikiezer
          titel="Kies een gezicht"
          huidig={g.current.emoji}
          opAf={() => zetKiezer(false)}
          opKlaar={(teken) => { g.current.emoji = teken; zetKiezer(false); opnieuw(); }}
        />
      )}
    </>
  );
}
