// Zet het commit-nummer in de pagina en in versie.txt ernaast. De app
// vergelijkt die twee en weet zo dat er iets nieuwers is uitgerold.
//
// Draait bij elke manier van uitrollen — Cloudflare Workers Builds, GitHub
// Actions, of met de hand — dus het nummer komt uit wat er toevallig is.
import { readFileSync, writeFileSync } from 'node:fs';
import { execSync } from 'node:child_process';

function versie(){
  const uitOmgeving = process.env.WORKERS_CI_COMMIT_SHA
    || process.env.GITHUB_SHA
    || process.env.CF_PAGES_COMMIT_SHA;
  if(uitOmgeving) return uitOmgeving.trim();
  try{ return execSync('git rev-parse HEAD', { encoding:'utf8' }).trim(); }
  catch{ return 'los-' + Math.random().toString(36).slice(2, 10); }
}

const nummer = versie();
const pad = 'public/index.html';
const pagina = readFileSync(pad, 'utf8');
if(!pagina.includes('__VERSIE__')){
  console.error('__VERSIE__ staat niet meer in ' + pad + '; niets gestempeld.');
  process.exit(1);
}
writeFileSync(pad, pagina.replace('__VERSIE__', nummer));
writeFileSync('public/versie.txt', nummer);
console.log('gestempeld op ' + nummer);
