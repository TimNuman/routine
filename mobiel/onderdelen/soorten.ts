export type Persoon = { id: string; naam: string; emoji: string; kleur: string };
export type Stap = { icoon: string; label: string; dagen: string[]; datum: string; wie: string[] };
export type Groep = { groep: string; tijd: string; stappen: Stap[] };
// Wat er die dag verder is: het vaste weekritme en de eenmalige dingen.
export type Weekitem = {
  icoon: string; tekst: string; tijd: string; tot: string;
  dagen: string[]; wie: string[]; avond: boolean;
};
export type Eenmalig = {
  id: string; icoon: string; tekst: string; tijd: string; tot: string;
  datum: string; wie: string[];
};
export type Agendaitem = Weekitem & { bijzonder?: boolean };

export type Inhoud = {
  titel: string;
  avondVanaf: number;
  mensen: Persoon[];
  dag: Groep[];
  nacht: Groep[];
  overzicht: Weekitem[];
  events: Eenmalig[];
};
export type Ritme = 'dag' | 'nacht';
