// NativeWind zet zijn klassen om op gewone componenten, maar niet op de
// Animated-varianten van Reanimated. Alles wat van kleur verschiet is er zo een,
// dus die krijgen hier een echte stijl in plaats van een className. De maten
// komen één op één uit de webversie.
export const L = {
  titel: { fontFamily: 'Baloo2_800ExtraBold', fontSize: 36, lineHeight: 38, letterSpacing: -0.5 },
  onder: { fontFamily: 'Nunito_700Bold', fontSize: 15, marginTop: 3 },
  groep: { fontFamily: 'Baloo2_800ExtraBold', fontSize: 17 },
  groeptijd: { fontFamily: 'Nunito_700Bold', fontSize: 13 },
  taaknaam: { fontFamily: 'Baloo2_700Bold', textAlign: 'center' },
  naam: { fontFamily: 'Baloo2_800ExtraBold', fontSize: 16 },
  telling: { fontFamily: 'Nunito_800ExtraBold', fontSize: 12.5 },
  knop: { fontFamily: 'Baloo2_800ExtraBold', fontSize: 15 },
  kindnaam: { fontFamily: 'Nunito_800ExtraBold', fontSize: 11 },
  blokkop: { fontFamily: 'Baloo2_800ExtraBold', fontSize: 16, lineHeight: 22 },
  agendanaam: { fontFamily: 'Baloo2_700Bold', fontSize: 15.5 },
  agendatijd: { fontFamily: 'Nunito_800ExtraBold', fontSize: 12.5 },
  merk: { fontFamily: 'Baloo2_800ExtraBold', fontSize: 12.5 },
} as const;
