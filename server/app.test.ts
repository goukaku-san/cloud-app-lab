import { describe, expect, it } from "vitest";
import { createApp, dayKeyOf, generateCode, type SimpleRequest } from "./app.ts";
import { MemoryStore } from "./store.ts";
import { CLASSROOM_CODE_PATTERN } from "../src/game/classroom/protocol.ts";

const NOW = new Date(2026, 9, 29, 12, 0, 0);
const today = dayKeyOf(NOW);

function makeApp(k = 5) {
  const store = new MemoryStore();
  const app = createApp({
    store,
    jukuTokens: new Map([["tok-a", "juku-a"], ["tok-b", "juku-b"]]),
    companyToken: "company",
    k,
    clock: () => NOW,
    rateLimitPerMinute: 1000,
  });
  return { store, app };
}

function req(partial: Partial<SimpleRequest> & { method: string; path: string }): SimpleRequest {
  return { query: new URLSearchParams(), headers: {}, body: null, ip: "1.1.1.1", ...partial };
}

const hash = (n: number) => n.toString(16).padStart(64, "0");

async function createRoom(app: ReturnType<typeof makeApp>["app"], token = "tok-a"): Promise<string> {
  const res = await app.handle(req({ method: "POST", path: "/v1/classrooms", headers: { authorization: `Bearer ${token}` } }));
  expect(res.status).toBe(201);
  return (res.body as { code: string }).code;
}

describe("教室コード", () => {
  it("形式が正しく、読み間違えやすい文字を含まない", () => {
    for (let i = 0; i < 50; i += 1) {
      const code = generateCode();
      expect(code).toMatch(CLASSROOM_CODE_PATTERN);
      expect(code).not.toMatch(/[IO01]/);
    }
  });
});

describe("帰還の受信", () => {
  it("トークンなしでは教室を作れない", async () => {
    const { app } = makeApp();
    const res = await app.handle(req({ method: "POST", path: "/v1/classrooms" }));
    expect(res.status).toBe(401);
  });

  it("3 項目だけを受け取り、1 端末 1 日 3 回までしか数えない", async () => {
    const { app, store } = makeApp();
    const code = await createRoom(app);
    const results: boolean[] = [];
    for (let i = 0; i < 5; i += 1) {
      const res = await app.handle(req({ method: "POST", path: "/v1/returns", body: { code, dayKey: today, hash: hash(1) } }));
      expect(res.status).toBe(200);
      results.push((res.body as { counted: boolean }).counted);
    }
    expect(results).toEqual([true, true, true, false, false]);
    const snap = store.snapshot();
    const bucket = snap.days[`${code}:${today}`];
    expect(bucket.returns).toBe(3);
    expect(bucket.participants).toBe(1);
    // 保存されているキーは合計・人数・日替わりハッシュだけ
    expect(Object.keys(bucket).sort()).toEqual(["hashes", "participants", "returns"]);
  });

  it("余計な項目を送っても保存されない", async () => {
    const { app, store } = makeApp();
    const code = await createRoom(app);
    await app.handle(
      req({ method: "POST", path: "/v1/returns", body: { code, dayKey: today, hash: hash(2), nickname: "たろう", report: "done", minutes: 30 } }),
    );
    expect(JSON.stringify(store.snapshot())).not.toMatch(/たろう|done|minutes/);
  });

  it("形式が不正なら 400、存在しない教室なら 404、日付が遠いなら数えない", async () => {
    const { app } = makeApp();
    const code = await createRoom(app);
    expect((await app.handle(req({ method: "POST", path: "/v1/returns", body: { code: "bad", dayKey: today, hash: hash(1) } }))).status).toBe(400);
    expect((await app.handle(req({ method: "POST", path: "/v1/returns", body: { code: "ZZZZ-ZZZZ", dayKey: today, hash: hash(1) } }))).status).toBe(404);
    const far = await app.handle(req({ method: "POST", path: "/v1/returns", body: { code, dayKey: "2020-01-01", hash: hash(1) } }));
    expect(far.status).toBe(200);
    expect((far.body as { counted: boolean }).counted).toBe(false);
  });
});

