// `next build` で生成した out/ を配信する最小の静的サーバー（E2E とローカル確認用）。
// 外部依存なし。trailingSlash: true 前提で /room/ -> out/room/index.html を返す。
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

// SERVE_ROOT を指定すると別のディレクトリを配信できる（サブパス配信の確認用）
const root = process.env.SERVE_ROOT ? path.resolve(process.env.SERVE_ROOT) : path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "out");
const port = Number(process.argv[2] ?? 3100);
// HOST=0.0.0.0 にすると同じ Wi-Fi のスマホからも開ける（PC の IP アドレスでアクセス）
const host = process.env.HOST ?? "127.0.0.1";

const types = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".webmanifest": "application/manifest+json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".ico": "image/x-icon",
  ".txt": "text/plain; charset=utf-8",
  ".woff2": "font/woff2",
};

function resolveFile(urlPath) {
  const clean = decodeURIComponent(urlPath.split("?")[0]);
  let filePath = path.join(root, clean);
  if (!filePath.startsWith(root)) return null;
  if (fs.existsSync(filePath) && fs.statSync(filePath).isDirectory()) {
    filePath = path.join(filePath, "index.html");
  } else if (!fs.existsSync(filePath) && fs.existsSync(filePath + ".html")) {
    filePath = filePath + ".html";
  }
  return fs.existsSync(filePath) ? filePath : null;
}

http
  .createServer((req, res) => {
    const file = resolveFile(req.url ?? "/");
    if (!file) {
      const notFound = path.join(root, "404.html");
      res.writeHead(404, { "content-type": "text/html; charset=utf-8" });
      res.end(fs.existsSync(notFound) ? fs.readFileSync(notFound) : "Not found");
      return;
    }
    const ext = path.extname(file);
    res.writeHead(200, {
      "content-type": types[ext] ?? "application/octet-stream",
      "cache-control": ext === ".html" ? "no-cache" : "public, max-age=3600",
    });
    fs.createReadStream(file).pipe(res);
  })
  .listen(port, host, () => {
    console.log(`serving ${root} at http://${host}:${port}/`);
  });
