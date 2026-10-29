// 共創の星図（第 2 段階）のデモ表示用データ。
// すべて架空の値であり、実際の参加者のデータではない。実データの集計公開は安全審査後（設計書 2-F）。
export const STARS_DEMO_IS_FICTIONAL = true;

export interface DemoWeek {
  label: string;
  actions: number; // 架空の「今週の行動回数」
}

export const DEMO_WEEKS: DemoWeek[] = [
  { label: "3 週間前", actions: 180 },
  { label: "2 週間前", actions: 240 },
  { label: "先週", actions: 310 },
  { label: "今週", actions: 120 },
];

/** 架空の参加者数。固定値。 */
export const DEMO_PARTICIPANTS = 42;

/** 星の位置を決定的に生成する（擬似乱数。外部データなし）。 */
export function starPositions(count: number, seed = 7): Array<{ x: number; y: number; r: number }> {
  let s = seed >>> 0;
  const next = () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
  const out: Array<{ x: number; y: number; r: number }> = [];
  for (let i = 0; i < count; i += 1) {
    out.push({ x: 8 + next() * 344, y: 10 + next() * 200, r: 0.8 + next() * 1.6 });
  }
  return out;
}
