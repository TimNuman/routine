// Who is asking. The phone signs in with Apple or Google and sends us the
// id token; we check it against the provider's public keys and hand back two
// tokens of our own: a short-lived access token (a signed JWT, nothing stored)
// and a long-lived refresh token (random, stored hashed, used once).

import { createRemoteJWKSet, errors, jwtVerify, SignJWT } from 'jose';
import type { Provider } from './accounts';

export const ACCESS_TTL_SECONDS = 60 * 60;
export const REFRESH_TTL_DAYS = 90;
const ISSUER = 'routine';
const MIN_SECRET_LENGTH = 32;

export class AuthError extends Error {
  constructor(
    message: string,
    readonly status: 401 | 500 = 401,
  ) {
    super(message);
  }
}

export interface Identity {
  provider: Provider;
  subject: string;
  email: string | null;
}

interface ProviderConfig {
  issuer: string | string[];
  jwks: string;
  audience: (env: Env) => string | undefined;
}

const PROVIDERS: Record<Provider, ProviderConfig> = {
  apple: {
    issuer: 'https://appleid.apple.com',
    jwks: 'https://appleid.apple.com/auth/keys',
    audience: (env) => env.APPLE_BUNDLE_ID,
  },
  google: {
    issuer: ['https://accounts.google.com', 'accounts.google.com'],
    jwks: 'https://www.googleapis.com/oauth2/v3/certs',
    audience: (env) => env.GOOGLE_CLIENT_ID,
  },
};

export function isProvider(value: unknown): value is Provider {
  return value === 'apple' || value === 'google';
}

// The provider's keys, fetched once per isolate and refreshed by jose when an
// unknown key id turns up.
const keySets = new Map<Provider, ReturnType<typeof createRemoteJWKSet>>();

function keySet(provider: Provider) {
  let set = keySets.get(provider);
  if (!set) {
    set = createRemoteJWKSet(new URL(PROVIDERS[provider].jwks));
    keySets.set(provider, set);
  }
  return set;
}

/** Checks an id token from Apple or Google and says who it is about. */
export async function verifyIdToken(provider: Provider, token: string, env: Env): Promise<Identity> {
  const config = PROVIDERS[provider];
  const audience = config.audience(env);
  if (!audience) throw new AuthError(`Sign-in with ${provider} is not configured.`, 500);

  try {
    const { payload } = await jwtVerify(token, keySet(provider), { issuer: config.issuer, audience });
    if (!payload.sub) throw new AuthError('The id token has no subject.');
    const verified = payload.email_verified === true || payload.email_verified === 'true';
    return {
      provider,
      subject: payload.sub,
      email: typeof payload.email === 'string' && verified ? payload.email : null,
    };
  } catch (err) {
    if (err instanceof AuthError) throw err;
    if (err instanceof errors.JOSEError) throw new AuthError(`The id token is not valid: ${err.code}.`);
    throw err;
  }
}

function secret(env: Env): Uint8Array {
  if (!env.AUTH_SECRET || env.AUTH_SECRET.length < MIN_SECRET_LENGTH) {
    throw new AuthError('AUTH_SECRET is missing or too short; sign-in is off.', 500);
  }
  return new TextEncoder().encode(env.AUTH_SECRET);
}

export async function issueAccessToken(userId: string, env: Env): Promise<string> {
  return await new SignJWT({})
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuer(ISSUER)
    .setSubject(userId)
    .setIssuedAt()
    .setExpirationTime(Math.floor(Date.now() / 1000) + ACCESS_TTL_SECONDS)
    .sign(secret(env));
}

/** The user id inside a valid access token, or null. */
export async function readAccessToken(token: string, env: Env): Promise<string | null> {
  try {
    const { payload } = await jwtVerify(token, secret(env), { issuer: ISSUER, algorithms: ['HS256'] });
    return payload.sub ?? null;
  } catch (err) {
    if (err instanceof errors.JOSEError) return null;
    throw err;
  }
}

export function newRefreshToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return base64url(bytes);
}

export async function hashToken(token: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token));
  return base64url(new Uint8Array(digest));
}

export function refreshExpiry(): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + REFRESH_TTL_DAYS);
  return d.toISOString();
}

export function bearer(header: string | undefined): string | null {
  if (!header) return null;
  const [scheme, token] = header.split(' ', 2);
  return scheme?.toLowerCase() === 'bearer' && token ? token : null;
}

function base64url(bytes: Uint8Array): string {
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
