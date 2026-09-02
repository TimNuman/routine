// The page behind an invite link. Someone taps the link in WhatsApp; this
// offers to open the app with the code, or to get the app first.
//
// With the paid developer account the app can claim /join/* as a universal
// link (see /.well-known/apple-app-site-association below) and iOS opens it
// straight away, skipping this page.

export const JOIN_SCHEME = 'routines';

export function siteAssociation(env: Env): Record<string, unknown> {
  return {
    applinks: {
      details: [
        { appIDs: [`${env.APPLE_TEAM_ID}.${env.APPLE_BUNDLE_ID}`], components: [{ '/': '/join/*' }] },
      ],
    },
  };
}

function escape(text: string): string {
  return text.replace(/[&<>"']/g, (ch) => `&#${ch.charCodeAt(0)};`);
}

export function joinPage(code: string, env: Env): string {
  const pretty = code.length === 8 ? `${code.slice(0, 4)}-${code.slice(4)}` : code;
  const valid = code.length === 8;
  const open = `${JOIN_SCHEME}://join/${code}`;
  const store = env.APP_STORE_URL
    ? `<a class="second" href="${escape(env.APP_STORE_URL)}">Nog geen app? Haal Routines uit de App Store</a>`
    : `<p class="note">Nog geen app? Routines staat nog niet in de App Store; vraag degene die je uitnodigt om een testversie.</p>`;
  return `<!doctype html>
<html lang="nl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Routines</title>
<style>
  body { margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center;
         font-family: -apple-system, system-ui, sans-serif; color: #2B2D42;
         background: linear-gradient(180deg, #FFE8B8 0%, #FFD6D6 55%, #E3E8F6 100%); }
  main { max-width: 420px; padding: 32px 24px; text-align: center; }
  .sun { font-size: 56px; }
  h1 { font-size: 34px; margin: 6px 0 4px; letter-spacing: -0.5px; }
  p { color: #5C5F7A; line-height: 1.45; }
  .code { font-size: 30px; letter-spacing: 3px; font-weight: 800; margin: 18px 0; }
  a.button { display: block; background: #F2994A; color: white; text-decoration: none; font-weight: 800;
             padding: 15px; border-radius: 16px; font-size: 17px; }
  a.second { display: block; margin-top: 14px; color: #F2994A; font-weight: 700; text-decoration: none; }
  .note { font-size: 14px; margin-top: 18px; }
</style>
</head>
<body>
<main>
  <div class="sun">☀️</div>
  <h1>Routines</h1>
  ${
    valid
      ? `<p>Je bent uitgenodigd om mee te doen in een huis.</p>
  <div class="code">${escape(pretty)}</div>
  <a class="button" href="${escape(open)}">Open in Routines</a>
  ${store}
  <p class="note">Werkt de knop niet? Log in de app in en tik de code in bij Instellingen → Ouders en verzorgers.</p>`
      : `<p>Deze link klopt niet. Vraag om een nieuwe code.</p>`
  }
</main>
</body>
</html>
`;
}
