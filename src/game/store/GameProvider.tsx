"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useReducer,
  useRef,
  useState,
  type ReactNode,
} from "react";
import { createInitialState, type AvatarConfig, type GameState, type Quest, type SelfReport, type Settings } from "@/game/types";
import { createClassroomClient, type ClassroomClient } from "@/game/classroom/client";
import { dayHash, randomSecret } from "@/game/classroom/hash";
import { CONSENT_VERSION } from "@/game/classroom/protocol";
import { dayKeyOf } from "@/game/logic/time";
import { gameReducer } from "@/game/store/reducer";
import { createStorage, type StorageAdapter } from "@/game/store/storage";
import { deviceClock, type Clock } from "@/game/logic/clock";

export interface GameContextValue {
  state: GameState;
  ready: boolean;
  persistent: boolean;
  clock: Clock;
  createPlayer: (nickname?: string) => void;
  setAvatar: (avatar: AvatarConfig) => void;
  updateSettings: (patch: Partial<Omit<Settings, "notifications">>) => void;
  markPreviewSeen: () => void;
  startSession: (quest: Quest) => void;
  returnFromSession: (report: SelfReport, reflection?: string) => void;
  recordAttempt: (questionId: string, choiceIndex: number, correct: boolean) => string;
  setAttemptThinking: (attemptId: string, thinking: string) => void;
  classroomClient: ClassroomClient;
  joinClassroom: (code: string) => void;
  leaveClassroom: () => void;
  resetAll: () => Promise<void>;
}

const GameContext = createContext<GameContextValue | null>(null);

