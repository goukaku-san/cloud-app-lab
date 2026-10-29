/* 受験生の鏡 Service Worker
 * - 同一オリジンの静的ファイルだけをキャッシュする。外部へのリクエストは一切行わない。
 * - 画面のシェルはインストール時に先読みし、以後は「ネットワーク優先・失敗時キャッシュ」。
 * - ハッシュ付きの _next/static はキャッシュ優先（内容が変わればファイル名も変わる）。
 * - CACHE_VERSION を上げると古いキャッシュを捨てる。
 */
const CACHE_VERSION = "kagami-v2";
// 配信先の基点（例: "/" や "/cloud-app-lab/"）。登録時のスコープから求める
const BASE = new URL(self.registration.scope).pathname.replace(/\/+$/, "") + "/";
const SHELL = [
  "/",
  "/intro/",
  "/avatar/",
  "/room/",
  "/plan/",
  "/journey/",
  "/return/",
  "/change/",
  "/log/",
  "/quiz/",
  "/stars/",
  "/classroom/",
  "/juku/",
  "/settings/",
  "/about/",
  "/manifest.webmanifest",
  "/icons/icon.svg",
].map((p) => BASE + p.replace(/^\//, ""));

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(CACHE_VERSION)
      .then((cache) => Promise.allSettled(SHELL.map((url) => cache.add(url))))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE_VERSION).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

function isSameOrigin(url) {
  return url.origin === self.location.origin;
}

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (!isSameOrigin(url)) return; // 外部リクエストには関与しない（存在しないはず）

  if (url.pathname.startsWith(BASE + "_next/static/")) {
    event.respondWith(
      caches.match(req).then(
        (hit) =>
          hit ||
          fetch(req).then((res) => {
            const copy = res.clone();
            caches.open(CACHE_VERSION).then((cache) => cache.put(req, copy));
            return res;
          }),
      ),
    );
    return;
  }

  // ページとその他: ネットワーク優先、失敗時はキャッシュ、最後にトップのシェル
  event.respondWith(
    fetch(req)
      .then((res) => {
        if (res.ok) {
          const copy = res.clone();
          caches.open(CACHE_VERSION).then((cache) => cache.put(req, copy));
        }
        return res;
      })
      .catch(async () => {
        const hit = await caches.match(req, { ignoreSearch: true });
        if (hit) return hit;
        if (req.mode === "navigate") {
          const shell = await caches.match(BASE);
          if (shell) return shell;
        }
        return new Response("オフラインです。接続後にもう一度開いてください。", {
          status: 503,
          headers: { "content-type": "text/plain; charset=utf-8" },
        });
      }),
  );
});
