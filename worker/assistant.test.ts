import { createExecutionContext, env, waitOnExecutionContext } from 'cloudflare:test';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { ageText, cleanPayload, promptText } from './assistant';
import app from './index';

async function read(body: unknown, extra: Partial<Env> = {}) {
  const ctx = createExecutionContext();
  const res = await app.fetch(
    new Request('https://house/api/v2/read', {
      method: 'POST',
      body: typeof body === 'string' ? body : JSON.stringify(body),
      headers: { 'Content-Type': 'application/json' },
    }),
    { ...env, ...extra },
    ctx,
  );
  await waitOnExecutionContext(ctx);
  return res;
}

/** Stands in for api.anthropic.com; remembers what was asked. */
function claudeSays(answer: unknown, status = 200) {
  const asked: unknown[] = [];
  const body =
    status === 200
      ? {
          id: 'msg',
          type: 'message',
          role: 'assistant',
          model: 'claude-opus-5',
          stop_reason: 'end_turn',
          content: [{ type: 'text', text: JSON.stringify(answer) }],
          usage: { input_tokens: 1, output_tokens: 1 },
        }
      : answer;
  vi.stubGlobal('fetch', async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input instanceof Request ? input.url : input);
    if (!url.startsWith('https://api.anthropic.com/v1/messages')) throw new Error('unexpected fetch: ' + url);
    asked.push(JSON.parse(String(init?.body)));
    return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
  });
  return asked;
}

describe('cleaning the payload', () => {
  it('keeps only what is allowed, trimmed', () => {
    const clean = cleanPayload({
      text: '  Tennis on Tuesday  ',
      today: '2026-09-02',
      round: '2.7',
      language: 'en-GB',
      children: [
        { id: 'emma', name: 'Emma', traits: { group: '1-2B', extra: 42 }, birthday: '2019-03-04' },
        { id: 'filip', name: 'Filip', birthday: 'somewhen' },
        { name: 'no id' },
        'garbage',
      ],
    });
    expect(clean).toEqual({
      house: { day: [], night: [], week: [] },
      text: 'Tennis on Tuesday',
      today: '2026-09-02',
      round: 2,
      language: 'en-GB',
      children: [
        { id: 'emma', name: 'Emma', traits: { group: '1-2B', extra: '42' }, birthday: '2019-03-04' },
        { id: 'filip', name: 'Filip', traits: {}, birthday: '' },
      ],
    });
  });

  it('falls back on defaults for junk', () => {
    const clean = cleanPayload({ today: 'tomorrow', round: -3, language: 'klingon!!', text: 7 });
    expect(clean.today).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    expect(clean.round).toBe(1);
    expect(clean.language).toBe('nl');
    expect(clean.text).toBe('');
    expect(cleanPayload(null).children).toEqual([]);
  });

  it('caps the text length', () => {
    expect(cleanPayload({ text: 'x'.repeat(30_000) }).text).toHaveLength(20_000);
  });
});

describe('what already stands', () => {
  it('keeps the shape of the house, not the one-off things', () => {
    const clean = cleanPayload({
      text: 'hi',
      house: {
        day: [{ name: ' Boven ', time: '6:00 – 6:30', steps: ['Wakker worden', '', 42] }, 'garbage'],
        night: [],
        week: ['School', ''],
        events: [{ text: 'Fysio' }],
      },
    });
    expect(clean.house).toEqual({
      day: [{ name: 'Boven', time: '6:00 – 6:30', steps: ['Wakker worden', '42'] }],
      night: [],
      week: ['School'],
    });
    expect(clean.house).not.toHaveProperty('events');
  });

  it('tells the model what it does not have to propose again', () => {
    const text = promptText(
      cleanPayload({
        text: 'hi',
        house: {
          day: [{ name: 'Boven', time: '6:00 – 6:30', steps: ['Tanden poetsen'] }],
          week: ['School'],
        },
      }),
    );
    expect(text).toContain('- ochtend, Boven (6:00 – 6:30): Tanden poetsen');
    expect(text).toContain('- elke week: School');
  });

  it('says so when the app is still empty', () => {
    const text = promptText(cleanPayload({ text: 'wij zijn met z\'n drieën' }));
    expect(text).toContain('- nog geen. De app is leeg.');
    expect(text).toContain('- nog niets.');
  });
});

