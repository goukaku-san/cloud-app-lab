// 受験生の鏡: データモデル（docs/03-data-model.md と対応）
// すべて端末内に保存する。サーバー送信は行わない。

export type SelfReport = "done" | "partial" | "rest" | "skip";
export type QuestKind = "study" | "review" | "rest";

export interface AvatarConfig {
  hairStyle: 0 | 1 | 2;
  outfitColor: 0 | 1 | 2 | 3;
  companion: 0 | 1 | 2;
}

export interface Settings {
  reduceMotion: boolean;
  largeText: boolean;
  sound: boolean; // 実験機能: 端末内で合成する静かな環境音（初期 OFF）
  soundVolume: number; // 0〜1
  shareUsage: boolean; // 本人 opt-in の匿名利用統計（初期 OFF。接続先がなければ何も送らない）
  notifications: false; // この版では通知を送らない
}

/** 教室の星図への参加（任意）。塾に渡るのは教室単位の匿名の合計だけ。 */
export interface ClassroomMembership {
  code: string;
  joinedAt: string;
  consentVersion: string;
}

/** 送信待ち。オフラインでも失わず、接続後に送る。内容は protocol.ts の 3 項目のみ。 */
export interface OutboxItem {
  id: string;
  kind: "return" | "pulse";
  dayKey: string;
  hash: string;
  code?: string; // kind: return のとき
  event?: "open" | "return"; // kind: pulse のとき
}

export interface Player {
  id: string;
  nickname?: string;
  avatar: AvatarConfig;
  settings: Settings;
  createdAt: string;
}

export interface Quest {
  id: string;
  subject: string;
  title: string;
  estimatedMinutes: number;
  kind: QuestKind;
  difficulty: 1 | 2 | 3;
}

export interface Session {
  id: string;
  quest: Quest;
  dayKey: string;
  startedAt: string;
  returnedAt?: string;
  elapsedMinutes?: number;
  selfReport?: SelfReport;
  reflection?: string;
}

export interface WorldState {
  growth: number;
  roomStage: number;
  chapter: number;
  unlockedObjects: string[];
  storyFlags: Record<string, boolean>;
  activeDays: string[];
  pointsByDay: Record<string, number>;
}

export type Subject = "数学" | "英語" | "国語" | "理科" | "社会";

export interface Question {
  id: string;
  subject: Subject;
  gradeBand: string; // 例: "中1", "中3", "高1"
  prompt: string;
  choices: string[];
  answerIndex: number;
  explanation: string;
  reviewed: boolean; // 人手の監修を受けたか。false のものは画面で「デモ（監修前）」と明示する
  source: "ai-draft" | "human";
}

export interface Attempt {
  id: string;
  questionId: string;
  choiceIndex: number;
  correct: boolean;
  thinking?: string; // 考え方の言語化（任意）
  at: string;
}

export interface StoryEntry {
  title: string;
  text: string;
}

export interface ChangeSummary {
  sessionId: string;
  selfReport: SelfReport;
  beforeStage: number;
  afterStage: number;
  growthDelta: number;
  capped: boolean;
  newObjects: string[];
  story: StoryEntry & { chapter: number };
}

export const GAME_STATE_VERSION = 1 as const;

export interface GameState {
  version: typeof GAME_STATE_VERSION;
  player: Player | null;
  world: WorldState;
  sessions: Session[];
  attempts: Attempt[];
  activeSessionId: string | null;
  previewSeen: boolean;
  lastChange: ChangeSummary | null;
  classroom: ClassroomMembership | null;
  deviceSecret: string | null; // 日替わりハッシュの元。端末の外には出さない
  outbox: OutboxItem[];
  lastPulseDay: string | null;
}

export const DEFAULT_AVATAR: AvatarConfig = { hairStyle: 0, outfitColor: 0, companion: 0 };

export const DEFAULT_SETTINGS: Settings = {
  reduceMotion: false,
  largeText: false,
  sound: false,
  soundVolume: 0.5,
  shareUsage: false,
  notifications: false,
};

export function createInitialWorld(): WorldState {
  return {
    growth: 0,
    roomStage: 0,
    chapter: 1,
    unlockedObjects: [],
    storyFlags: {},
    activeDays: [],
    pointsByDay: {},
  };
}

export function createInitialState(): GameState {
  return {
    version: GAME_STATE_VERSION,
    player: null,
    world: createInitialWorld(),
    sessions: [],
    attempts: [],
    activeSessionId: null,
    previewSeen: false,
    lastChange: null,
    classroom: null,
    deviceSecret: null,
    outbox: [],
    lastPulseDay: null,
  };
}
