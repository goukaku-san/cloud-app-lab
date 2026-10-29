// 教室の星図 集計サーバー（フレームワークなし）。docs/07-business-design-v0.2.md の 2 章・6 章に従う。
// - 受け取るのは教室コード・日付・「帰還 1 回」だけ。本文をログに残さない。
// - 塾の画面には k 未満の日の合計を出さない。教室間の比較は出さない。
import { randomBytes } from "node:crypto";
import {
  CLASSROOM_CODE_PATTERN,
  DAY_KEY_PATTERN,
  HASH_PATTERN,
  K_ANONYMITY_DEFAULT,
  PER_DEVICE_DAILY_CAP,
  type ClassroomSummary,
  type DaySummary,
  type MetricsDay,
  type PulseEvent,
} from "../src/game/classroom/protocol.ts";
import type { AggregateStore } from "./store.ts";

export interface AppConfig {
  store: AggregateStore;
  /** 塾のトークン → 塾 ID */
  jukuTokens: Map<string, string>;
  /** 会社用トークン（利用統計の閲覧）。null なら統計は閲覧不可 */
  companyToken: string | null;
  k?: number;
  perHashCap?: number;
  clock?: () => Date;
  allowedOrigin?: string | null;
  rateLimitPerMinute?: number;
}

export interface SimpleRequest {
  method: string;
  path: string;
  query: URLSearchParams;
  headers: Record<string, string | undefined>;
  body: unknown;
  ip: string;
}

export interface SimpleResponse {
  status: number;
  body: unknown;
  headers?: Record<string, string>;
}

function pad(n: number): string {
  return n < 10 ? `0${n}` : String(n);
}

