import { describe, expect, it } from "vitest";
import { pickQuestion } from "@/game/logic/quiz";
import { QUESTIONS } from "@/game/content/questions";
import type { Attempt } from "@/game/types";

const attempt = (questionId: string, i: number): Attempt => ({ id: `a${i}`, questionId, choiceIndex: 0, correct: true, at: "2026-10-29T00:00:00.000Z" });

describe("pickQuestion", () => {
  it("未回答の問題を優先する", () => {
    const attempts = QUESTIONS.slice(0, 29).map((q, i) => attempt(q.id, i));
    expect(pickQuestion(QUESTIONS, attempts, 7)?.id).toBe(QUESTIONS[29].id);
  });

  it("全問解いたら回数の少ない問題から巡回する", () => {
    const all = QUESTIONS.map((q, i) => attempt(q.id, i));
    const twice = [...all, attempt(QUESTIONS[0].id, 99)];
    const picked = pickQuestion(QUESTIONS, twice, 0);
    expect(picked?.id).not.toBe(QUESTIONS[0].id);
  });

  it("空なら null", () => {
    expect(pickQuestion([], [], 0)).toBeNull();
  });
});
