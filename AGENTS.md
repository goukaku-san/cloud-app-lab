<!-- BEGIN:nextjs-agent-rules -->

## This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->

# 受験生の鏡: AI の協力者（Codex など）への案内

このリポジトリは、株式会社合格の受験生向けゲーム「受験生の鏡」です。受験生が小さな行動を選び、端末を置いて現実で行動し、戻って自己申告すると、鏡の中の部屋が変わります。Next.js 16 の静的書き出しによる PWA で、データは端末内（IndexedDB）にだけ保存します。

## 最初に読むもの

1. `docs/08-handoff.md`: 現在地、オーナーの決定事項、オーナーとの接し方、未完了の一覧、落とし穴。末尾の追記ほど新しい。
2. 必要に応じて `README.md`、`docs/00`（監査とリスク）、`docs/03`（データ構造）、`docs/07`（事業設計）。

## 一緒に作業している相手

Claude Code の会話（クラウドと倉庫メインPC）も同じリポジトリで作業しています。ぶつからないように次を守ってください。

- 作業を始める前に `main` を取り込み、`docs/08-handoff.md` の最新の追記を読む。
- `main` へ直接 push しない。`codex/<内容>` のような枝を切り、`main` 宛ての PR を出す。PR は小さく、目的ごとに分ける。
- 作業を終えたら `docs/08-handoff.md` の末尾に追記する。日付、誰が、何をしたか、確かめたこと（事実）と確かめていないことを分けて書く。

## 必ず守ること（オーナーの決定。変えるにはオーナー本人の言葉が要る）

- ゲーム本体を、オーナー以外が遊べる状態にしない。公開 URL は「準備中」の 1 枚（`holding/`）だけを配信している。`.github/workflows/pages.yml` を本体（`out/`）の配信に戻さない。
- 塾に渡すデータは、本人が任意参加した教室単位の匿名の合計だけ。個人のデータは外に出さない。広告ターゲティングはしない。
- 禁止するゲーム設計: 連続記録（ストリーク）、未達の罰や減点、羞恥や罪悪感を使う文言、深夜の再訪を促す仕組み、プッシュ通知、成績や人格のランキング、ガチャや可変報酬、無限スクロール。休んでも進行が止まらないこと。
- 物語と学習問題は AI の下書きで、人の監修を受けていない。画面の「草案」「デモ（監修前）」の表示を外さない。
- 第三者の SDK、分析タグ、外部フォント、外部への通信を足さない（教室の星図は、接続先を設定したときだけ 3 項目を送る）。

## よく使うコマンド

```bash
npm ci
npm run check                     # 型検査 + Lint + 単体テスト（Vitest）
npx playwright install chromium   # E2E を初めて動かす環境だけ
npm run test:e2e                  # 本番ビルド + E2E（スマホ幅）
npm run build && npm run start    # http://127.0.0.1:3100 で動作確認
```

PR を出す前に `npm run check` と `npm run test:e2e` を通してください。

## オーナーに質問するとき

オーナーは技術者ではありません。オーナー本人が決めた会話の約束があります。

- 質問は一度に 1 つ。選択肢は番号つきで 3 つ以上（推奨の採用か却下かだけは 2 つでよい）。先に自分の判断と推奨を書き、「どう思いますか」と丸投げしない。
- 数字を出すときは、式と前提を先に書く。前提が決まっていなければ予測しない。出典のない業界水準は語らない。
- 画面の操作をお願いするときは、押すボタンの名前と場所まで書く。
