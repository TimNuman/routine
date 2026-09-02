// Secrets and optional vars that wrangler.toml does not list (so `wrangler
// types` cannot see them). Merged into the generated Env.
interface Env {
  /** Secret. Without it the assistant refuses to read. */
  ANTHROPIC_API_KEY?: string;
  /** Secret, at least 32 characters. Signs our access tokens; without it nobody can sign in. */
  AUTH_SECRET?: string;
  /** Secret, optional. When set, the shared-key path must send it as X-Routine-Key. */
  SLEUTEL?: string;
  /** Optional overrides, mostly for tests. */
  ANTHROPIC_BASE_URL?: string;
  MODEL?: string;
  EFFORT?: string;
}
