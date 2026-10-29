import type { SelfReport } from "@/game/types";

export const REPORT_LABEL: Record<SelfReport, string> = {
  done: "やった",
  partial: "少しやった",
  rest: "今日は休んだ",
  skip: "記録なし",
};