export function dayKeyOf(date: Date): string {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function shiftDay(dayKey: string, delta: number): string {
  const [y, m, d] = dayKey.split("-").map(Number);
  const date = new Date(y, m - 1, d + delta);
  return dayKeyOf(date);
}

function recentDayKeys(today: string, count: number): string[] {
  const keys: string[] = [];
  for (let i = count - 1; i >= 0; i -= 1) keys.push(shiftDay(today, -i));
  return keys;
}

const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // 読み間違えやすい I O 0 1 を除く

export function generateCode(): string {
  const bytes = randomBytes(8);
  let s = "";
  for (let i = 0; i < 8; i += 1) {
    if (i === 4) s += "-";
    s += CODE_ALPHABET[bytes[i] % CODE_ALPHABET.length];
  }
  return s;
}

function json(status: number, body: unknown, headers?: Record<string, string>): SimpleResponse {
  return { status, body, headers };
}

function bearer(req: SimpleRequest): string | null {
  const h = req.headers.authorization ?? req.headers.Authorization;
  if (!h || !h.startsWith("Bearer ")) return null;
  return h.slice("Bearer ".length).trim() || null;
}

export function createApp(cfg: AppConfig) {
  const k = cfg.k ?? K_ANONYMITY_DEFAULT;
  const perHashCap = cfg.perHashCap ?? PER_DEVICE_DAILY_CAP;
  const clock = cfg.clock ?? (() => new Date());
  const limitPerMinute = cfg.rateLimitPerMinute ?? 120;
  const hits = new Map<string, { minute: number; count: number }>();

  function rateLimited(ip: string): boolean {
    const minute = Math.floor(clock().getTime() / 60_000);
    const h = hits.get(ip);
    if (!h || h.minute !== minute) {
      hits.set(ip, { minute, count: 1 });
      if (hits.size > 10_000) hits.clear(); // メモリ上限の簡易対策
      return false;
    }
    h.count += 1;
    return h.count > limitPerMinute;
  }

  function corsHeaders(): Record<string, string> {
    const origin = cfg.allowedOrigin ?? "*";
    return {
      "access-control-allow-origin": origin,
      "access-control-allow-methods": "GET, POST, OPTIONS",
      "access-control-allow-headers": "content-type, authorization",
      "access-control-max-age": "600",
    };
  }

  function toSummary(code: string, days: { dayKey: string; returns: number; participants: number }[]): ClassroomSummary {
    const out: DaySummary[] = days.map((d) => {
      const suppressed = d.participants < k;
      return {
        dayKey: d.dayKey,
        returns: suppressed ? null : d.returns,
        participants: suppressed ? null : d.participants,
        suppressed,
      };
    });
    const week = out.slice(-7);
    return {
      code,
      k,
      days: out,
      weekTotal: week.reduce((sum, d) => sum + (d.returns ?? 0), 0),
      weekSuppressedDays: week.filter((d) => d.suppressed).length,
    };
  }

  function daysParam(req: SimpleRequest, def: number, max: number): number {
    const n = Number(req.query.get("days") ?? def);
    if (!Number.isFinite(n)) return def;
    return Math.max(1, Math.min(max, Math.floor(n)));
  }

  async function handle(req: SimpleRequest): Promise<SimpleResponse> {
    const headers = corsHeaders();
    if (req.method === "OPTIONS") return json(204, null, headers);
    if (rateLimited(req.ip)) return json(429, { error: "too_many_requests" }, headers);

    const today = dayKeyOf(clock());
    const store = cfg.store;

    if (req.method === "GET" && req.path === "/v1/health") {
      return json(200, { ok: true, k, perDeviceDailyCap: perHashCap, today }, headers);
    }

    // 塾: 教室を作る
    if (req.method === "POST" && req.path === "/v1/classrooms") {
      const token = bearer(req);
      const ownerId = token ? cfg.jukuTokens.get(token) : undefined;
      if (!ownerId) return json(401, { error: "unauthorized" }, headers);
      let code = generateCode();
      for (let i = 0; i < 5 && (await store.getClassroom(code)); i += 1) code = generateCode();
      await store.createClassroom({ code, ownerId, createdAt: clock().toISOString() });
      return json(201, { code }, headers);
    }

    // 生徒: 帰還 1 回
    if (req.method === "POST" && req.path === "/v1/returns") {
      const body = (req.body ?? {}) as Partial<{ code: unknown; dayKey: unknown; hash: unknown }>;
      const code = typeof body.code === "string" ? body.code : "";
      const dayKey = typeof body.dayKey === "string" ? body.dayKey : "";
      const hash = typeof body.hash === "string" ? body.hash : "";
      if (!CLASSROOM_CODE_PATTERN.test(code) || !DAY_KEY_PATTERN.test(dayKey) || !HASH_PATTERN.test(hash)) {
        return json(400, { error: "invalid_request" }, headers);
      }
      // 端末の日付はサーバーの前後 1 日まで受け付ける（時差対策）。それ以外は数えない
      if (dayKey < shiftDay(today, -1) || dayKey > shiftDay(today, 1)) return json(200, { counted: false }, headers);
      if (!(await store.getClassroom(code))) return json(404, { error: "classroom_not_found" }, headers);
      const result = await store.recordReturn(code, dayKey, hash, perHashCap);
      await store.purgeHashes(shiftDay(today, -1));
      return json(200, result, headers);
    }

    // 生徒: 自分の教室の合計（k 未満の日は出ない）
    let m = req.path.match(/^\/v1\/classrooms\/([A-Z0-9]{4}-[A-Z0-9]{4})\/public$/);
    if (req.method === "GET" && m) {
      const code = m[1];
      if (!(await store.getClassroom(code))) return json(404, { error: "classroom_not_found" }, headers);
      const days = await store.listDays(code, recentDayKeys(today, daysParam(req, 7, 14)));
      return json(200, toSummary(code, days), headers);
    }

    // 塾: 自分の教室の合計（k 未満の日は出ない。個人は一切出ない）
    m = req.path.match(/^\/v1\/classrooms\/([A-Z0-9]{4}-[A-Z0-9]{4})\/summary$/);
    if (req.method === "GET" && m) {
      const code = m[1];
      const token = bearer(req);
      const ownerId = token ? cfg.jukuTokens.get(token) : undefined;
      if (!ownerId) return json(401, { error: "unauthorized" }, headers);
      const room = await store.getClassroom(code);
      if (!room || room.ownerId !== ownerId) return json(404, { error: "classroom_not_found" }, headers);
      const days = await store.listDays(code, recentDayKeys(today, daysParam(req, 28, 90)));
      return json(200, toSummary(code, days), headers);
    }

    // 本人 opt-in の匿名利用統計
    if (req.method === "POST" && req.path === "/v1/pulse") {
      const body = (req.body ?? {}) as Partial<{ dayKey: unknown; hash: unknown; event: unknown }>;
      const dayKey = typeof body.dayKey === "string" ? body.dayKey : "";
      const hash = typeof body.hash === "string" ? body.hash : "";
      const event = body.event === "open" || body.event === "return" ? (body.event as PulseEvent) : null;
      if (!DAY_KEY_PATTERN.test(dayKey) || !HASH_PATTERN.test(hash) || !event) return json(400, { error: "invalid_request" }, headers);
      if (dayKey < shiftDay(today, -1) || dayKey > shiftDay(today, 1)) return json(200, { counted: false }, headers);
      const result = await store.recordPulse(dayKey, hash, event, event === "open" ? 1 : perHashCap);
      return json(200, result, headers);
    }

    if (req.method === "GET" && req.path === "/v1/metrics/summary") {
      const token = bearer(req);
      if (!cfg.companyToken || token !== cfg.companyToken) return json(401, { error: "unauthorized" }, headers);
      const days: MetricsDay[] = await store.listPulse(recentDayKeys(today, daysParam(req, 28, 90)));
      return json(200, { days }, headers);
    }

    return json(404, { error: "not_found" }, headers);
  }

  return { handle, k, perHashCap };
}
