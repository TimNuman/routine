// The shapes the iOS app and the server agree on. The server stores content as
// an opaque document (the app owns its structure); these types are the contract.

export const CONTENT_VERSION = 2;

export const ROUTINES = ['day', 'night'] as const;
export type Routine = (typeof ROUTINES)[number];

export const WEEKDAYS = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'] as const;
export type Weekday = (typeof WEEKDAYS)[number];

export interface Person {
  id: string;
  name: string;
  emoji: string;
  color: string;
  traits: Record<string, string>;
}

export interface Step {
  icon: string;
  label: string;
  days?: Weekday[];
  date?: string;
  who?: string[];
}

export interface Group {
  name: string;
  time: string;
  steps: Step[];
}

export interface WeekItem {
  icon: string;
  text: string;
  time?: string;
  until?: string;
  days?: Weekday[];
  who?: string[];
  evening?: boolean;
}

export interface Event {
  id: string;
  icon: string;
  text: string;
  time?: string;
  until?: string;
  date: string;
  who?: string[];
}

export interface Content {
  version: number;
  title: string;
  people: Person[];
  day: Group[];
  night: Group[];
  week: WeekItem[];
  events: Event[];
}

/** Which steps are ticked on one day: `<routine>/<step>/<person>` → true. */
export type Checks = Record<string, true>;

/** What the house tells every connected phone. */
export type HouseEvent =
  | { kind: 'content'; content: Content }
  | { kind: 'check'; date: string; key: string; on: boolean }
  | { kind: 'routine'; date: string; routine: Routine };

/** The first frame on a stream, and the answer to a `day` request. */
export interface Opening {
  kind: 'start';
  date: string;
  content: Content | null;
  checks: Checks;
}

export function isRoutine(value: unknown): value is Routine {
  return (ROUTINES as readonly unknown[]).includes(value);
}
