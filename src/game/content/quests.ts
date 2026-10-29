import type { Quest } from "@/game/types";

// 作戦会議の候補。提案はルールベースであり、AI は使っていない（docs/00 R2）。
export const QUEST_POOL: Quest[] = [
  { id: "math10", subject: "数学", title: "数学を10分", estimatedMinutes: 10, kind: "study", difficulty: 2 },
  { id: "math-one", subject: "数学", title: "例題を1つ解く", estimatedMinutes: 10, kind: "study", difficulty: 2 },
  { id: "words5", subject: "英語", title: "英単語を5個", estimatedMinutes: 5, kind: "study", difficulty: 1 },
  { id: "readaloud", subject: "国語", title: "音読を5分", estimatedMinutes: 5, kind: "study", difficulty: 1 },
  { id: "science10", subject: "理科", title: "まとめを10分読む", estimatedMinutes: 10, kind: "study", difficulty: 2 },
  { id: "history5", subject: "社会", title: "年表を5分ながめる", estimatedMinutes: 5, kind: "study", difficulty: 1 },
  { id: "open-book", subject: "どれでも", title: "教科書を開くだけ", estimatedMinutes: 1, kind: "study", difficulty: 1 },
  { id: "mistake1", subject: "復習", title: "昨日の間違いを1問", estimatedMinutes: 5, kind: "review", difficulty: 1 },
  { id: "notes3", subject: "復習", title: "今日のノートを3分見返す", estimatedMinutes: 3, kind: "review", difficulty: 1 },
  { id: "past-q", subject: "復習", title: "前に解けた問題をもう一度", estimatedMinutes: 10, kind: "review", difficulty: 2 },
  { id: "rest10", subject: "休息", title: "休息する", estimatedMinutes: 10, kind: "rest", difficulty: 1 },
  { id: "walk", subject: "休息", title: "外の空気を吸う", estimatedMinutes: 10, kind: "rest", difficulty: 1 },
  { id: "stretch", subject: "休息", title: "ストレッチと深呼吸", estimatedMinutes: 5, kind: "rest", difficulty: 1 },
];

export const KIND_LABEL: Record<Quest["kind"], string> = {
  study: "勉強",
  review: "復習",
  rest: "休息",
};

export const MIN_QUEST_MINUTES = 1;
export const MAX_QUEST_MINUTES = 90;
