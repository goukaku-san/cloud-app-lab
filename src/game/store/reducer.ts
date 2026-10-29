import {
  createInitialState,
  DEFAULT_AVATAR,
  DEFAULT_SETTINGS,
  type AvatarConfig,
  type GameState,
  type Quest,
  type SelfReport,
  type Session,
  type Settings,
} from "@/game/types";
import { applyReturn } from "@/game/logic/growth";
import { dayKeyOf } from "@/game/logic/time";

// 純粋なリデューサー。ID と現在時刻は呼び出し側（GameProvider）が渡す。
export type GameAction =
  | { type: "hydrate"; state: GameState }
  | { type: "createPlayer"; id: string; nickname?: string; now: string }
  | { type: "setAvatar"; avatar: AvatarConfig }
  | { type: "updateSettings"; patch: Partial<Omit<Settings, "notifications">> }
  | { type: "markPreviewSeen" }
  | { type: "startSession"; id: string; quest: Quest; now: string }
  | { type: "returnSession"; report: SelfReport; reflection?: string; now: string }
  | { type: "recordAttempt"; id: string; questionId: string; choiceIndex: number; correct: boolean; now: string }
  | { type: "setAttemptThinking"; attemptId: string; thinking: string }
  | { type: "reset" };

/** 保存済みデータに後から追加したフィールドを補う（古い保存データとの互換）。 */
export function normalizeState(saved: GameState): GameState {
  const base = createInitialState();
  return {
    ...base,
    ...saved,
    attempts: Array.isArray(saved.attempts) ? saved.attempts : [],
    player: saved.player
      ? { ...saved.player, settings: { ...DEFAULT_SETTINGS, ...saved.player.settings, notifications: false } }
      : null,
  };
}

export function gameReducer(state: GameState, action: GameAction): GameState {
  switch (action.type) {
    case "hydrate":
      return normalizeState(action.state);

    case "createPlayer": {
      if (state.player) return state;
      const nickname = action.nickname?.trim().slice(0, 20);
      return {
        ...state,
        player: {
          id: action.id,
          nickname: nickname ? nickname : undefined,
          avatar: { ...DEFAULT_AVATAR },
          settings: { ...DEFAULT_SETTINGS },
          createdAt: action.now,
        },
      };
    }

    case "setAvatar":
      if (!state.player) return state;
      return { ...state, player: { ...state.player, avatar: action.avatar } };

    case "updateSettings":
      if (!state.player) return state;
      return {
        ...state,
        player: {
          ...state.player,
          settings: { ...state.player.settings, ...action.patch, notifications: false },
        },
      };

    case "markPreviewSeen":
      return state.previewSeen ? state : { ...state, previewSeen: true };

    case "startSession": {
      if (!state.player || state.activeSessionId) return state;
      const session: Session = {
        id: action.id,
        quest: action.quest,
        dayKey: dayKeyOf(new Date(action.now)),
        startedAt: action.now,
      };
      return { ...state, sessions: [...state.sessions, session], activeSessionId: session.id };
    }

    case "returnSession": {
      const session = state.sessions.find((s) => s.id === state.activeSessionId);
      if (!session) return state;
      const result = applyReturn(state.world, {
        session,
        report: action.report,
        reflection: action.reflection,
        returnedAt: action.now,
      });
      return {
        ...state,
        world: result.world,
        sessions: state.sessions.map((s) => (s.id === session.id ? result.session : s)),
        activeSessionId: null,
        lastChange: result.change,
      };
    }

    case "recordAttempt": {
      if (!state.player) return state;
      const attempt = {
        id: action.id,
        questionId: action.questionId,
        choiceIndex: action.choiceIndex,
        correct: action.correct,
        at: action.now,
      };
      return { ...state, attempts: [...state.attempts, attempt] };
    }

    case "setAttemptThinking":
      return {
        ...state,
        attempts: state.attempts.map((a) => (a.id === action.attemptId ? { ...a, thinking: action.thinking.slice(0, 60) } : a)),
      };

    case "reset":
      return createInitialState();

    default:
      return state;
  }
}
