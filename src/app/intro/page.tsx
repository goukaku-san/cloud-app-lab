"use client";

import Link from "next/link";
import { useEffect, useState, useSyncExternalStore, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { useGame } from "@/game/store/GameProvider";
import { Loading } from "@/components/ui";
import { MirrorRoom } from "@/components/MirrorRoom";
import { AvatarPreview } from "@/components/Avatar";
import { objectsForGrowth, STAGE_THRESHOLDS } from "@/game/content/roomStages";
import { STORY_CHAPTERS } from "@/game/content/story";
import type { AvatarConfig } from "@/game/types";

// 導入（ランディング）。構成の手本: 「一言の問いかけ → 大きな題字 → 手元のスマホ画面 → 1 つの大きな入口 → 安心の一文」。
// 絵柄・人物・書体は他作品をまねず、受験生の鏡の部屋と分身で描く（設計書 5 章）。

const HERO_AVATAR: AvatarConfig = { hairStyle: 2, outfitColor: 0, companion: 1 };
const HERO_STAGE = 3;
const HERO_OBJECTS = [...objectsForGrowth(STAGE_THRESHOLDS[HERO_STAGE]), "subj-math"];
const WEEKDAYS = ["日", "月", "火", "水", "木", "金", "土"];

function pad(n: number): string {
  return n < 10 ? `0${n}` : String(n);
}

// 端末の時計を 1 枚のスマホ画面に出す（20 秒ごとに読み直す）。表示だけで、どこにも送らない。
function subscribeClock(onChange: () => void): () => void {
  const id = window.setInterval(onChange, 20_000);
  return () => window.clearInterval(id);
}
function readClock(): string {
  const d = new Date();
  return `${pad(d.getHours())}:${pad(d.getMinutes())}|${d.getMonth() + 1}月${d.getDate()}日（${WEEKDAYS[d.getDay()]}）`;
}

function PhoneScene() {
  const snapshot = useSyncExternalStore(subscribeClock, readClock, () => "--:--|");
  const [time, date] = snapshot.split("|");
  return (
    <div className="relative mx-auto h-[540px] w-full max-w-[340px]" aria-label="画面のイメージ" role="img">
      {/* 動きの線 */}
      <svg aria-hidden="true" viewBox="0 0 60 60" className="absolute left-2 top-16 h-14 w-14">
        <path d="M8 40 L40 18" stroke="#5b6c8f" strokeWidth="5" strokeLinecap="round" />
        <path d="M14 54 L48 34" stroke="#5b6c8f" strokeWidth="5" strokeLinecap="round" />
        <path d="M28 4 L22 22 L32 22 L24 40" stroke="#f2d479" strokeWidth="5" fill="none" strokeLinejoin="round" />
      </svg>

      {/* スマホ */}
      <div className="absolute left-1/2 top-2 h-[480px] w-[236px] -translate-x-1/2 rounded-[2.6rem] border-[10px] border-ink bg-gradient-to-b from-[#7fb0c8] to-[#4d5f86] shadow-[8px_8px_0_rgba(59,47,47,0.18)]">
        <div className="mx-auto mt-2 h-5 w-20 rounded-full bg-ink" />
        <p className="mt-3 text-center text-5xl font-light tabular-nums tracking-tight text-white" data-testid="hero-clock">
          {time}
        </p>
        <p className="text-center text-xs font-semibold text-white/90">{date}</p>
        <div className="mx-3 mt-3 overflow-hidden rounded-2xl border-2 border-white/80">
          <MirrorRoom stage={HERO_STAGE} objects={HERO_OBJECTS} avatar={HERO_AVATAR} season="autumn" idPrefix="hero" label="鏡の部屋（イメージ）" className="rounded-none border-0" />
        </div>
        <div className="mx-3 mt-2 space-y-1.5">
          <div className="rounded-xl bg-white/95 px-3 py-2 shadow-sm">
            <p className="flex items-center gap-1.5 text-[10px] font-bold text-ink-soft">
              <span className="inline-block h-3 w-3 rounded-[4px] bg-terracotta" />
              作戦会議
            </p>
            <p className="text-xs font-bold leading-tight">数学を10分 → 現実へ出発</p>
          </div>
          <div className="rounded-xl bg-white/95 px-3 py-2 shadow-sm">
            <p className="flex items-center gap-1.5 text-[10px] font-bold text-ink-soft">
              <span className="inline-block h-3 w-3 rounded-[4px] bg-sage-deep" />
              帰還
            </p>
            <p className="text-xs font-bold leading-tight">机に、小さな灯りがともった</p>
          </div>
        </div>
      </div>

      {/* 「閉じてOK」の札 */}
      <div className="absolute right-0 top-10 rotate-6 rounded-2xl border-[3px] border-ink bg-paper px-3 py-2 text-center shadow-[4px_4px_0_var(--ink)]">
        <svg aria-hidden="true" viewBox="0 0 40 40" className="mx-auto h-8 w-8">
          <path d="M26 6 a14 14 0 1 0 8 22 a11 11 0 1 1 -8 -22 z" fill="#f2d479" stroke="#3b2f2f" strokeWidth="2.5" />
        </svg>
        <p className="text-xs font-black leading-tight">
          閉じて
          <br />
          <span className="text-lg">OK</span>
        </p>
      </div>

      {/* 鏡の自分 */}
      <div className="absolute -bottom-1 left-0">
        <AvatarPreview avatar={HERO_AVATAR} size={118} label="鏡の自分（イメージ）" />
      </div>
    </div>
  );
}

function Blobs() {
  return (
    <svg aria-hidden="true" className="pointer-events-none absolute inset-0 h-full w-full" preserveAspectRatio="none" viewBox="0 0 400 800">
      <path d="M0 0 H190 Q150 60 90 70 Q30 80 0 140 Z" fill="#f2d479" />
      <path d="M400 40 Q330 60 330 140 Q330 230 400 250 Z" fill="#8fb996" />
      <path d="M0 800 V720 Q90 650 190 700 Q300 760 400 680 V800 Z" fill="#e9a08f" />
    </svg>
  );
}

const STEPS = [
  { title: "作戦会議", text: "今日の小さな行動をひとつ選ぶ。「数学を10分」でも「教科書を開くだけ」でも「休む」でもいい。" },
  { title: "現実へ出発", text: "スマホを閉じて、机へ。通知は送りません。途中でやめても、罰はありません。" },
  { title: "帰還して鏡を見る", text: "「やった」「少しやった」「今日は休んだ」から選ぶと、鏡の自分と部屋、物語が進む。" },
];

const PROMISES = ["罰も減点もなし", "連続記録も順位もなし", "通知は送らない", "休んでも物語は進む", "記録はこの端末の中だけ", "AI と通信しない"];

export default function IntroPage() {
  const { state, ready, createPlayer, persistent } = useGame();
  const router = useRouter();
  const [nickname, setNickname] = useState("");
  const [leaving, setLeaving] = useState(false);

  useEffect(() => {
    if (ready && state.player && !leaving) router.replace("/room");
  }, [ready, state.player, leaving, router]);

  if (!ready) return <Loading />;

  const start = (name?: string) => {
    setLeaving(true);
    createPlayer(name);
    router.push("/avatar");
  };
  const onSubmit = (e: FormEvent) => {
    e.preventDefault();
    start(nickname);
  };

  return (
    <div className="relative min-h-dvh overflow-hidden bg-cream">
      <section className="relative">
        <Blobs />
        <header className="relative z-10 mx-auto flex max-w-5xl items-center justify-between px-4 pt-4">
          <div>
            <p className="text-lg font-black leading-none tracking-tight">
              受験生の<span className="ml-0.5 rounded-md bg-terracotta px-1 text-white">鏡</span>
            </p>
            <p className="mt-1 text-[10px] font-semibold tracking-[0.2em] text-ink-soft">閉じるほど、物語が動き出す</p>
          </div>
          <Link
            href="/about"
            className="rounded-full border-2 border-ink bg-paper px-3 py-1.5 text-xs font-bold focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-dusk"
          >
            保護者の方へ
          </Link>
        </header>

        <main className="relative z-10 mx-auto grid max-w-5xl gap-6 px-4 pb-14 pt-6 md:grid-cols-2 md:items-center md:gap-10">
          <div>
            <p className="relative inline-block -rotate-1 rounded-2xl border-[3px] border-ink bg-white px-4 py-2 text-sm font-bold shadow-[3px_3px_0_var(--ink)] sm:text-base">
              「スマホを閉じるだけで、物語が進む」って、ほんと？
            </p>
            <h1 className="mt-5 font-black leading-none tracking-tight">
              <span className="block text-4xl sm:text-5xl">受験生の</span>
              <span className="mt-2 inline-block -rotate-3 rounded-2xl bg-terracotta px-4 pb-3 pt-2 text-[6.5rem] text-white shadow-[6px_6px_0_var(--ink)] sm:text-[8rem]">
                鏡
              </span>
            </h1>
            <p className="mt-6 text-[15px] leading-loose">
              勉強の前に、まずスマホを置く。いちばん難しいのは、たぶんそこです。受験生の鏡は、スマホを閉じているあいだに物語が進むゲーム。小さな行動をひとつ選んで出発し、戻ってきたら、鏡の自分と部屋が少しだけ変わります。
              <strong className="font-black">休んだ日も、物語は止まりません。</strong>
            </p>
            <div className="mt-6 flex flex-wrap items-center gap-3">
              <button
                type="button"
                onClick={() => start()}
                className="inline-flex min-h-14 items-center gap-2 rounded-full border-[3px] border-ink bg-star px-8 text-lg font-black shadow-[4px_4px_0_var(--ink)] transition-transform active:translate-x-[2px] active:translate-y-[2px] active:shadow-[2px_2px_0_var(--ink)] focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-dusk"
              >
                はじめる
                <span aria-hidden="true">→</span>
              </button>
              <a
                href="#how"
                className="inline-flex min-h-14 items-center rounded-full border-[3px] border-ink bg-paper px-6 font-black focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-dusk"
              >
                遊び方を見る
              </a>
            </div>
            <p className="mt-4 inline-block rounded-xl bg-paper/90 px-3 py-1.5 text-xs text-ink-soft">
              ログインも入力もいりません。記録はこの端末の中だけに保存され、どこにも送信されません。
            </p>
          </div>
          <PhoneScene />
        </main>
      </section>

      <section id="how" className="relative z-10 border-y-[3px] border-ink bg-paper px-4 py-10">
        <div className="mx-auto max-w-5xl">
          <h2 className="text-2xl font-black">遊び方は、3 つだけ</h2>
          <ol className="mt-5 grid gap-3 md:grid-cols-3">
            {STEPS.map((s, i) => (
              <li key={s.title} className="rounded-3xl border-[3px] border-ink bg-white p-4 shadow-[4px_4px_0_var(--ink)]">
                <p className="flex items-center gap-2 text-lg font-black">
                  <span className="inline-flex h-9 w-9 items-center justify-center rounded-full border-[3px] border-ink bg-star text-base">{i + 1}</span>
                  {s.title}
                </p>
                <p className="mt-2 text-sm leading-relaxed">{s.text}</p>
              </li>
            ))}
          </ol>
          <p className="mt-5 inline-block rounded-full border-2 border-ink bg-sage/40 px-4 py-1 text-sm font-bold">
            物語は全 {STORY_CHAPTERS.length} 章。そのあとも、日々は続きます。
          </p>
        </div>
      </section>

      <section className="relative z-10 px-4 py-10">
        <div className="mx-auto max-w-5xl">
          <h2 className="text-2xl font-black">この作品の約束</h2>
          <ul className="mt-4 flex flex-wrap gap-2">
            {PROMISES.map((p) => (
              <li key={p} className="rounded-full border-2 border-ink bg-white px-3 py-1.5 text-sm font-bold">
                {p}
              </li>
            ))}
          </ul>
          <p className="mt-4 text-sm leading-relaxed text-ink-soft">
            行動は自己申告です。部屋の変化は学習の証明ではありません。物語と問題は下書きの段階です。端末を変えたりブラウザのデータを消したりすると、記録も消えます。
          </p>
        </div>
      </section>

      <section id="start" className="relative z-10 px-4 pb-16">
        <form onSubmit={onSubmit} className="mx-auto flex max-w-md flex-col gap-3 rounded-3xl border-[3px] border-ink bg-paper p-5 shadow-[4px_4px_0_var(--ink)]">
          <h2 className="text-xl font-black">名前をつけてはじめる</h2>
          <label className="flex flex-col gap-1 text-sm font-semibold">
            ニックネーム（任意・20 文字まで）
            <input
              type="text"
              name="nickname"
              value={nickname}
              onChange={(e) => setNickname(e.target.value)}
              maxLength={20}
              autoComplete="off"
              placeholder="空のままでも始められます"
              className="min-h-12 rounded-2xl border-2 border-ink bg-white px-4 text-base font-normal focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-dusk"
            />
          </label>
          <p className="text-xs text-ink-soft">本名や学校名は入れないでください。ニックネームはこの端末の中でだけ使われます。</p>
          {!persistent ? (
            <p role="alert" className="text-xs text-terracotta-deep">
              この端末（またはブラウザの設定）では保存ができないため、閉じると記録が消えます。
            </p>
          ) : null}
          <button
            type="submit"
            className="min-h-12 rounded-full border-[3px] border-ink bg-star font-black shadow-[3px_3px_0_var(--ink)] focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-dusk"
          >
            この名前ではじめる
          </button>
        </form>
      </section>
    </div>
  );
}
