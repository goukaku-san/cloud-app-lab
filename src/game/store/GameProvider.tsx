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
  resetAll: () => Promise<void>;
}

const GameContext = createContext<GameContextValue | null>(null);

function newId(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) return crypto.randomUUID();
  return `id-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}

export function GameProvider({ children, clock = deviceClock }: { children: ReactNode; clock?: Clock }) {
  const [state, dispatch] = useReducer(gameReducer, undefined, createInitialState);
  const [ready, setReady] = useState(false);
  const [persistent, setPersistent] = useState(true);
  const adapterRef = useRef<StorageAdapter | null>(null);
  const hydratedRef = useRef(false);

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
    (patch: Partial<Omit<Settings, "notifications">>) => dispatch({ type: "updateSettings", patch }),
    [],
  );
  const markPreviewSeen = useCallback(() => dispatch({ type: "markPreviewSeen" }), []);
  const startSession = useCallback(
    (quest: Quest) => dispatch({ type: "startSession", id: newId(), quest, now: nowIso() }),
    [nowIso],
  );
  const returnFromSession = useCallback(
    (report: SelfReport, reflection?: string) =>
      dispatch({ type: "returnSession", report, reflection, now: nowIso() }),
    [nowIso],
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
      resetAll,
    }),
    [state, ready, persistent, clock, createPlayer, setAvatar, updateSettings, markPreviewSeen, startSession, returnFromSession, resetAll],
  );

  return <GameContext.Provider value={value}>{children}</GameContext.Provider>;
}

export function useGame(): GameContextValue {
  const ctx = useContext(GameContext);
  if (!ctx) throw new Error("useGame must be used inside GameProvider");
  return ctx;
}
