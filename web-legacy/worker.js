export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (!url.pathname.startsWith('/api/')) return env.ASSETS.fetch(request);

    if (!env.UPSTREAM) {
      return new Response(JSON.stringify({ fout: 'Geen UPSTREAM gebonden.' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json; charset=utf-8' },
      });
    }

    return await env.UPSTREAM.fetch(request);
  },
};
