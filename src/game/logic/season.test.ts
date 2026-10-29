import { describe, expect, it } from "vitest";
import { seasonOf } from "@/game/logic/season";

describe("seasonOf", () => {
  it("月で季節が決まる", () => {
    expect(seasonOf(new Date(2026, 2, 1))).toBe("spring");
    expect(seasonOf(new Date(2026, 4, 31))).toBe("spring");
    expect(seasonOf(new Date(2026, 5, 1))).toBe("summer");
    expect(seasonOf(new Date(2026, 9, 29))).toBe("autumn");
    expect(seasonOf(new Date(2026, 11, 1))).toBe("winter");
    expect(seasonOf(new Date(2026, 1, 28))).toBe("winter");
  });
});
