"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useGame } from "@/game/store/GameProvider";

type ActiveRule = "allow" | "redirect" | "require";

/**
 * 画面ガード（docs/02-screen-flow.md）。描画してよいときだけ true を返す。
 * - requirePlayer: プレイヤー未作成なら /intro へ
 * - active: 出発中のとき "redirect" なら /journey へ、"require" なら出発中でなければ /room へ
 * - requireChange: 直前の帰還結果がなければ /room へ
 * - paused: true のあいだはリダイレクトしない（状態更新と同時に自分で遷移するとき）
 */
export function useRouteGuard(
  opts: { requirePlayer?: boolean; active?: ActiveRule; requireChange?: boolean; paused?: boolean } = {},
): boolean {
  const { state, ready } = useGame();
  const router = useRouter();
  const { requirePlayer = true, active = "allow", requireChange = false, paused = false } = opts;

  let target: "/intro" | "/journey" | "/room" | null = null;
  if (ready && !paused) {
    if (requirePlayer && !state.player) target = "/intro";
    else if (active === "redirect" && state.activeSessionId) target = "/journey";
    else if (active === "require" && !state.activeSessionId) target = "/room";
    else if (requireChange && !state.lastChange) target = "/room";
  }

  useEffect(() => {
    if (target) router.replace(target);
  }, [target, router]);

  return ready && target === null;
}
