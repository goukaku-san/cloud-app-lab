# 受験生の鏡（仮）— v0.1 縦切りデモ

「閉じるほど、物語が動き出す。」
受験生が今日の小さな行動を自分で選び、端末を置いて現実で行動し、戻ってきたら自己申告する。申告にもとづいて、鏡の中の小さな部屋が変わる。

状態: **実機検証前のデモ**。外部公開・課金・広告・実ユーザーデータ収集は行っていない。物語の文章は草案（監修前）。学習問題は未実装（監修済みデータ待ち）。

## 動かす

```bash
npm install
npm run dev          # http://localhost:3000（開発。Service Worker は登録されない）
npm run build        # 静的書き出し → out/
npm run start        # out/ を http://127.0.0.1:3100 で配信（本番相当・PWA 有効）
```

## 検証

```bash
npm run check        # typecheck + lint + 単体テスト
npm run test:e2e     # 本番ビルド（out/）を対象にした Playwright E2E（スマホ幅・Chromium）
npm run icons        # public/icons/icon.svg から PNG アイコンを再生成
```

結果は `docs/05-test-report.md` に記録する。自動テストと手動検証は区別して報告する。

## 文書

| ファイル | 内容 |
| --- | --- |
| `docs/00-repo-audit-and-risks.md` | リポジトリ監査、仕様の矛盾、リスクと未実装一覧 |
| `docs/01-implementation-plan.md` | Phase ごとの計画、技術構成、ゲーム規則 |
| `docs/02-screen-flow.md` | 画面遷移とガード |
| `docs/03-data-model.md` | データ構造と永続化の抽象化 |
| `docs/04-test-plan.md` | テスト計画（自動 / 手動） |
| `docs/05-test-report.md` | テスト結果とデモ操作シナリオ |

## 設計上の約束（実装で担保しているもの）

- 入力項目はニックネーム（任意）のみ。データは端末内の IndexedDB にのみ保存し、サーバーへ送らない。
- 成長は自己申告 1 回ごとに加算し、1 日 3 点が上限。経過時間は成長に影響しない。減点・連続記録・ランキング・通知・広告はない。
- 「今日は休んだ」「記録しない」を選んでも罰はなく、物語は続く。
- 初回の「未来の部屋」はプレビューと明示し、成長を付与しない。
- 第三者 SDK・分析タグ・Web フォントを使わない。Service Worker は同一オリジンのみをキャッシュする。
- 行動の提案はルールベースで、AI は使っていない。

## 構成

Next.js 16（App Router, 静的書き出し）/ React 19 / TypeScript / Tailwind CSS 4 / Vitest / Playwright。
詳細は `docs/01-implementation-plan.md`。
