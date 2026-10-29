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
  sound: boolean; // 未実装。常に false
  notifications: false; // この版では通知を送らない
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
  activeSessionId: string | null;
  previewSeen: boolean;
  lastChange: ChangeSummary | null;
}

export const DEFAULT_AVATAR: AvatarConfig = { hairStyle: 0, outfitColor: 0, companion: 0 };

export const DEFAULT_SETTINGS: Settings = {
  reduceMotion: false,
  largeText: false,
  sound: false,
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
    activeSessionId: null,
    previewSeen: false,
    lastChange: null,
  };
}
