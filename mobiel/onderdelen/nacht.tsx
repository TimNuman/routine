import { createContext, useContext } from 'react';
import { interpolateColor, useAnimatedStyle, type SharedValue } from 'react-native-reanimated';

// Eén waarde die van 0 naar 1 loopt als je van ochtend naar avond gaat. Alles
// wat van kleur verschiet hangt eraan, zodat het hele scherm in één beweging
// omgaat in plaats van per onderdeel om te klappen.
export const Nacht = createContext<SharedValue<number> | null>(null);

export function useNacht(): SharedValue<number> {
  const v = useContext(Nacht);
  if (!v) throw new Error('Nacht-waarde ontbreekt');
  return v;
}

export function useNachtKleur(licht: string, donker: string) {
  const nacht = useNacht();
  return useAnimatedStyle(() => ({
    color: interpolateColor(nacht.value, [0, 1], [licht, donker]),
  }));
}
