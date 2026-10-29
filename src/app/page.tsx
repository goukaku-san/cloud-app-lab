"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useGame } from "@/game/store/GameProvider";
import { Loading } from "@/components/ui";

// 起動判定: プレイヤーなし → 導入、出発中 → 出発中画面、それ以外 → 鏡の部屋
export default function Home() {
  const { state, ready } = useGame();
  const router = useRouter();
  useEffect(() => {
    if (!ready) return;
    if (!state.player) router.replace("/intro");
    else if (state.activeSessionId) router.replace("/journey");
    else router.replace("/room");
  }, [ready, state.player, state.activeSessionId, router]);
  return <Loading />;
}
