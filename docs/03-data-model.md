# データ構造

実装は `src/game/types.ts`。全データは端末内（IndexedDB `kagami` / store `state` / key `game`）に 1 レコードとして保存する。サーバー送信は行わない。

```ts
type SelfReport = 'done' | 'partial' | 'rest' | 'skip';
type QuestKind = 'study' | 'review' | 'rest';

interface AvatarConfig { hairStyle: 0 | 1 | 2; outfitColor: 0 | 1 | 2 | 3; companion: 0 | 1 | 2 }
interface Settings { reduceMotion: boolean; largeText: boolean; sound: boolean; notifications: false }

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
  chapter: number;             // 1〜7（8 日目以降は 7 のままエピローグ巡回）
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
interface GameState {
  version: 1; player: Player | null; world: WorldState; sessions: Session[];
  activeSessionId: string | null; previewSeen: boolean; lastChange: ChangeSummary | null;
}
```

## 設計書 8 章との対応

| 設計書 | 実装 | 備考 |
| --- | --- | --- |
| Player | `Player` | `accessibilitySettings` は `Settings` に統合 |
| Quest | `Quest` | セッションに快照（スナップショット）として保存 |
| Session | `Session` | `selfReport` に `skip` を含む |
| WorldState | `WorldState` | `roomStage` は `growth` から導出。`activeDays` は章の決定にのみ使う |
| Question | 未実装 | 監修済みデータ入手後に追加 |
| Event | 未実装 | プライバシー審査前のため予約のみ |

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
- `version` フィールドでマイグレーションに備える。
