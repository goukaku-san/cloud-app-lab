import type { Quest } from "@/game/types";

/**
 * 作戦会議の 3 案を決定的に選ぶ。
 * 1 案目: 勉強、2 案目: 復習か「小さな一歩」（3 分以下）、3 案目: 休息。
 * seed が変わると候補が巡回し、同じ 3 案ばかりにならない。押し付けはしない。
 */
export function suggestQuests(pool: Quest[], seed: number): Quest[] {
  const s = Math.max(0, Math.floor(seed));
  const study = pool.filter((q) => q.kind === "study" && q.estimatedMinutes > 3);
  const small = pool.filter((q) => q.kind === "review" || q.estimatedMinutes <= 3);
  const rest = pool.filter((q) => q.kind === "rest");

  const pick = (list: Quest[], offset: number, taken: Set<string>): Quest | undefined => {
    if (list.length === 0) return undefined;
    for (let i = 0; i < list.length; i += 1) {
      const q = list[(s + offset + i) % list.length];
      if (!taken.has(q.id)) return q;
    }
    return undefined;
  };

  const taken = new Set<string>();
  const result: Quest[] = [];
  for (const [list, offset] of [
    [study, 0],
    [small, 1],
    [rest, 2],
  ] as const) {
    const q = pick(list, offset, taken);
    if (q) {
      taken.add(q.id);
      result.push(q);
    }
  }
  // 候補が足りないときは残りから補う（最大 3 案）
  for (const q of pool) {
    if (result.length >= 3) break;
    if (!taken.has(q.id)) {
      taken.add(q.id);
      result.push(q);
    }
  }
  return result.slice(0, 3);
}