function newId(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) return crypto.randomUUID();
  return `id-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}

export function GameProvider({
  children,
  clock = deviceClock,
  classroomClient: clientProp,
}: {
  children: ReactNode;
  clock?: Clock;
  classroomClient?: ClassroomClient;
}) {
  const [state, dispatch] = useReducer(gameReducer, undefined, createInitialState);
  const [ready, setReady] = useState(false);
  const [persistent, setPersistent] = useState(true);
  const adapterRef = useRef<StorageAdapter | null>(null);
  const hydratedRef = useRef(false);
  const stateRef = useRef(state);
  useEffect(() => {
    stateRef.current = state;
  }, [state]);
  const [classroomClient] = useState<ClassroomClient>(() => clientProp ?? createClassroomClient());
  const [onlineTick, setOnlineTick] = useState(0);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const handle = await createStorage();
      if (cancelled) return;
      adapterRef.current = handle.adapter;
      setPersistent(handle.persistent);
      try {
        const saved = await handle.adapter.load();
        if (cancelled) return;
        if (saved) dispatch({ type: "hydrate", state: saved });
      } catch {
        // 読み込みに失敗しても初期状態で続行する（画面で保存不可を案内）
        setPersistent(false);
      }
      hydratedRef.current = true;
      setReady(true);
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  // 状態が変わるたびに端末内へ保存する
  useEffect(() => {
    if (!hydratedRef.current || !adapterRef.current) return;
    adapterRef.current.save(state).catch(() => setPersistent(false));
  }, [state]);

  // アクセシビリティ設定を <html> のクラスに反映する
  useEffect(() => {
    const root = document.documentElement;
    const s = state.player?.settings;
    root.classList.toggle("reduce-motion", Boolean(s?.reduceMotion));
    root.classList.toggle("large-text", Boolean(s?.largeText));
  }, [state.player?.settings]);

  const nowIso = useCallback(() => clock.now().toISOString(), [clock]);

  const createPlayer = useCallback(
    (nickname?: string) => dispatch({ type: "createPlayer", id: newId(), nickname, now: nowIso() }),
    [nowIso],
  );
  const setAvatar = useCallback((avatar: AvatarConfig) => dispatch({ type: "setAvatar", avatar }), []);
  const updateSettings = useCallback(
    (patch: Partial<Omit<Settings, "notifications">>) =>
      dispatch({ type: "updateSettings", patch, secretIfNeeded: patch.shareUsage ? randomSecret() : undefined }),
    [],
  );
  const markPreviewSeen = useCallback(() => dispatch({ type: "markPreviewSeen" }), []);
  const startSession = useCallback(
    (quest: Quest) => dispatch({ type: "startSession", id: newId(), quest, now: nowIso() }),
    [nowIso],
  );
  const returnFromSession = useCallback(
    (report: SelfReport, reflection?: string) => {
      const now = nowIso();
      dispatch({ type: "returnSession", report, reflection, now });
      if (report === "skip") return;
      // 教室に参加していれば「帰還 1 回」を送信待ちに入れる（3 項目のみ）。利用統計 opt-in も同様
      const current = stateRef.current;
      const dayKey = dayKeyOf(new Date(now));
      const secret = current.deviceSecret;
      if (!secret) return;
      void dayHash(secret, dayKey).then((hash) => {
        if (current.classroom) {
          dispatch({ type: "outboxAdd", item: { id: newId(), kind: "return", dayKey, hash, code: current.classroom.code } });
        }
        if (current.player?.settings.shareUsage) {
          dispatch({ type: "outboxAdd", item: { id: newId(), kind: "pulse", dayKey, hash, event: "return" } });
        }
      });
    },
    [nowIso],
  );
  const joinClassroom = useCallback(
    (code: string) => dispatch({ type: "joinClassroom", code, secret: randomSecret(), consentVersion: CONSENT_VERSION, now: nowIso() }),
    [nowIso],
  );
  const leaveClassroom = useCallback(() => dispatch({ type: "leaveClassroom" }), []);

  // 送信待ちを流す（オンラインになったときも再試行）
  useEffect(() => {
    const onOnline = () => setOnlineTick((t) => t + 1);
    window.addEventListener("online", onOnline);
    return () => window.removeEventListener("online", onOnline);
  }, []);
  useEffect(() => {
    if (!ready || state.outbox.length === 0) return;
    if (typeof navigator !== "undefined" && navigator.onLine === false) return;
    let cancelled = false;
    (async () => {
      for (const item of state.outbox) {
        if (cancelled) return;
        try {
          if (item.kind === "return" && item.code) {
            await classroomClient.sendReturn({ code: item.code, dayKey: item.dayKey, hash: item.hash });
          } else if (item.kind === "pulse" && item.event) {
            await classroomClient.sendPulse({ dayKey: item.dayKey, hash: item.hash, event: item.event });
          }
          dispatch({ type: "outboxRemove", ids: [item.id] });
        } catch (e) {
          // 4xx は再送しても通らないので捨てる。それ以外（通信断）は残して後で再試行
          const status = (e as { status?: number }).status;
          if (status && status >= 400 && status < 500) dispatch({ type: "outboxRemove", ids: [item.id] });
          return;
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [ready, state.outbox, classroomClient, onlineTick]);

  // 利用統計 opt-in: 1 日 1 回「開いた」を送る（接続先がなければ送らない）
  useEffect(() => {
    if (!ready || !state.player?.settings.shareUsage || classroomClient.mode !== "http") return;
    const today = dayKeyOf(clock.now());
    if (state.lastPulseDay === today) return;
    const secret = state.deviceSecret;
    if (!secret) return;
    let cancelled = false;
    void dayHash(secret, today).then((hash) => {
      if (cancelled) return;
      dispatch({ type: "outboxAdd", item: { id: newId(), kind: "pulse", dayKey: today, hash, event: "open" } });
      dispatch({ type: "markPulse", dayKey: today });
    });
    return () => {
      cancelled = true;
    };
  }, [ready, state.player?.settings.shareUsage, state.lastPulseDay, state.deviceSecret, classroomClient, clock]);
  const recordAttempt = useCallback(
    (questionId: string, choiceIndex: number, correct: boolean) => {
      const id = newId();
      dispatch({ type: "recordAttempt", id, questionId, choiceIndex, correct, now: nowIso() });
      return id;
    },
    [nowIso],
  );
  const setAttemptThinking = useCallback(
    (attemptId: string, thinking: string) => dispatch({ type: "setAttemptThinking", attemptId, thinking }),
    [],
  );
  const resetAll = useCallback(async () => {
    try {
      await adapterRef.current?.clear();
    } finally {
      dispatch({ type: "reset" });
    }
  }, []);

  const value = useMemo<GameContextValue>(
    () => ({
      state,
      ready,
      persistent,
      clock,
      createPlayer,
      setAvatar,
      updateSettings,
      markPreviewSeen,
      startSession,
      returnFromSession,
      recordAttempt,
      setAttemptThinking,
      classroomClient,
      joinClassroom,
      leaveClassroom,
      resetAll,
    }),
    [state, ready, persistent, clock, createPlayer, setAvatar, updateSettings, markPreviewSeen, startSession, returnFromSession, recordAttempt, setAttemptThinking, classroomClient, joinClassroom, leaveClassroom, resetAll],
  );

  return <GameContext.Provider value={value}>{children}</GameContext.Provider>;
}

export function useGame(): GameContextValue {
  const ctx = useContext(GameContext);
  if (!ctx) throw new Error("useGame must be used inside GameProvider");
  return ctx;
}
