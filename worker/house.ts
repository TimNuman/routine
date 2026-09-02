// One house: everything one household shares, plus the phones watching it.
//
// A Durable Object is the one place that can both keep state and know who is
// connected right now, so a change is pushed to every phone at once and nobody
// polls. The worker talks to it over RPC; only the WebSocket comes in via fetch.

import { DurableObject } from 'cloudflare:workers';
import { dateOr, daysAgo } from './dates';
import type { Checks, Content, HouseEvent, Opening, Routine } from './types';

const KEEP_DAYS = 7;
const CONTENT = 'content';
// Historical prefix; the live house has keys under it, so it stays.
const DAY = 'dag:';

interface Watching {
  date: string;
}

export class House extends DurableObject<Env> {
  async getContent(): Promise<Content | null> {
    return (await this.ctx.storage.get<Content>(CONTENT)) ?? null;
  }

  async putContent(content: Content): Promise<void> {
    await this.ctx.storage.put(CONTENT, content);
    this.broadcast({ kind: 'content', content });
  }

  async getChecks(date: string): Promise<Checks> {
    return (await this.ctx.storage.get<Checks>(DAY + date)) ?? {};
  }

  async setCheck(date: string, key: string, on: boolean): Promise<void> {
    const checks = await this.getChecks(date);
    if (on) checks[key] = true;
    else delete checks[key];
    await this.ctx.storage.put(DAY + date, checks);
    this.broadcast({ kind: 'check', date, key, on });
    await this.sweep();
  }

  async clearRoutine(date: string, routine: Routine): Promise<void> {
    const checks = await this.getChecks(date);
    for (const key of Object.keys(checks)) {
      if (key.startsWith(routine + '/')) delete checks[key];
    }
    await this.ctx.storage.put(DAY + date, checks);
    this.broadcast({ kind: 'routine', date, routine });
  }

  /** The WebSocket. Anything else over fetch is a mistake. */
  override async fetch(request: Request): Promise<Response> {
    if (request.headers.get('Upgrade') !== 'websocket') {
      return new Response('Expected a WebSocket.', { status: 426 });
    }
    const pair = new WebSocketPair();
    const client = pair[0];
    const server = pair[1];
    this.ctx.acceptWebSocket(server);
    const date = dateOr(new URL(request.url).searchParams.get('date'));
    server.serializeAttachment({ date } satisfies Watching);
    server.send(JSON.stringify(await this.opening(date)));
    return new Response(null, { status: 101, webSocket: client });
  }

  /** A phone may switch the day it watches: `{ "kind": "day", "date": "…" }`. */
  override async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    if (typeof message !== 'string') return;
    let raw: unknown;
    try {
      raw = JSON.parse(message);
    } catch {
      return;
    }
    if (!raw || typeof raw !== 'object' || (raw as { kind?: unknown }).kind !== 'day') return;
    const date = dateOr((raw as { date?: unknown }).date);
    ws.serializeAttachment({ date } satisfies Watching);
    ws.send(JSON.stringify(await this.opening(date)));
  }

  override webSocketClose(ws: WebSocket): void {
    try {
      ws.close();
    } catch {
      // Already gone.
    }
  }

  override webSocketError(): void {}

  private async opening(date: string): Promise<Opening> {
    return { kind: 'start', date, content: await this.getContent(), checks: await this.getChecks(date) };
  }

  private broadcast(event: HouseEvent): void {
    const text = JSON.stringify(event);
    for (const ws of this.ctx.getWebSockets()) {
      if ('date' in event && watching(ws).date !== event.date) continue;
      try {
        ws.send(text);
      } catch {
        // A socket that is closing; it will be cleaned up.
      }
    }
  }

  /** Days older than a week are gone tomorrow anyway. */
  private async sweep(): Promise<void> {
    const stale = await this.ctx.storage.list({ prefix: DAY, end: DAY + daysAgo(KEEP_DAYS) });
    if (stale.size) await this.ctx.storage.delete([...stale.keys()]);
  }
}

function watching(ws: WebSocket): Watching {
  try {
    return (ws.deserializeAttachment() as Watching | null) ?? { date: '' };
  } catch {
    return { date: '' };
  }
}
