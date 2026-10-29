// 起動: node --experimental-strip-types server/index.ts
// 環境変数:
//   PORT              待ち受けポート（既定 8787）
//   DATA_FILE         JSON 保存先（既定 server-data/aggregates.json）
//   JUKU_TOKENS       "トークン:塾ID,トークン:塾ID"。未設定なら開発用 "dev-juku:juku-dev" を使う（警告を出す）
//   COMPANY_TOKEN     利用統計の閲覧トークン。未設定なら開発用 "dev-company"
//   ALLOWED_ORIGIN    生徒アプリのオリジン（CORS）。未設定なら "*"
//   K_ANONYMITY       最小表示人数（既定 5）
import http from "node:http";
import path from "node:path";
import { createApp, type SimpleRequest } from "./app.ts";
import { FileStore } from "./store.ts";

const port = Number(process.env.PORT ?? 8787);
const dataFile = process.env.DATA_FILE ?? path.resolve("server-data", "aggregates.json");

const jukuTokens = new Map<string, string>();
for (const pair of (process.env.JUKU_TOKENS ?? "").split(",")) {
  const [token, id] = pair.split(":").map((s) => s.trim());
  if (token && id) jukuTokens.set(token, id);
}
if (jukuTokens.size === 0) {
  jukuTokens.set("dev-juku", "juku-dev");
  console.warn("[警告] JUKU_TOKENS が未設定のため開発用トークン dev-juku を使います。試行・本番では必ず設定してください。");
}
const companyToken = process.env.COMPANY_TOKEN ?? "dev-company";
if (!process.env.COMPANY_TOKEN) console.warn("[警告] COMPANY_TOKEN が未設定のため開発用トークン dev-company を使います。");

const store = new FileStore(dataFile);
await store.load();
const app = createApp({
  store,
  jukuTokens,
  companyToken,
  allowedOrigin: process.env.ALLOWED_ORIGIN ?? null,
  k: process.env.K_ANONYMITY ? Number(process.env.K_ANONYMITY) : undefined,
});

const MAX_BODY = 4 * 1024;

http
  .createServer(async (req, res) => {
    const url = new URL(req.url ?? "/", "http://localhost");
    const chunks: Buffer[] = [];
    let size = 0;
    for await (const chunk of req) {
      size += (chunk as Buffer).length;
      if (size > MAX_BODY) {
        res.writeHead(413, { "content-type": "application/json" });
        res.end(JSON.stringify({ error: "payload_too_large" }));
        return;
      }
      chunks.push(chunk as Buffer);
    }
    let body: unknown = null;
    if (chunks.length > 0) {
      try {
        body = JSON.parse(Buffer.concat(chunks).toString("utf8"));
      } catch {
        res.writeHead(400, { "content-type": "application/json" });
        res.end(JSON.stringify({ error: "invalid_json" }));
        return;
      }
    }
    const simple: SimpleRequest = {
      method: req.method ?? "GET",
      path: url.pathname,
      query: url.searchParams,
      headers: { authorization: req.headers.authorization },
      body,
      ip: req.socket.remoteAddress ?? "unknown",
    };
    const out = await app.handle(simple);
    res.writeHead(out.status, { "content-type": "application/json; charset=utf-8", ...(out.headers ?? {}) });
    res.end(out.body === null ? undefined : JSON.stringify(out.body));
  })
  .listen(port, () => {
    console.log(`教室の星図 集計サーバー: http://localhost:${port}/v1/health (k=${app.k}, 保存先=${dataFile})`);
  });
