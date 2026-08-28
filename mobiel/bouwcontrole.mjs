// Een uitgave met een testadres erin is niet te zien aan de pagina: hij vraagt
// de browser alleen om toegang tot het lokale netwerk en blijft dan leeg. Dus
// kijken we na het uitgeven of er nog een adres van deze machine in staat.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

const MAP = new URL('../public/nieuw/', import.meta.url).pathname;
const VERDACHT = /https?:\/\/(localhost|127\.0\.0\.1|0\.0\.0\.0|10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+)(:\d+)?/g;

function alleBestanden(map) {
  return readdirSync(map).flatMap((naam) => {
    const pad = join(map, naam);
    return statSync(pad).isDirectory() ? alleBestanden(pad) : [pad];
  });
}

const gevonden = [];
for (const pad of alleBestanden(MAP)) {
  if (!/\.(js|html|css|json)$/.test(pad)) continue;
  const treffers = readFileSync(pad, 'utf8').match(VERDACHT);
  if (treffers) gevonden.push([pad.slice(MAP.length), [...new Set(treffers)].join(', ')]);
}

if (gevonden.length) {
  console.error('De uitgave wijst naar deze machine:');
  gevonden.forEach(([pad, adressen]) => console.error(`  ${pad}: ${adressen}`));
  console.error('Bouw opnieuw zonder EXPO_PUBLIC_API of EXPO_PUBLIC_ASSISTENT_URL.');
  process.exit(1);
}
console.log('Uitgave gecontroleerd: geen adressen van deze machine.');
