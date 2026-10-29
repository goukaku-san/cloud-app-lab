import type { NextConfig } from "next";

// 初期版はログインなし・端末内保存のため、静的書き出し（out/）で配布する。
// バックエンドを追加する段階で `output` を外す（docs/01-implementation-plan.md 参照）。
// サブパス配信（例: GitHub Pages の https://<owner>.github.io/<repo>/）のときは
// NEXT_PUBLIC_BASE_PATH="/<repo>" を指定してビルドする。未指定ならルート配信。
const basePath = process.env.NEXT_PUBLIC_BASE_PATH?.replace(/\/+$/, "") || "";

const nextConfig: NextConfig = {
  output: "export",
  trailingSlash: true,
  images: { unoptimized: true },
  basePath,
  assetPrefix: basePath || undefined,
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
