export type Persoon = { id: string; naam: string; emoji: string; kleur: string };
export type Stap = { icoon: string; label: string; dagen: string[]; datum: string; wie: string[] };
export type Groep = { groep: string; tijd: string; stappen: Stap[] };
export type Inhoud = {
  titel: string;
  avondVanaf: number;
  mensen: Persoon[];
  dag: Groep[];
  nacht: Groep[];
};
export type Ritme = 'dag' | 'nacht';
