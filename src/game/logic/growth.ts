import type { ChangeSummary, SelfReport, Session, WorldState } from "@/game/types";
import { objectsForGrowth, stageForGrowth, subjectObjectId } from "@/game/content/roomStages";
import { STORY_CHAPTERS, storyFor } from "@/game/content/story";
import { dayKeyOf, elapsedMinutes } from "@/game/logic/time";

// 成長の規則（docs/01-implementation-plan.md）。
// - 自己申告ごとに加算。経過時間は一切使わない。
// - 1 日の上限 3 点。上限後も物語と記録は進み、罰はない。
// - 減点は存在しない。連続日数は計算しない。
export const REPORT_POINTS: Record<SelfReport, number> = {
  done: 2,
  partial: 1,
  rest: 1,
  skip: 0,
};

export const MAX_POINTS_PER_DAY = 3;
export const MAX_CHAPTER = STORY_CHAPTERS.length;

export interface ReturnInput {
  session: Session;
  report: SelfReport;
  reflection?: string;
  returnedAt: string;
}

export interface ReturnResult {
  world: WorldState;
  session: Session;
  change: ChangeSummary;
}

export function applyReturn(world: WorldState, input: ReturnInput): ReturnResult {
  const { session, report, returnedAt } = input;
  const dayKey = dayKeyOf(new Date(returnedAt));
  const reflection = input.reflection?.trim() ? input.reflection.trim().slice(0, 140) : undefined;

  const activeDays =
    report === "skip" || world.activeDays.includes(dayKey)
      ? world.activeDays
      : [...world.activeDays, dayKey];
  const dayIndex = Math.max(1, activeDays.length);
  const chapter = Math.min(MAX_CHAPTER, dayIndex);

  const wanted = REPORT_POINTS[report];
  const used = world.pointsByDay[dayKey] ?? 0;
  const granted = Math.max(0, Math.min(wanted, MAX_POINTS_PER_DAY - used));
  const capped = wanted > 0 && granted < wanted;

  const growth = world.growth + granted;
  const afterStage = stageForGrowth(growth);

  const unlocked = new Set(world.unlockedObjects);
  for (const id of objectsForGrowth(growth)) unlocked.add(id);
  const storyFlags = { ...world.storyFlags };
  if (report === "rest" && !storyFlags.firstRest) {
    storyFlags.firstRest = true;
    unlocked.add("blanket");
  }
  // 選んだ行動の教科ではじめて帰還した日に、その教科の物が現れる（やった／少しやった／休んだ のいずれでも）
  if (report !== "skip") {
    const subj = subjectObjectId(session.quest.subject);
    if (subj) unlocked.add(subj);
  }
  const newObjects = [...unlocked].filter((id) => !world.unlockedObjects.includes(id));

  const story = storyFor(chapter, report, dayIndex);

  const nextWorld: WorldState = {
    growth,
    roomStage: afterStage,
    chapter,
    unlockedObjects: [...unlocked],
    storyFlags,
    activeDays,
    pointsByDay: granted > 0 ? { ...world.pointsByDay, [dayKey]: used + granted } : world.pointsByDay,
  };

  const nextSession: Session = {
    ...session,
    returnedAt,
    elapsedMinutes: elapsedMinutes(session.startedAt, returnedAt),
    selfReport: report,
    reflection,
  };

  const change: ChangeSummary = {
    sessionId: session.id,
    selfReport: report,
    beforeStage: world.roomStage,
    afterStage,
    growthDelta: granted,
    capped,
    newObjects,
    story: { chapter, ...story },
  };

  return { world: nextWorld, session: nextSession, change };
}

/** 今日すでに受け取った成長点（上限表示用）。 */
export function pointsUsedToday(world: WorldState, now: Date): number {
  return world.pointsByDay[dayKeyOf(now)] ?? 0;
}
