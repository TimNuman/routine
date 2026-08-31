import { ScrollViewStyleReset } from 'expo-router/html';
import type { PropsWithChildren } from 'react';

// De schil om elke pagina heen. Expo maakt hem zelf als dit bestand er niet is;
// hij staat er alleen om het web-manifest en de iconen erin te hangen, zodat de
// app op het beginscherm gezet kan worden. De bestanden zelf staan in public/
// en worden bij het uitgeven meegekopieerd.
export default function Root({ children }: PropsWithChildren) {
  return (
    <html lang="nl">
      <head>
        <meta charSet="utf-8" />
        <meta httpEquiv="X-UA-Compatible" content="IE=edge" />
        <meta
          name="viewport"
          content="width=device-width, initial-scale=1, shrink-to-fit=no, viewport-fit=cover"
        />
        <meta name="theme-color" content="#F2994A" />
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="default" />
        <link rel="manifest" href="/manifest.webmanifest" />
        <link rel="apple-touch-icon" href="/icon-180.png" />
        <link rel="icon" href="/icon-32.png" sizes="32x32" />
        <link rel="icon" href="/icon.svg" type="image/svg+xml" />
        <ScrollViewStyleReset />
      </head>
      <body>{children}</body>
    </html>
  );
}
