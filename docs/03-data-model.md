# データ構造

実装は `src/game/types.ts`。全データは端末内（IndexedDB `kagami` / store `state` / key `game`）に 1 レコードとして保存する。サーバー送信は行わない。

```ts
type SelfReport = 'done' | 'partial' | 'rest' | 'skip';
type QuestKind = 'study' | 'review' | 'rest';

interface AvatarConfig { hairStyle: 0 | 1 | 2; outfitColor: 0 | 1 | 2 | 3; companion: 0 | 1 | 2 }
interface Settings { reduceMotion: boolean; largeText: boolean; sound: boolean; soundVolume: number; notifications: false }

interface Player { id: string; nickname?: string; avatar: AvatarConfig; settings: Settings; createdAt: string }
interface Quest { id: string; subject: string; title: string; estimatedMinutes: number; kind: QuestKind; difficulty: 1 | 2 | 3 }
interface Session {
  id: string; quest: Quest; dayKey: string;          // dayKey = 端末ローカル日付 YYYY-MM-DD
  startedAt: string; returnedAt?: string;            // ISO 8601（端末時計）
  elapsedMinutes?: number;                           // 記録のみ。成長に影響しない
  selfReport?: SelfReport; reflection?: string;
}
interface WorldState {
  growth: number;              // 累積成長点（単調増加）
  roomStage: number;           // 0〜5
  chapter: number;             // 1〜14（15 日目以降は 14 のままエピローグ巡回）
  unlockedObjects: string[];   // 部屋に現れた物の ID
  storyFlags: Record<string, boolean>;
  activeDays: string[];        // 帰還（skip 以外）があった日の dayKey。連続性は計算しない
  pointsByDay: Record<string, number>; // 1 日上限の判定用
}
interface ChangeSummary {       // 直前の帰還の結果。変化画面の表示用
  sessionId: string; selfReport: SelfReport;
  beforeStage: number; afterStage: number; growthDelta: number; capped: boolean;
  newObjects: string[]; story: { chapter: number; title: string; text: string };
}
interface Question {            // 学習問題（src/game/content/questions.ts に同梱）
  id: string; subject: '数学' | '英語' | '国語' | '理科' | '社会'; gradeBand: string;
  prompt: string; choices: string[]; answerIndex: number; explanation: string;
  reviewed: boolean;             // false のものは画面で「デモ（監修前）」と表示
  source: 'ai-draft' | 'human';  // AI 生成問題の隔離
}
interface Attempt {             // 一問の魔法の記録（端末内のみ、順位・点数化しない）
  id: string; questionId: string; choiceIndex: number; correct: boolean; thinking?: string; at: string;
}
interface ClassroomMembership { code: string; joinedAt: string; consentVersion: string }  // 教室の星図（任意参加）
interface OutboxItem {          // 送信待ち。内容は protocol.ts の 3 項目のみ
  id: string; kind: 'return' | 'pulse'; dayKey: string; hash: string; code?: string; event?: 'open' | 'return';
}
interface GameState {
  version: 1; player: Player | null; world: WorldState; sessions: Session[]; attempts: Attempt[];
  activeSessionId: string | null; previewSeen: boolean; lastChange: ChangeSummary | null;
  classroom: ClassroomMembership | null;
  deviceSecret: string | null;   // 日替わりハッシュの元。端末の外には出さない
  outbox: OutboxItem[]; lastPulseDay: string | null;
}
```

## 設計書 8 章との対応

| 設計書 | 実装 | 備考 |
| --- | --- | --- |
| Player | `Player` | `accessibilitySettings` は `Settings` に統合 |
| Quest | `Quest` | セッションに快照（スナップショット）として保存 |
| Session | `Session` | `selfReport` に `skip` を含む |
| WorldState | `WorldState` | `roomStage` は `growth` から導出。`activeDays` は章の決定にのみ使う |
| Question | `Question` | `reviewed` / `source` で監修前データを隔離。`Attempt` で回答を端末内に記録 |
| Event | 未実装 | プライバシー審査前のため予約のみ |

## 集計サーバーに送るもの（教室の星図）

| 送る | 送らない |
| --- | --- |
| 教室コード、日付、「帰還 1 回」の事実（`src/game/classroom/protocol.ts` の 3 項目） | ニックネーム、ひとこと、自己申告の種類、経過時間、分身、一問の魔法の記録、恒久的な端末 ID |

日替わりハッシュ = SHA-256(端末内の秘密値 : 日付)。翌日には別の値になり、名寄せできない。サーバーは当日分のハッシュだけを 1 日 3 回の上限判定に使い、前日より古い分は消す（`server/store.ts`）。

## 永続化と抽象化

```ts
interface StorageAdapter {
  load(): Promise<GameState | null>;
  save(state: GameState): Promise<void>;
  clear(): Promise<void>;
}
```

- `IndexedDbStorage`: 本番。IndexedDB が使えない環境（プライベートモード等）では `MemoryStorage` にフォールバックし、画面に「この端末では保存できません」と表示する。
- 将来の同期は `StorageAdapter` の実装追加で対応し、画面側は変更しない。
- `version` フィールドでマイグレーションに備える。後から追加したフィールド（`attempts`, `soundVolume`, `classroom`, `outbox` など）は読込時に `normalizeState` が補う。
- 集計サーバー側の保存は `AggregateStore`（`MemoryStore` / `FileStore`）。本番規模では PostgreSQL 実装に差し替える。
