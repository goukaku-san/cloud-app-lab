import type { Attempt, Question } from "@/game/types";

/**
 * 次に出す問題を決定的に選ぶ。
 * まだ解いていない問題を優先し、全部解いたら解いた回数が少ない順。seed で巡回する。
 */
export function pickQuestion(questions: Question[], attempts: Attempt[], seed: number): Question | null {
  if (questions.length === 0) return null;
  const counts = new Map<string, number>();
  for (const a of attempts) counts.set(a.questionId, (counts.get(a.questionId) ?? 0) + 1);
  const minCount = Math.min(...questions.map((q) => counts.get(q.id) ?? 0));
  const candidates = questions.filter((q) => (counts.get(q.id) ?? 0) === minCount);
  return candidates[Math.max(0, Math.floor(seed)) % candidates.length];
}
