import Animated from 'react-native-reanimated';
import { Gezichten, Lijst, Lijstrij } from '../onderdelen/Lijst';
import { L } from '../onderdelen/letters';
import { useNachtKleur } from '../onderdelen/nacht';
import { Scherm } from '../onderdelen/Scherm';
import { useGezin } from '../onderdelen/gezin';
import { aantalStappen, eenmaligeDingen, zacht } from '../onderdelen/inhoud';

export default function Instellingenscherm() {
  const { inhoud } = useGezin();

  const eenmalig = inhoud ? eenmaligeDingen(inhoud).length : 0;
  const eenmaligTekst = !eenmalig ? 'niets op een datum'
    : eenmalig === 1 ? 'één ding op een datum' : `${eenmalig} dingen op een datum`;

  return (
    <Scherm titel="Instellingen" onder={inhoud?.titel || ''} smal>
      {inhoud && (
        <Lijst>
          <Lijstrij
            eerste
            icoon="🧒"
            titel="Kinderen"
            uitleg={inhoud.mensen.map((p) => p.naam).join(', ') || 'nog niemand'}
            rechts={<Gezichten mensen={inhoud.mensen} zacht={zacht} />}
            opTik={() => {}}
          />
          <Lijstrij
            eerste={false}
            icoon="☀️"
            titel="Ochtendritme"
            uitleg={`${aantalStappen(inhoud.dag)} stappen`}
            opTik={() => {}}
          />
          <Lijstrij
            eerste={false}
            icoon="🌙"
            titel="Avondritme"
            uitleg={`${aantalStappen(inhoud.nacht)} stappen`}
            opTik={() => {}}
          />
          <Lijstrij
            eerste={false}
            icoon="📅"
            titel="Weekritme"
            uitleg="school, sport en wat er verder is"
            opTik={() => {}}
          />
          <Lijstrij
            eerste={false}
            icoon="📌"
            titel="Eenmalig"
            uitleg={eenmaligTekst}
            opTik={() => {}}
          />
          <Lijstrij
            eerste={false}
            icoon="⚙️"
            titel="Naam en tijden"
            uitleg={`${inhoud.titel} · avond vanaf ${inhoud.avondVanaf}:00`}
            opTik={() => {}}
          />
        </Lijst>
      )}
      <Voetnoot>testversie</Voetnoot>
    </Scherm>
  );
}

function Voetnoot({ children }: { children: string }) {
  const kleur = useNachtKleur('#5C5F7A', 'rgba(255,255,255,0.6)');
  return <Animated.Text style={[L.voetnoot, kleur, { opacity: 0.75 }]}>{children}</Animated.Text>;
}
