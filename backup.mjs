// Pulls everything out of the house into one file on disk, or puts such a file
// back.
//
// The house is a Durable Object: there is no export button and no console to
// peek into. What is in it is the content (the routines, the children, the
// week) plus the checks per day. The house keeps checks for seven days, so
// that is as far back as this goes.
//
//   node backup.mjs                    make one
//   node backup.mjs --restore <file>   put the content back
//
// The address comes from ROUTINE_URL, the key from ROUTINE_KEY if you set one.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';

const URL_BASE = (process.env.ROUTINE_URL || '').replace(/\/+$/, '');
const KEY = process.env.ROUTINE_KEY || '';
const KEEP_DAYS = 7;
const DIR = 'backups';

if (!URL_BASE) {
  console.error('Set ROUTINE_URL to the address of your Worker.');
  process.exit(1);
}

const headers = KEY ? { 'X-Routine-Key': KEY } : {};

async function get(path) {
  const res = await fetch(URL_BASE + path, { headers });
  if (!res.ok) throw new Error(`${path} returned ${res.status}`);
  return await res.json();
}

function localDate(d) {
  return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 10);
}

async function backup() {
  const { content } = await get('/api/v2/storage/content');
  if (!content) throw new Error('The house is empty; nothing to save.');

  const dates = Array.from({ length: KEEP_DAYS }, (_, i) => {
    const d = new Date();
    d.setDate(d.getDate() - i);
    return localDate(d);
  });
  const days = {};
  const results = await Promise.all(dates.map((date) => get('/api/v2/storage/day?date=' + date)));
  for (const { date, checks } of results) {
    if (checks && Object.keys(checks).length) days[date] = checks;
  }

  const now = new Date();
  const name = `${localDate(now)}-${String(now.getHours()).padStart(2, '0')}${String(now.getMinutes()).padStart(2, '0')}`;
  mkdirSync(DIR, { recursive: true });
  const path = `${DIR}/${name}.json`;
  writeFileSync(
    path,
    JSON.stringify({ made: now.toISOString(), url: URL_BASE, content, days }, null, 2) + '\n',
  );

  const steps = ['day', 'night'].reduce(
    (n, which) => n + (content[which] || []).reduce((m, g) => m + (g.steps || []).length, 0),
    0,
  );
  console.log(path);
  console.log(
    `  ${(content.people || []).length} children, ${steps} steps, ` +
      `${(content.week || []).length} weekly, ${(content.events || []).length} one-off`,
  );
  console.log(`  checks for ${Object.keys(days).length} day(s)`);
}

// Only the content goes back. The checks are in the file so you can see what
// was there, but restoring them would re-tick a morning that has already
// happened, and nobody is helped by that.
async function restore(file) {
  const copy = JSON.parse(readFileSync(file, 'utf8'));
  if (!copy.content) throw new Error('No content in that file.');
  const res = await fetch(URL_BASE + '/api/v2/storage/content', {
    method: 'PUT',
    headers: { ...headers, 'Content-Type': 'application/json' },
    body: JSON.stringify(copy.content),
  });
  if (!res.ok) throw new Error(`Restoring returned ${res.status}`);
  console.log(`Restored from ${file} (made ${copy.made}).`);
}

const [flag, file] = process.argv.slice(2);
try {
  if (flag === '--restore' && file) await restore(file);
  else if (!flag) await backup();
  else {
    console.error('Usage: node backup.mjs [--restore <file>]');
    process.exit(1);
  }
} catch (err) {
  console.error(err.message);
  process.exit(1);
}
