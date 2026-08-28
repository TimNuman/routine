// Baloo 2 en Nunito komen van Google met alles erin: Baloo 2 heeft het complete
// Devanagari-schrift aan boord, Nunito het Cyrillische. Samen 1,1 MB voor vier
// gewichten, terwijl deze app alleen Latijn schrijft.
//
// Op web lost Google dat zelf op — de <link> stuurt een woff2 met alleen de
// latin-slice. Een app op een telefoon heeft een echt bestand nodig en kan dat
// niet, dus knippen we het hier zelf bij. Zelfde letters, ~10% van de bytes.
//
//   node lettertypes.mjs
import subsetFont from 'subset-font';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { statSync } from 'node:fs';

const NAAR = new URL('./assets/fonts/', import.meta.url);

const WIL = [
  ['@expo-google-fonts/baloo-2/700Bold/Baloo2_700Bold.ttf', 'Baloo2_700Bold.ttf'],
  ['@expo-google-fonts/baloo-2/800ExtraBold/Baloo2_800ExtraBold.ttf', 'Baloo2_800ExtraBold.ttf'],
  ['@expo-google-fonts/nunito/700Bold/Nunito_700Bold.ttf', 'Nunito_700Bold.ttf'],
  ['@expo-google-fonts/nunito/800ExtraBold/Nunito_800ExtraBold.ttf', 'Nunito_800ExtraBold.ttf'],
];

// Latin-1 plus wat interpunctie en het euroteken; genoeg voor Nederlands.
const TEKENS = [
  ...bereik(0x20, 0xff),
  0x0131, 0x0152, 0x0153, 0x02bb, 0x02bc, 0x02c6, 0x02da, 0x02dc,
  ...bereik(0x2018, 0x201f), 0x2013, 0x2014, 0x2026, 0x2039, 0x203a,
  0x20ac, 0x2122, 0x2192, 0x2713,
].map((n) => String.fromCodePoint(n)).join('');

function bereik(van, tot) {
  return Array.from({ length: tot - van + 1 }, (_, i) => van + i);
}

await mkdir(NAAR, { recursive: true });

let was = 0, wordt = 0;
for (const [vanaf, naam] of WIL) {
  const pad = new URL(`./node_modules/${vanaf}`, import.meta.url);
  const bron = await readFile(pad);
  const klein = await subsetFont(bron, TEKENS, { targetFormat: 'truetype' });
  await writeFile(new URL(naam, NAAR), klein);
  was += bron.length;
  wordt += klein.length;
  console.log(`${naam.padEnd(28)} ${kb(bron.length)} → ${kb(klein.length)}`);
}
console.log(`\ntotaal ${kb(was)} → ${kb(wordt)}`);

function kb(n) { return `${String(Math.round(n / 1024)).padStart(4)} KB`; }
