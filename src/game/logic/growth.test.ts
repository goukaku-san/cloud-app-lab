import { describe, expect, it } from "vitest";
import { applyReturn, MAX_POINTS_PER_DAY, REPORT_POINTS } from "@/game/logic/growth";
import { createInitialWorld, type SelfReport, type Session, type WorldState } from "@/game/types";
import { stageForGrowth, STAGE_THRESHOLDS } from "@/game/content/roomStages";
import { EPILOGUE, STORY_CHAPTERS } from "@/game/content/story";

function localIso(day: number, hour = 12, minute = 0): string {
  return new Date(2026, 9, day, hour, minute, 0).toISOString();
}

function makeSession(startedAt: string, id = "s1"): Session {
  return {
    id,
    quest: { id: "math10", subject: "数学", title: "数学を10分", estimatedMinutes: 10, kind: "study", difficulty: 2 },
    dayKey: "ignored",
    startedAt,
  };
}

function run(world: WorldState, report: SelfReport, day: number, hour = 12, minute = 10) {
  return applyReturn(world, { session: makeSession(localIso(day, hour, 0)), report, returnedAt: localIso(day, hour, minute) });
}

describe("applyReturn: 成長点", () => {
  it("自己申告ごとに決まった点を加算する", () => {
    for (const report of ["done", "partial", "rest", "skip"] as const) {
      const r = run(createInitialWorld(), report, 1);
      expect(r.change.growthDelta).toBe(REPORT_POINTS[report]);
      expect(r.world.growth).toBe(REPORT_POINTS[report]);
    }
  });

  it("1 日の上限を超えない。上限後も罰や減点はない", () => {
    let world = createInitialWorld();
    const deltas: number[] = [];
    let capped = false;
    for (let i = 0; i < 4; i += 1) {
      const r = run(world, "done", 1, 10 + i);
      deltas.push(r.change.growthDelta);
      capped = r.change.capped;
      world = r.world;
    }
    expect(world.growth).toBe(MAX_POINTS_PER_DAY);
    expect(deltas).toEqual([2, 1, 0, 0]);
    expect(capped).toBe(true);
    // 上限後も物語はある
    const again = run(world, "done", 1, 20);
    expect(again.change.story.text.length).toBeGreaterThan(0);
    expect(again.world.growth).toBe(MAX_POINTS_PER_DAY);
  });

  it("翌日になれば上限が戻る", () => {
    let world = createInitialWorld();
    world = run(world, "done", 1).world;
    world = run(world, "done", 1, 15).world;
    expect(world.growth).toBe(3);
    const next = run(world, "done", 2);
    expect(next.change.growthDelta).toBe(2);
    expect(next.world.growth).toBe(5);
  });

  it("経過時間は成長に影響しない", () => {
    const short = applyReturn(createInitialWorld(), {
      session: makeSession(localIso(1, 12, 0)),
      report: "done",
      returnedAt: localIso(1, 12, 1),
    });
    const long = applyReturn(createInitialWorld(), {
      session: makeSession(localIso(1, 1, 0)),
      report: "done",
      returnedAt: localIso(1, 23, 0),
    });
    expect(short.world.growth).toBe(long.world.growth);
    expect(short.world.roomStage).toBe(long.world.roomStage);
    expect(short.session.elapsedMinutes).toBe(1);
    expect(long.session.elapsedMinutes).toBe(22 * 60);
  });

  it("成長は単調増加で、休んでも記録しなくても減らない", () => {
    let world = createInitialWorld();
    const reports: SelfReport[] = ["done", "rest", "skip", "partial", "rest", "skip", "done", "done", "rest"];
    let prev = 0;
    reports.forEach((report, i) => {
      world = run(world, report, 1 + i).world;
      expect(world.growth).toBeGreaterThanOrEqual(prev);
      prev = world.growth;
    });
  });
});

describe("部屋の段階", () => {
  it("しきい値で段階が決まる", () => {
    expect(stageForGrowth(0)).toBe(0);
    expect(stageForGrowth(1)).toBe(1);
    expect(stageForGrowth(2)).toBe(1);
    expect(stageForGrowth(3)).toBe(2);
    expect(stageForGrowth(6)).toBe(3);
    expect(stageForGrowth(10)).toBe(4);
    expect(stageForGrowth(15)).toBe(5);
    expect(stageForGrowth(999)).toBe(STAGE_THRESHOLDS.length - 1);
  });

  it("最初の帰還で必ず目に見える変化がある（やった / 少しやった / 休んだ）", () => {
    for (const report of ["done", "partial", "rest"] as const) {
      const r = run(createInitialWorld(), report, 1);
      expect(r.change.newObjects.length).toBeGreaterThan(0);
      expect(r.change.afterStage).toBeGreaterThanOrEqual(1);
    }
  });

  it("はじめて休んだ日にひざ掛けが現れ、二度目は重複しない", () => {
    const first = run(createInitialWorld(), "rest", 1);
    expect(first.change.newObjects).toContain("blanket");
    expect(first.world.storyFlags.firstRest).toBe(true);
    const second = run(first.world, "rest", 2);
    expect(second.change.newObjects).not.toContain("blanket");
    expect(second.world.unlockedObjects.filter((o) => o === "blanket")).toHaveLength(1);
  });
});

describe("章と物語", () => {
  it("章は帰還した日数で進み、記録しない日は数えない", () => {
    let world = createInitialWorld();
    world = run(world, "done", 1).world;
    expect(world.chapter).toBe(1);
    world = run(world, "partial", 1, 18).world;
    expect(world.chapter).toBe(1);
    world = run(world, "skip", 2).world;
    expect(world.chapter).toBe(1);
    world = run(world, "rest", 3).world;
    expect(world.chapter).toBe(2);
  });

  it("8 日目以降はエピローグを巡回し、章は 7 のまま", () => {
    let world = createInitialWorld();
    for (let d = 1; d <= 7; d += 1) world = run(world, "done", d).world;
    expect(world.chapter).toBe(STORY_CHAPTERS.length);
    const day8 = run(world, "done", 8);
    expect(day8.world.chapter).toBe(7);
    expect(day8.change.story.title).toBe(EPILOGUE[0].done.title);
    const day9 = run(day8.world, "rest", 9);
    expect(day9.change.story.title).toBe(EPILOGUE[1].rest.title);
  });

  it("どの申告でも短い物語が返る", () => {
    for (const report of ["done", "partial", "rest", "skip"] as const) {
      const r = run(createInitialWorld(), report, 1);
      expect(r.change.story.title.length).toBeGreaterThan(0);
      expect(r.change.story.text.length).toBeGreaterThan(10);
    }
  });

  it("ひとことは前後の空白を除き 140 字に収める", () => {
    const r = applyReturn(createInitialWorld(), {
      session: makeSession(localIso(1)),
      report: "done",
      reflection: `  ${"あ".repeat(200)}  `,
      returnedAt: localIso(1, 12, 5),
    });
    expect(r.session.reflection).toHaveLength(140);
    const empty = applyReturn(createInitialWorld(), {
      session: makeSession(localIso(1)),
      report: "done",
      reflection: "   ",
      returnedAt: localIso(1, 12, 5),
    });
    expect(empty.session.reflection).toBeUndefined();
  });
});