describe("合計の表示（k 未満は出さない）", () => {
  it("参加端末が k 未満の日は null、k 以上で数字が出る", async () => {
    const { app } = makeApp(3);
    const code = await createRoom(app);
    for (let d = 1; d <= 2; d += 1) {
      await app.handle(req({ method: "POST", path: "/v1/returns", body: { code, dayKey: today, hash: hash(d) } }));
    }
    let res = await app.handle(req({ method: "GET", path: `/v1/classrooms/${code}/public` }));
    expect(res.status).toBe(200);
    let body = res.body as { days: Array<{ dayKey: string; returns: number | null; suppressed: boolean }>; weekTotal: number };
    const todayRow = body.days.find((x) => x.dayKey === today);
    expect(todayRow?.suppressed).toBe(true);
    expect(todayRow?.returns).toBeNull();
    expect(body.weekTotal).toBe(0);

    await app.handle(req({ method: "POST", path: "/v1/returns", body: { code, dayKey: today, hash: hash(3) } }));
    res = await app.handle(req({ method: "GET", path: `/v1/classrooms/${code}/public` }));
    body = res.body as typeof body;
    expect(body.days.find((x) => x.dayKey === today)?.returns).toBe(3);
    expect(body.weekTotal).toBe(3);
  });

  it("塾は自分の教室だけ見られ、個人を示す項目が含まれない", async () => {
    const { app } = makeApp(1);
    const code = await createRoom(app, "tok-a");
    await app.handle(req({ method: "POST", path: "/v1/returns", body: { code, dayKey: today, hash: hash(9) } }));
    const mine = await app.handle(req({ method: "GET", path: `/v1/classrooms/${code}/summary`, headers: { authorization: "Bearer tok-a" } }));
    expect(mine.status).toBe(200);
    const text = JSON.stringify(mine.body);
    expect(text).not.toMatch(/"(hash|hashes|nickname|report|elapsed|ip|secret)"/i);
    expect(Object.keys((mine.body as { days: object[] }).days[0]).sort()).toEqual(["dayKey", "participants", "returns", "suppressed"]);
    const other = await app.handle(req({ method: "GET", path: `/v1/classrooms/${code}/summary`, headers: { authorization: "Bearer tok-b" } }));
    expect(other.status).toBe(404);
    const anon = await app.handle(req({ method: "GET", path: `/v1/classrooms/${code}/summary` }));
    expect(anon.status).toBe(401);
  });
});

describe("利用統計（本人 opt-in）", () => {
  it("open は 1 端末 1 日 1 回、return は 3 回まで。閲覧は会社トークンのみ", async () => {
    const { app } = makeApp();
    const open1 = await app.handle(req({ method: "POST", path: "/v1/pulse", body: { dayKey: today, hash: hash(5), event: "open" } }));
    const open2 = await app.handle(req({ method: "POST", path: "/v1/pulse", body: { dayKey: today, hash: hash(5), event: "open" } }));
    expect((open1.body as { counted: boolean }).counted).toBe(true);
    expect((open2.body as { counted: boolean }).counted).toBe(false);
    const denied = await app.handle(req({ method: "GET", path: "/v1/metrics/summary", headers: { authorization: "Bearer tok-a" } }));
    expect(denied.status).toBe(401);
    const ok = await app.handle(req({ method: "GET", path: "/v1/metrics/summary", headers: { authorization: "Bearer company" } }));
    expect(ok.status).toBe(200);
    const row = (ok.body as { days: Array<{ dayKey: string; opens: number; devices: number }> }).days.find((d) => d.dayKey === today);
    expect(row?.opens).toBe(1);
    expect(row?.devices).toBe(1);
  });
});

describe("保護", () => {
  it("同じ IP からの過剰な要求は 429", async () => {
    const store = new MemoryStore();
    const app = createApp({ store, jukuTokens: new Map(), companyToken: null, clock: () => NOW, rateLimitPerMinute: 3 });
    const statuses: number[] = [];
    for (let i = 0; i < 5; i += 1) statuses.push((await app.handle(req({ method: "GET", path: "/v1/health" }))).status);
    expect(statuses).toEqual([200, 200, 200, 429, 429]);
  });

  it("前日より古い日のハッシュ表は消え、合計は残る", async () => {
    const { app, store } = makeApp(1);
    const code = await createRoom(app);
    const yesterday = dayKeyOf(new Date(2026, 9, 28));
    await app.handle(req({ method: "POST", path: "/v1/returns", body: { code, dayKey: yesterday, hash: hash(7) } }));
    await store.purgeHashes(today);
    const bucket = store.snapshot().days[`${code}:${yesterday}`];
    expect(bucket.returns).toBe(1);
    expect(bucket.participants).toBe(1);
    expect(bucket.hashes).toEqual({});
  });
});
