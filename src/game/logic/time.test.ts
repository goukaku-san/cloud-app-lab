import { describe, expect, it } from "vitest";
import { dayKeyOf, elapsedMinutes, formatDayKey, formatElapsed } from "@/game/logic/time";

describe("time", () => {
  it("dayKey は端末ローカル日付", () => {
    expect(dayKeyOf(new Date(2026, 0, 5, 23, 59))).toBe("2026-01-05");
    expect(dayKeyOf(new Date(2026, 11, 31, 0, 0))).toBe("2026-12-31");
  });

  it("経過分は切り捨てで負にならない", () => {
    const start = new Date(2026, 9, 29, 10, 0).toISOString();
    expect(elapsedMinutes(start, new Date(2026, 9, 29, 10, 12, 59).toISOString())).toBe(12);
    expect(elapsedMinutes(start, new Date(2026, 9, 29, 9, 0).toISOString())).toBe(0);
    expect(elapsedMinutes("not-a-date", start)).toBe(0);
  });

  it("表示用の整形", () => {
    expect(formatElapsed(5 * 60_000)).toBe("5分");
    expect(formatElapsed(63 * 60_000)).toBe("1時間3分");
    expect(formatDayKey("2026-10-29")).toBe("2026年10月29日");
  });
});
