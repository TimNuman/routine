import { useState } from 'react';
import Animated from 'react-native-reanimated';
import { Gezichten, Lijst, Lijstrij } from '../onderdelen/Lijst';
import { Velscherm, type Velsoort } from '../onderdelen/Velscherm';
import { L } from '../onderdelen/letters';
import { useNachtKleur } from '../onderdelen/nacht';
import { Scherm } from '../onderdelen/Scherm';
import { useGezin } from '../onderdelen/gezin';
import { aantalStappen, eenmaligeDingen, zacht } from '../onderdelen/inhoud';

export default function Instellingenscherm() {
  const { inhoud, bewaar } = useGezin();
  const [vel, zetVel] = useState<Velsoort | null>(null);

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
            opTik={() => zetVel('kinderen')}
          />
          <Lijstrij
            eerste={false}
            icoon="☀️"
            titel="Ochtendritme"
            uitleg={`${aantalStappen(inhoud.dag)} stappen`}
            opTik={() => zetVel('dag')}
          />
          <Lijstrij
            eerste={false}
            icoon="🌙"
            titel="Avondritme"
            uitleg={`${aantalStappen(inhoud.nacht)} stappen`}
            opTik={() => zetVel('nacht')}
          />
          <Lijstrij
            eerste={false}
            icoon="📅"
            titel="Weekritme"
            uitleg="school, sport en wat er verder is"
            opTik={() => zetVel('overzicht')}
          />
          <Lijstrij
            eerste={false}
            icoon="📌"
            titel="Eenmalig"
            uitleg={eenmaligTekst}
            opTik={() => zetVel('eenmalig')}
          />
          <Lijstrij
            eerste={false}
            icoon="⚙️"
            titel="Naam en tijden"
            uitleg={`${inhoud.titel} · avond vanaf ${inhoud.avondVanaf}:00`}
            opTik={() => zetVel('algemeen')}
          />
        </Lijst>
      )}
      <Voetnoot>testversie</Voetnoot>

      {!!vel && inhoud && (
        <Velscherm
          soort={vel}
          inhoud={inhoud}
          opAf={() => zetVel(null)}
          opBewaar={bewaar}
        />
      )}
    </Scherm>
  );
}

function Voetnoot({ children }: { children: string }) {
  const kleur = useNachtKleur('#5C5F7A', 'rgba(255,255,255,0.6)');
  return <Animated.Text style={[L.voetnoot, kleur, { opacity: 0.75 }]}>{children}</Animated.Text>;
}
