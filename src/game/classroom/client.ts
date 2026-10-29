// 生徒アプリと塾画面が集計サーバーと話すための窓口。
// NEXT_PUBLIC_CLASSROOM_API が未設定なら「モック」として動き、通信を一切しない（表示にも明示する）。
import {
  CLASSROOM_CODE_PATTERN,
  K_ANONYMITY_DEFAULT,
  PER_DEVICE_DAILY_CAP,
  type ClassroomSummary,
  type DaySummary,
  type MetricsDay,
  type PulseRequest,
  type ReturnRequest,
} from "@/game/classroom/protocol";

export interface ClassroomClient {
  readonly mode: "mock" | "http";
  readonly baseUrl: string | null;
  sendReturn(req: ReturnRequest): Promise<{ counted: boolean }>;
  getPublicSummary(code: string, days?: number): Promise<ClassroomSummary>;
  sendPulse(req: PulseRequest): Promise<{ counted: boolean }>;
  createClassroom(token: string): Promise<{ code: string }>;
  getAdminSummary(code: string, token: string, days?: number): Promise<ClassroomSummary>;
  getMetrics(token: string, days?: number): Promise<{ days: MetricsDay[] }>;
}

export class ClassroomApiError extends Error {
  readonly status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export function isValidClassroomCode(code: string): boolean {
  return CLASSROOM_CODE_PATTERN.test(code);
}

export function normalizeCode(input: string): string {
  const raw = input.toUpperCase().replace(/[^A-Z0-9]/g, "");
  if (raw.length !== 8) return input.toUpperCase().trim();
  return `${raw.slice(0, 4)}-${raw.slice(4)}`;
}

function pad(n: number): string {
  return n < 10 ? `0${n}` : String(n);
}
function dayKeyOf(d: Date): string {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}
function recentDays(count: number, now: Date): string[] {
  const out: string[] = [];
  for (let i = count - 1; i >= 0; i -= 1) {
    const d = new Date(now);
    d.setDate(now.getDate() - i);
    out.push(dayKeyOf(d));
  }
  return out;
}

/** 架空データで合計を見せるための教室コード（モック専用）。 */
export const MOCK_DEMO_CODE = "DEMO-0000";
const MOCK_STORAGE_KEY = "kagami-mock-classroom";

interface MockBucket {
  returns: number;
  hashes: Record<string, number>;
}

/** 通信をしないモック。集計は localStorage に保存し、表示には「モック」と出す。 */
export class MockClassroomClient implements ClassroomClient {
  readonly mode = "mock" as const;
  readonly baseUrl = null;
  private readonly k = K_ANONYMITY_DEFAULT;

  private load(): Record<string, MockBucket> {
    try {
      const raw = globalThis.localStorage?.getItem(MOCK_STORAGE_KEY);
      return raw ? (JSON.parse(raw) as Record<string, MockBucket>) : {};
    } catch {
      return {};
    }
  }
  private save(data: Record<string, MockBucket>): void {
    try {
      globalThis.localStorage?.setItem(MOCK_STORAGE_KEY, JSON.stringify(data));
    } catch {
      // 保存できなくても動作は続く
    }
  }

  async sendReturn(req: ReturnRequest): Promise<{ counted: boolean }> {
    if (!isValidClassroomCode(req.code)) throw new ClassroomApiError(400, "invalid_request");
    const data = this.load();
    const key = `${req.code}:${req.dayKey}`;
    const bucket = (data[key] ??= { returns: 0, hashes: {} });
    const used = bucket.hashes[req.hash] ?? 0;
    if (used >= PER_DEVICE_DAILY_CAP) return { counted: false };
    bucket.hashes[req.hash] = used + 1;
    bucket.returns += 1;
    this.save(data);
    return { counted: true };
  }

