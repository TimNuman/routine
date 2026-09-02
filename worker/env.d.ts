// Secrets and optional vars that wrangler.toml does not list (so `wrangler
// types` cannot see them). Merged into the generated Env.
interface Env {
  /** Secret. Without it the assistant refuses to read. */
  ANTHROPIC_API_KEY?: string;
  /** Secret, optional. When set, every /api request must send it as X-Routine-Key. */
  SLEUTEL?: string;
  /** Optional overrides, mostly for tests. */
  ANTHROPIC_BASE_URL?: string;
  MODEL?: string;
  EFFORT?: string;
}
