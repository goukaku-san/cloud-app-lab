import { describe, expect, it } from "vitest";
import { dayHash, randomSecret } from "@/game/classroom/hash";
import { HASH_PATTERN } from "@/game/classroom/protocol";
import { MockClassroomClient, MOCK_DEMO_CODE, normalizeCode } from "@/game/classroom/client";

describe("日替わりハッシュ", () => {
  it("同じ秘密値と日付なら同じ値、日付が変わると別の値", async () => {
    const secret = randomSecret();
    const a = await dayHash(secret, "2026-10-29");
    const b = await dayHash(secret, "2026-10-29");
    const c = await dayHash(secret, "2026-10-30");
    expect(a).toBe(b);
    expect(a).not.toBe(c);
    expect(a).toMatch(HASH_PATTERN);
  });

  it("別の端末（別の秘密値）なら別の値", async () => {
    const a = await dayHash(randomSecret(), "2026-10-29");
    const b = await dayHash(randomSecret(), "2026-10-29");
    expect(a).not.toBe(b);
  });
});

describe("教室コードの整形", () => {
  it("小文字や区切りなしを整える", () => {
    expect(normalizeCode("abcd1234")).toBe("ABCD-1234");
    expect(normalizeCode(" abcd-1234 ")).toBe("ABCD-1234");
    expect(normalizeCode("abc")).toBe("ABC");
  });
});

describe("モッククライアント", () => {
  it("通信せずに集計し、k 未満は表示しない。デモ教室は架空の数字を返す", async () => {
    const client = new MockClassroomClient();
    const r1 = await client.sendReturn({ code: "ABCD-2345", dayKey: "2026-10-29", hash: "a".repeat(64) });
    expect(r1.counted).toBe(true);
    const summary = await client.getPublicSummary("ABCD-2345");
    expect(summary.days.every((d) => d.suppressed)).toBe(true);
    const demo = await client.getPublicSummary(MOCK_DEMO_CODE);
    expect(demo.weekTotal).toBeGreaterThan(0);
    expect(demo.days.every((d) => !d.suppressed)).toBe(true);
    expect((await client.sendPulse({ dayKey: "2026-10-29", hash: "a".repeat(64), event: "open" })).counted).toBe(false);
  });
});