  async getPublicSummary(code: string, days = 7): Promise<ClassroomSummary> {
    if (!isValidClassroomCode(code)) throw new ClassroomApiError(400, "invalid_request");
    const keys = recentDays(days, new Date());
    if (code === MOCK_DEMO_CODE) {
      // 架空の教室。数字はすべてデモ
      const demo: DaySummary[] = keys.map((dayKey, i) => ({ dayKey, returns: 12 + ((i * 7) % 11), participants: 9 + (i % 4), suppressed: false }));
      const week = demo.slice(-7);
      return { code, k: this.k, days: demo, weekTotal: week.reduce((s, d) => s + (d.returns ?? 0), 0), weekSuppressedDays: 0 };
    }
    const data = this.load();
    const rows: DaySummary[] = keys.map((dayKey) => {
      const b = data[`${code}:${dayKey}`];
      const participants = b ? Object.keys(b.hashes).length : 0;
      const suppressed = participants < this.k;
      return { dayKey, returns: suppressed ? null : b?.returns ?? 0, participants: suppressed ? null : participants, suppressed };
    });
    const week = rows.slice(-7);
    return { code, k: this.k, days: rows, weekTotal: week.reduce((s, d) => s + (d.returns ?? 0), 0), weekSuppressedDays: week.filter((d) => d.suppressed).length };
  }

  async sendPulse(req: PulseRequest): Promise<{ counted: boolean }> {
    void req; // モックでは送らない
    return { counted: false };
  }

  async createClassroom(token: string): Promise<{ code: string }> {
    if (!token) throw new ClassroomApiError(401, "unauthorized");
    const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    let s = "";
    for (let i = 0; i < 8; i += 1) {
      if (i === 4) s += "-";
      s += alphabet[Math.floor(Math.random() * alphabet.length)];
    }
    return { code: s };
  }

  async getAdminSummary(code: string, token: string, days = 28): Promise<ClassroomSummary> {
    if (!token) throw new ClassroomApiError(401, "unauthorized");
    return this.getPublicSummary(code, days);
  }

  async getMetrics(token: string, days = 28): Promise<{ days: MetricsDay[] }> {
    if (!token) throw new ClassroomApiError(401, "unauthorized");
    return { days: recentDays(days, new Date()).map((dayKey) => ({ dayKey, opens: 0, returns: 0, devices: 0 })) };
  }
}

export class HttpClassroomClient implements ClassroomClient {
  readonly mode = "http" as const;
  readonly baseUrl: string;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl.replace(/\/+$/, "");
  }

  private async call<T>(method: "GET" | "POST", path: string, body?: unknown, token?: string): Promise<T> {
    const headers: Record<string, string> = { "content-type": "application/json" };
    if (token) headers.authorization = `Bearer ${token}`;
    const res = await fetch(`${this.baseUrl}${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
      credentials: "omit",
      cache: "no-store",
    });
    if (!res.ok) {
      let message = res.statusText;
      try {
        message = ((await res.json()) as { error?: string }).error ?? message;
      } catch {
        // 本文なし
      }
      throw new ClassroomApiError(res.status, message);
    }
    return (await res.json()) as T;
  }

  sendReturn(req: ReturnRequest): Promise<{ counted: boolean }> {
    // 送るのは 3 項目だけ（protocol.ts）。それ以外を混ぜない
    return this.call("POST", "/v1/returns", { code: req.code, dayKey: req.dayKey, hash: req.hash });
  }
  getPublicSummary(code: string, days = 7): Promise<ClassroomSummary> {
    return this.call("GET", `/v1/classrooms/${encodeURIComponent(code)}/public?days=${days}`);
  }
  sendPulse(req: PulseRequest): Promise<{ counted: boolean }> {
    return this.call("POST", "/v1/pulse", { dayKey: req.dayKey, hash: req.hash, event: req.event });
  }
  createClassroom(token: string): Promise<{ code: string }> {
    return this.call("POST", "/v1/classrooms", {}, token);
  }
  getAdminSummary(code: string, token: string, days = 28): Promise<ClassroomSummary> {
    return this.call("GET", `/v1/classrooms/${encodeURIComponent(code)}/summary?days=${days}`, undefined, token);
  }
  getMetrics(token: string, days = 28): Promise<{ days: MetricsDay[] }> {
    return this.call("GET", `/v1/metrics/summary?days=${days}`, undefined, token);
  }
}

export const CLASSROOM_API_URL = process.env.NEXT_PUBLIC_CLASSROOM_API?.trim() || null;

export function createClassroomClient(): ClassroomClient {
  return CLASSROOM_API_URL ? new HttpClassroomClient(CLASSROOM_API_URL) : new MockClassroomClient();
}
