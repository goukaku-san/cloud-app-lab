import type { NextConfig } from "next";

// 初期版はログインなし・端末内保存のため、静的書き出し（out/）で配布する。
// バックエンドを追加する段階で `output` を外す（docs/01-implementation-plan.md 参照）。
const nextConfig: NextConfig = {
  output: "export",
  trailingSlash: true,
  images: { unoptimized: true },
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
