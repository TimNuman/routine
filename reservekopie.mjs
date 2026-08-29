// Haalt alles uit het huis en zet het als één bestand op schijf, of zet zo'n
// bestand weer terug.
//
// Het huis is een Durable Object: er zit geen exportknop op en geen console waar
// je even in kunt kijken. Wat erin zit is de inhoud — het ritme, de kinderen, het
// weekritme — plus de vinkjes per dag. Die vinkjes bewaart het huis zelf maar
// zeven dagen, dus daar houdt dit ook op; ze zijn morgen toch weg.
//
//   node reservekopie.mjs                     maak er een
//   node reservekopie.mjs --terug <bestand>   zet de inhoud terug
//
// Het adres komt uit ROUTINE_ADRES, en de sleutel uit ROUTINE_SLEUTEL als je er
// een hebt neergezet.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';

const ADRES = (process.env.ROUTINE_ADRES || '').replace(/\/+$/, '');
const SLEUTEL = process.env.ROUTINE_SLEUTEL || '';
const BEWAARDAGEN = 7;

if (!ADRES) {
  console.error('Zet ROUTINE_ADRES op het adres van je Worker.');
  process.exit(1);
}

const kopjes = SLEUTEL ? { 'X-Routine-Sleutel': SLEUTEL } : {};

async function haal(pad) {
  const res = await fetch(ADRES + pad, { headers: kopjes });
  if (!res.ok) throw new Error(`${pad} gaf ${res.status}`);
  return await res.json();
}

function datumVan(d) {
  return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 10);
}

async function maak() {
  const { inhoud } = await haal('/api/opslag/inhoud');
  if (!inhoud) throw new Error('Het huis is leeg; niets om te bewaren.');

  // Vandaag en de zes dagen ervoor: verder terug bewaart het huis niet.
  const dagen = {};
  for (let i = 0; i < BEWAARDAGEN; i++) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    const datum = datumVan(d);
    const { vinkjes } = await haal('/api/opslag/dag?datum=' + datum);
    if (vinkjes && Object.keys(vinkjes).length) dagen[datum] = vinkjes;
  }

  const nu = new Date();
  const naam = `${datumVan(nu)}-${String(nu.getHours()).padStart(2, '0')}${String(nu.getMinutes()).padStart(2, '0')}`;
  mkdirSync('reservekopie', { recursive: true });
  const pad = `reservekopie/${naam}.json`;
  writeFileSync(pad, JSON.stringify({ gemaakt: nu.toISOString(), adres: ADRES, inhoud, dagen }, null, 2) + '\n');

  const stappen = ['dag', 'nacht'].reduce(
    (n, welk) => n + (inhoud[welk] || []).reduce((m, g) => m + (g.stappen || []).length, 0), 0);
  console.log(`${pad}`);
  console.log(`  ${(inhoud.mensen || []).length} kinderen, ${stappen} stappen, ` +
              `${(inhoud.overzicht || []).length} weekritme, ${(inhoud.events || []).length} eenmalig`);
  console.log(`  vinkjes van ${Object.keys(dagen).length} dag(en)`);
}

// Alleen de inhoud gaat terug. De vinkjes staan er wel in om te kunnen kijken wat
// er was, maar terugzetten zou betekenen dat je een ochtend die al geweest is
// opnieuw afvinkt — en daar is niemand mee geholpen.
async function terug(bestand) {
  const kopie = JSON.parse(readFileSync(bestand, 'utf8'));
  if (!kopie.inhoud) throw new Error('Geen inhoud in dat bestand.');
  const res = await fetch(ADRES + '/api/opslag/inhoud', {
    method: 'PUT',
    headers: { ...kopjes, 'Content-Type': 'application/json' },
    body: JSON.stringify(kopie.inhoud),
  });
  if (!res.ok) throw new Error(`Terugzetten gaf ${res.status}`);
  console.log(`Terug uit ${bestand} (van ${kopie.gemaakt}).`);
}

const [vlag, bestand] = process.argv.slice(2);
try {
  if (vlag === '--terug') {
    if (!bestand) throw new Error('Geef het bestand mee: --terug reservekopie/....json');
    await terug(bestand);
  } else {
    await maak();
  }
} catch (err) {
  console.error(err.message);
  process.exit(1);
}
