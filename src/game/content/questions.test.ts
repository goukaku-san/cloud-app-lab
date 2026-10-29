import { describe, expect, it } from "vitest";
import { QUESTIONS, THINKING_OPTIONS } from "@/game/content/questions";

describe("学習問題データ", () => {
  it("30 問あり、数学が中心で、ID が重複しない", () => {
    expect(QUESTIONS).toHaveLength(30);
    const math = QUESTIONS.filter((q) => q.subject === "数学").length;
    expect(math).toBeGreaterThanOrEqual(20);
    expect(new Set(QUESTIONS.map((q) => q.id)).size).toBe(QUESTIONS.length);
  });

  it("各問題は 4 択で、正答番号が範囲内、解説がある", () => {
    for (const q of QUESTIONS) {
      expect(q.choices, q.id).toHaveLength(4);
      expect(new Set(q.choices).size, q.id).toBe(4);
      expect(q.answerIndex, q.id).toBeGreaterThanOrEqual(0);
      expect(q.answerIndex, q.id).toBeLessThan(4);
      expect(q.prompt.trim().length, q.id).toBeGreaterThan(5);
      expect(q.explanation.trim().length, q.id).toBeGreaterThan(5);
    }
  });

  it("監修前のデータは reviewed: false / source: ai-draft で隔離されている", () => {
    for (const q of QUESTIONS) {
      if (!q.reviewed) expect(q.source).toBe("ai-draft");
    }
  });

  it("考え方の選択肢に評価的な語がない", () => {
    for (const t of THINKING_OPTIONS) {
      expect(t).not.toMatch(/ダメ|サボ|失敗|えらい|すごい/);
    }
  });
});
