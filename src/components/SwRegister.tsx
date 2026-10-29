"use client";

import { useEffect } from "react";

// 本番ビルドでのみ Service Worker を登録する（同一オリジンの静的ファイルのみをキャッシュ）。
export function SwRegister() {
  useEffect(() => {
    if (process.env.NODE_ENV !== "production") return;
    if (typeof navigator === "undefined" || !("serviceWorker" in navigator)) return;
    const base = process.env.NEXT_PUBLIC_BASE_PATH?.replace(/\/+$/, "") || "";
    navigator.serviceWorker.register(`${base}/sw.js`, { scope: `${base}/` }).catch(() => {
      // 登録できなくてもアプリは動く（オフライン対応だけが無効になる）
    });
  }, []);
  return null;
}
