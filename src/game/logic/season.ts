export type Season = "spring" | "summer" | "autumn" | "winter";

/** 端末ローカルの月から季節を決める（3〜5 月: 春、6〜8 月: 夏、9〜11 月: 秋、12〜2 月: 冬）。 */
export function seasonOf(date: Date): Season {
  const m = date.getMonth() + 1;
  if (m >= 3 && m <= 5) return "spring";
  if (m >= 6 && m <= 8) return "summer";
  if (m >= 9 && m <= 11) return "autumn";
  return "winter";
}

export const SEASON_LABEL: Record<Season, string> = { spring: "春", summer: "夏", autumn: "秋", winter: "冬" };
