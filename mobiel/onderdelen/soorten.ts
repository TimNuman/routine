// kenmerken: wat een bericht van school of de club nodig heeft om bij het
// juiste kind uit te komen, bijvoorbeeld { schoolgroep: '1-2B' }.
export type Persoon = {
  id: string; naam: string; emoji: string; kleur: string;
  kenmerken: Record<string, string>;
};
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
export type Agendaitem = Weekitem & { id?: string; datum?: string; bijzonder?: boolean };

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
