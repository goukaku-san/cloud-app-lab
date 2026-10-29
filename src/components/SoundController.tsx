"use client";

import { useEffect, useRef } from "react";
import { useGame } from "@/game/store/GameProvider";
import { AmbientSound } from "@/game/sound/ambient";

// 設定「音（実験）」に従って環境音を開始・停止する。ブラウザの制約で、初回はユーザー操作後に鳴り始める。
export function SoundController() {
  const { state } = useGame();
  const enabled = Boolean(state.player?.settings.sound);
  const volume = state.player?.settings.soundVolume ?? 0.5;
  const ref = useRef<AmbientSound | null>(null);

  useEffect(() => {
    if (!ref.current) ref.current = new AmbientSound();
    const sound = ref.current;
    if (!enabled) {
      if (sound.running) void sound.stop();
      return;
    }
    void sound.start(volume);
    const onGesture = () => void (sound.running ? sound.resume() : sound.start(volume));
    const onVisibility = () => {
      if (document.visibilityState === "visible") void sound.resume();
    };
    window.addEventListener("pointerdown", onGesture);
    window.addEventListener("keydown", onGesture);
    document.addEventListener("visibilitychange", onVisibility);
    return () => {
      window.removeEventListener("pointerdown", onGesture);
      window.removeEventListener("keydown", onGesture);
      document.removeEventListener("visibilitychange", onVisibility);
    };
    // volume は別の effect で反映する
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [enabled]);

  useEffect(() => {
    ref.current?.setVolume(volume);
  }, [volume]);

  useEffect(() => {
    const sound = ref.current;
    return () => {
      if (sound?.running) void sound.stop();
    };
  }, []);

  return null;
}
