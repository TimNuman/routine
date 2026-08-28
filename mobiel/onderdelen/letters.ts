// NativeWind zet zijn klassen om op gewone componenten, maar niet op de
// Animated-varianten van Reanimated. Alles wat van kleur verschiet is er zo een,
// dus die krijgen hier een echte stijl in plaats van een className.
export const L = {
  titel: { fontFamily: 'Baloo2_800ExtraBold', fontSize: 40, lineHeight: 46 },
  onder: { fontFamily: 'Nunito_800ExtraBold', fontSize: 15 },
  groep: { fontFamily: 'Baloo2_800ExtraBold', fontSize: 19 },
  groeptijd: { fontFamily: 'Nunito_800ExtraBold', fontSize: 13 },
  taaknaam: { fontFamily: 'Baloo2_700Bold', fontSize: 13, lineHeight: 16, textAlign: 'center', marginTop: 4 },
  naam: { fontFamily: 'Baloo2_700Bold', fontSize: 13 },
  knop: { fontFamily: 'Baloo2_700Bold', fontSize: 15 },
  kindnaam: { fontFamily: 'Nunito_800ExtraBold', fontSize: 11 },
} as const;
