import { describe, expect, it } from "vitest";
import { CAPPED_NOTE, EPILOGUE, SKIP_STORY, STORY_CHAPTERS, storyFor } from "@/game/content/story";
import { ROOM_OBJECTS, ROOM_STAGES } from "@/game/content/roomStages";
import { QUEST_POOL } from "@/game/content/quests";

// 設計書 4 章: 羞恥・罪悪感を利用する文言、連続記録、評価・叱責を禁止する。
const FORBIDDEN = ["サボ", "罰", "ダメ", "怠", "遅れ", "失敗", "負け", "連続", "ストリーク", "えらい", "すごい", "偉い", "頑張れ", "がんばれ", "ペナルティ", "減点", "ランキング", "順位"];

function allTexts(): string[] {
  const out: string[] = [];
  for (const ch of STORY_CHAPTERS) {
    for (const key of ["done", "partial", "rest"] as const) {
      out.push(ch.stories[key].title, ch.stories[key].text);
    }
  }
  for (const ep of EPILOGUE) {
    for (const key of ["done", "partial", "rest"] as const) out.push(ep[key].title, ep[key].text);
  }
  out.push(SKIP_STORY.title, SKIP_STORY.text, CAPPED_NOTE);
  for (const s of ROOM_STAGES) out.push(s.name, s.description);
  for (const o of ROOM_OBJECTS) out.push(o.name);
  for (const q of QUEST_POOL) out.push(q.title, q.subject);
  return out;
}

describe("物語コンテンツ", () => {
  it("14 章 × 3 申告 + エピローグ 7 本以上のすべてにテキストがある", () => {
    expect(STORY_CHAPTERS).toHaveLength(14);
    STORY_CHAPTERS.forEach((ch, i) => {
      expect(ch.chapter).toBe(i + 1);
      expect(ch.theme.trim().length).toBeGreaterThan(0);
      for (const key of ["done", "partial", "rest"] as const) {
        expect(ch.stories[key].title.trim().length).toBeGreaterThan(0);
        expect(ch.stories[key].text.trim().length).toBeGreaterThan(20);
      }
    });
    // 最終章の翌日以降は 1 週間で一巡させる（3 本だと 3 日で同じ文に戻り、薄い）
    expect(EPILOGUE.length).toBeGreaterThanOrEqual(7);
    for (const ep of EPILOGUE) {
      for (const key of ["done", "partial", "rest"] as const) {
        expect(ep[key].title.trim().length).toBeGreaterThan(0);
        expect(ep[key].text.trim().length).toBeGreaterThan(20);
      }
    }
  });

  it("物語の題名は全部違う（同じ題名が別の日に出ない）", () => {
    const titles: string[] = [];
    for (const ch of STORY_CHAPTERS) for (const key of ["done", "partial", "rest"] as const) titles.push(ch.stories[key].title);
    for (const ep of EPILOGUE) for (const key of ["done", "partial", "rest"] as const) titles.push(ep[key].title);
    expect(new Set(titles).size).toBe(titles.length);
  });

  it("禁止語を含まない", () => {
    for (const t of allTexts()) {
      for (const word of FORBIDDEN) {
        expect(t, `"${t}" に禁止語 "${word}"`).not.toContain(word);
      }
    }
  });

  it("storyFor は章・申告・日数に応じた物語を返す", () => {
    expect(storyFor(1, "done", 1)).toEqual(STORY_CHAPTERS[0].stories.done);
    expect(storyFor(7, "rest", 7)).toEqual(STORY_CHAPTERS[6].stories.rest);
    expect(storyFor(8, "done", 8)).toEqual(STORY_CHAPTERS[7].stories.done);
    expect(storyFor(14, "rest", 14)).toEqual(STORY_CHAPTERS[13].stories.rest);
    expect(storyFor(14, "partial", 15)).toEqual(EPILOGUE[0].partial);
    expect(storyFor(14, "partial", 15 + EPILOGUE.length)).toEqual(EPILOGUE[0].partial);
    expect(storyFor(3, "skip", 3)).toEqual(SKIP_STORY);
  });
});
