export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (!url.pathname.startsWith('/api/')) return env.ASSETS.fetch(request);

    if (!env.UPSTREAM) {
      return new Response(JSON.stringify({ fout: 'Geen UPSTREAM ingesteld.' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json; charset=utf-8' },
      });
    }

    const target = new URL(url.pathname + url.search, env.UPSTREAM);
    const forwarded = new Request(target, request);
    if (env.SLEUTEL) forwarded.headers.set('X-Routine-Sleutel', env.SLEUTEL);
    return await fetch(forwarded);
  },
};
