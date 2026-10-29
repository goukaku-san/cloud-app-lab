// 教室の星図: 生徒アプリ・塾画面・集計サーバーで共有する取り決め（docs/07-business-design-v0.2.md）。
// 送るのは 3 項目だけ。個人を示す情報は送らない。

export const CLASSROOM_CODE_PATTERN = /^[A-Z0-9]{4}-[A-Z0-9]{4}$/;
export const DAY_KEY_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
export const HASH_PATTERN = /^[0-9a-f]{64}$/;

/** 同意文面の版。文面を変えたら上げる（再同意が必要になる）。 */
export const CONSENT_VERSION = "2026-10-29";

/** 最小表示人数 k（仮置き。専門家確認後に確定。業界の基準ではない）。 */
export const K_ANONYMITY_DEFAULT = 5;

/** 1 端末あたり 1 日に集計へ数える帰還の上限（アプリ内の成長上限と同じ 3）。 */
export const PER_DEVICE_DAILY_CAP = 3;

/** 送られるもの（同意画面にそのまま表示する）。 */
export const SENT_FIELDS = ["教室コード", "日付（端末のローカル日付）", "「帰還 1 回」という事実"] as const;

/** 送られないもの（同意画面にそのまま表示する）。 */
export const NOT_SENT_FIELDS = [
  "ニックネーム",
  "ひとこと（振り返りの文章）",
  "自己申告の種類（やった／少しやった／休んだ）",
  "経過時間と時間帯",
  "分身の設定",
  "一問の魔法の記録",
  "端末を特定できる ID（送るのは日替わりで変わるハッシュだけ）",
] as const;

export interface ReturnRequest {
  code: string;
  dayKey: string;
  hash: string; // 日替わりハッシュ。翌日には同じ端末でも別の値になる
}

export type PulseEvent = "open" | "return";

export interface PulseRequest {
  dayKey: string;
  hash: string;
  event: PulseEvent;
}

export interface DaySummary {
  dayKey: string;
  /** 参加端末が k 未満の日は null（表示しない）。 */
  returns: number | null;
  participants: number | null;
  suppressed: boolean;
}

export interface ClassroomSummary {
  code: string;
  k: number;
  days: DaySummary[];
  weekTotal: number;
  weekSuppressedDays: number;
}

export interface MetricsDay {
  dayKey: string;
  opens: number;
  returns: number;
  devices: number;
}