describe('the prompt', () => {
  it('names the day in the requested language', () => {
    const text = promptText(cleanPayload({ text: 'hi', today: '2026-09-02', language: 'en', children: [] }));
    expect(text).toContain('Vandaag is 2026-09-02 (Wednesday)');
    expect(text).toContain('English (en)');
  });

  it('lists each child with its traits', () => {
    const text = promptText(
      cleanPayload({
        text: 'hi',
        children: [
          { id: 'emma', name: 'Emma', traits: { group: '1-2B' } },
          { id: 'mads', name: '' },
        ],
      }),
    );
    expect(text).toContain('- id emma, Emma — group: 1-2B');
    expect(text).toContain('- id mads, naamloos — nog niets bekend');
  });

  it('tells how old a child is today', () => {
    const text = promptText(
      cleanPayload({
        text: 'maak een voedings- en slaapschema voor Filip',
        today: '2026-09-04',
        children: [
          { id: 'filip', name: 'Filip', birthday: '2026-08-04' },
          { id: 'emma', name: 'Emma', traits: { group: '3B' }, birthday: '2019-03-04' },
        ],
      }),
    );
    expect(text).toContain('- id filip, Filip — geboren 2026-08-04 (1 maand oud)');
    expect(text).toContain('- id emma, Emma — geboren 2019-03-04 (7 jaar oud), group: 3B');
  });
});

describe('how old someone is', () => {
  it('counts in days, weeks, months and years', () => {
    expect(ageText('2026-09-03', '2026-09-04')).toBe('1 dag');
    expect(ageText('2026-08-21', '2026-09-04')).toBe('2 weken');
    expect(ageText('2026-08-04', '2026-09-04')).toBe('1 maand');
    expect(ageText('2026-01-04', '2026-09-04')).toBe('8 maanden');
    expect(ageText('2024-09-05', '2026-09-04')).toBe('23 maanden');
    expect(ageText('2024-09-04', '2026-09-04')).toBe('2 jaar');
    expect(ageText('2019-03-04', '2026-09-04')).toBe('7 jaar');
  });

  it('says nothing about a day that has not come yet or is not a day', () => {
    expect(ageText('2027-01-01', '2026-09-04')).toBe('');
    expect(ageText('ooit', '2026-09-04')).toBe('');
  });
});

describe('POST /api/v2/read', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('answers nothing for an empty text without asking Claude', async () => {
    expect(await (await read({ text: '   ' })).json()).toEqual({ type: 'nothing' });
    expect(await (await read('not json')).json()).toEqual({ type: 'nothing' });
  });

  it('refuses without an API key', async () => {
    expect((await read({ text: 'Tennis' }, { ANTHROPIC_API_KEY: '' })).status).toBe(500);
  });

  it("passes Claude's answer through", async () => {
    const answer = {
      type: 'suggestions',
      items: [
        {
          kind: 'weekly',
          icon: '🎾',
          text: 'Tennis',
          days: ['tue'],
          time: '18:00',
          who: ['emma'],
          source: 'Every Tuesday',
        },
      ],
    };
    const asked = claudeSays(answer);
    const res = await read({
      text: 'Every Tuesday 18:00 tennis Emma',
      children: [{ id: 'emma', name: 'Emma' }],
    });
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual(answer);

    expect(asked).toHaveLength(1);
    const request = asked[0] as {
      model: string;
      output_config: { format: { type: string } };
      messages: { content: string }[];
    };
    expect(request.model).toBe('claude-opus-5');
    expect(request.output_config.format.type).toBe('json_schema');
    expect(request.messages[0]?.content).toContain('Every Tuesday 18:00 tennis Emma');
    expect(request.messages[0]?.content).toContain('- id emma, Emma');
  });

  it('turns a rate limit into a 429', async () => {
    claudeSays({ type: 'error', error: { type: 'rate_limit_error', message: 'slow down' } }, 429);
    const res = await read({ text: 'Tennis' });
    expect(res.status).toBe(429);
  });

  it('turns a wrong key into a 500 with a clear message', async () => {
    claudeSays({ type: 'error', error: { type: 'authentication_error', message: 'bad key' } }, 401);
    const res = await read({ text: 'Tennis' });
    expect(res.status).toBe(500);
    expect(await res.json()).toEqual({ error: "The assistant's API key is wrong." });
  });
});
