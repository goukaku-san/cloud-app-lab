import { describe, expect, it } from "vitest";
import { suggestQuests } from "@/game/logic/suggest";
import { QUEST_POOL } from "@/game/content/quests";

describe("suggestQuests", () => {
  it("常に 3 案で、重複せず、休息を含む", () => {
    for (let seed = 0; seed < 20; seed += 1) {
      const s = suggestQuests(QUEST_POOL, seed);
      expect(s).toHaveLength(3);
      expect(new Set(s.map((q) => q.id)).size).toBe(3);
      expect(s.some((q) => q.kind === "rest")).toBe(true);
      expect(s.some((q) => q.estimatedMinutes <= 3 || q.kind === "review")).toBe(true);
    }
  });

  it("seed が変わると候補が巡回する", () => {
    const a = suggestQuests(QUEST_POOL, 0).map((q) => q.id).join(",");
    const b = suggestQuests(QUEST_POOL, 1).map((q) => q.id).join(",");
    expect(a).not.toBe(b);
  });

  it("候補が少なくても落ちない", () => {
    const s = suggestQuests(QUEST_POOL.slice(0, 2), 3);
    expect(s.length).toBeLessThanOrEqual(3);
    expect(s.length).toBeGreaterThan(0);
  });
});
