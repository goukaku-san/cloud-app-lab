"use client";

import { useGame } from "@/game/store/GameProvider";
import { useRouteGuard } from "@/components/useRouteGuard";
import { Card, LinkButton, Loading, Note, PageShell } from "@/components/ui";
import { DEMO_PARTICIPANTS, DEMO_WEEKS, starPositions } from "@/game/content/starsDemo";
import { useEffect, useState } from "react";
import { ClassroomSky } from "@/components/ClassroomSky";
import type { ClassroomSummary } from "@/game/classroom/protocol";

// 共創の星図（第 2 段階のデモ）。表示はすべて架空データ。実ユーザーの集計は安全審査後。
export default function StarsPage() {
  const ok = useRouteGuard({ active: "redirect" });
  const { state, classroomClient } = useGame();
  const [summary, setSummary] = useState<ClassroomSummary | null>(null);
  const joinedCode = state.classroom?.code ?? null;
  useEffect(() => {
    if (!joinedCode) return;
    let cancelled = false;
    classroomClient
      .getPublicSummary(joinedCode, 7)
      .then((s) => {
        if (!cancelled) setSummary(s);
      })
      .catch(() => {
        if (!cancelled) setSummary(null);
      });
    return () => {
      cancelled = true;
    };
  }, [joinedCode, classroomClient, state.outbox.length]);
  if (!ok) return <Loading />;

  const demoTotal = DEMO_WEEKS.reduce((sum, w) => sum + w.actions, 0);
  const demoStars = starPositions(Math.min(160, Math.round(demoTotal / 5)));
  const mine = state.sessions.filter((s) => s.returnedAt && s.selfReport !== "skip").length;
  const myStars = starPositions(Math.min(30, mine), 99);

  if (state.classroom) {
    return (
      <PageShell title="教室の星図" backHref="/room" backLabel="部屋">
        {classroomClient.mode === "mock" ? (
          <p className="rounded-xl bg-star/40 px-3 py-2 text-sm font-semibold" data-testid="stars-mock-label">
            モック: 集計サーバーに接続していないため、合計は端末内で模擬しています。
          </p>
        ) : null}
        <p className="text-sm">
          教室 <strong className="font-mono tracking-wider">{state.classroom.code}</strong> / あなたの星: {mine} 個
        </p>
        {summary ? (
          <>
            <ClassroomSky summary={summary} label="教室の星空" extraStars={mine} />
            <Card>
              <p className="text-sm" data-testid="classroom-week-total">
                {summary.weekSuppressedDays === 7
                  ? `まだ表示できません。参加端末が ${summary.k} 台以上になった日から、合計が星になります。`
                  : `この 7 日の教室の帰還: ${summary.weekTotal} 回（表示しない日が ${summary.weekSuppressedDays} 日）`}
              </p>
            </Card>
          </>
        ) : (
          <Note role="status">教室の合計を読み込んでいます…</Note>
        )}
        <LinkButton href="/classroom">教室の設定</LinkButton>
        <Note>白い星はあなたの帰還、黄色い星は教室全体の合計です。誰が何回かは誰にも分かりません。</Note>
      </PageShell>
    );
  }

  return (
    <PageShell title="共創の星図" backHref="/room" backLabel="部屋">
      <p className="rounded-xl bg-star/40 px-3 py-2 text-sm font-semibold" data-testid="stars-demo-label">
        架空のデモデータです。実際の参加者のデータではありません。他の人の記録はこの端末に届いていません。
      </p>
      <svg viewBox="0 0 360 230" role="img" aria-label="星図（デモ）。架空の星と、あなたの帰還の数だけの星。" className="h-auto w-full rounded-3xl border border-line">
        <defs>
          <linearGradient id="stars-sky" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#1c2541" />
            <stop offset="1" stopColor="#3a4d7a" />
          </linearGradient>
        </defs>
        <rect width="360" height="230" fill="url(#stars-sky)" />
        {demoStars.map((s, i) => (
          <circle key={`d${i}`} cx={s.x} cy={s.y} r={s.r} fill="#f2d479" opacity="0.6" className="anim-twinkle" style={{ animationDelay: `${(i % 7) * 0.4}s` }} />
        ))}
        {myStars.map((s, i) => (
          <circle key={`m${i}`} cx={s.x} cy={s.y} r={s.r + 1.2} fill="#ffffff" />
        ))}
        <path d="M0 230 Q90 190 180 212 Q270 190 360 230 Z" fill="#2f4a3c" />
      </svg>
      <Card>
        <p className="text-sm">
          <strong>あなたの星: {mine} 個</strong>（この端末に記録された帰還の数。記録せずに戻った分は含みません）
        </p>
        <p className="mt-2 text-sm text-ink-soft">
          架空の参加者 {DEMO_PARTICIPANTS} 人の、架空の行動回数（デモ）:
        </p>
        <ul className="mt-1 grid grid-cols-2 gap-1 text-sm">
          {DEMO_WEEKS.map((w) => (
            <li key={w.label} className="rounded-xl bg-paper px-3 py-1">
              {w.label}: {w.actions} 回
            </li>
          ))}
        </ul>
      </Card>
      <LinkButton href="/classroom">教室コードがあれば、本物の教室の星図に参加する</LinkButton>
      <Note>
        この画面は構想を見せるためのデモです。本物の星図は、塾や学校の教室コードで任意参加し、教室全体の匿名の合計だけが星になります。個人の順位や比較は、将来も表示しません。
      </Note>
    </PageShell>
  );
}
