import { cloudflareTest, readD1Migrations } from '@cloudflare/vitest-pool-workers';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  plugins: [
    cloudflareTest(async () => ({
      wrangler: { configPath: './wrangler.toml' },
      miniflare: {
        bindings: {
          HOUSEHOLD: 'test-house',
          ANTHROPIC_API_KEY: 'test-key',
          AUTH_SECRET: 'test-secret-that-is-long-enough-to-sign-with',
          GOOGLE_CLIENT_ID: 'google-test-client',
          TEST_MIGRATIONS: await readD1Migrations('migrations'),
        },
      },
    })),
  ],
  test: {
    setupFiles: ['./worker/test-setup.ts'],
  },
});
