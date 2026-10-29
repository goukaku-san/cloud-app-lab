"use client";

import { useGame } from "@/game/store/GameProvider";
import { useRouteGuard } from "@/components/useRouteGuard";
import { Card, Loading, Note, PageShell } from "@/components/ui";
import { REPORT_LABEL } from "@/game/content/labels";
import { QUESTIONS } from "@/game/content/questions";
import { dayKeyOf, formatClock, formatDayKey } from "@/game/logic/time";

export default function LogPage() {
  const ok = useRouteGuard({ active: "redirect" });
  const { state, clock } = useGame();
  if (!ok) return <Loading />;
  const sessions = [...state.sessions].reverse();
  const attempts = [...state.attempts].reverse();

  // この 7 日の振り返り（端末ローカル日付。評価はしない）
  const now = clock.now();
  const weekKeys = new Set<string>();
  for (let i = 0; i < 7; i += 1) {
    const d = new Date(now);
    d.setDate(now.getDate() - i);
    weekKeys.add(dayKeyOf(d));
  }
  const weekSessions = state.sessions.filter((s) => s.returnedAt && weekKeys.has(dayKeyOf(new Date(s.returnedAt))));
  const counts = { done: 0, partial: 0, rest: 0, skip: 0 };
  for (const s of weekSessions) if (s.selfReport) counts[s.selfReport] += 1;
  const weekDays = new Set(weekSessions.filter((s) => s.selfReport !== "skip").map((s) => dayKeyOf(new Date(s.returnedAt as string)))).size;

  return (
    <PageShell title="旅の記録" backHref="/room" backLabel="部屋">
      <Note>この記録はあなたにだけ表示され、外部には送られません。</Note>
      <Card>
        <h2 className="font-bold">この 7 日の振り返り</h2>
        <p className="mt-1 text-sm" data-testid="week-summary">
          帰還した日: {weekDays} 日 / やった {counts.done} 回・少しやった {counts.partial} 回・休んだ {counts.rest} 回
        </p>
        <Note>回数は多い少ないを比べるためのものではなく、戻ってきた日を思い出すためのものです。</Note>
      </Card>
      {sessions.length === 0 ? (
        <Card>
          <p className="text-sm">まだ記録はありません。最初の出発から、物語が始まります。</p>
        </Card>
      ) : (
        <ul className="flex flex-col gap-2" data-testid="log-list">
          {sessions.map((s) => (
            <li key={s.id}>
              <Card>
                <p className="text-xs text-ink-soft">
                  {formatDayKey(s.dayKey)} {formatClock(s.startedAt)}
                </p>
                <p className="font-bold">{s.quest.title}</p>
                <p className="text-sm">
                  {s.selfReport ? REPORT_LABEL[s.selfReport] : "出発中"}
                  {typeof s.elapsedMinutes === "number" ? ` / ${s.elapsedMinutes} 分` : ""}
                </p>
                {s.reflection ? <p className="mt-1 text-sm text-ink-soft">「{s.reflection}」</p> : null}
              </Card>
            </li>
          ))}
        </ul>
      )}
      <Card>
        <h2 className="font-bold">一問の魔法の記録</h2>
        {attempts.length === 0 ? (
          <p className="mt-1 text-sm">まだ解いた問題はありません。</p>
        ) : (
          <ul className="mt-2 flex flex-col gap-1 text-sm" data-testid="attempt-list">
            {attempts.slice(0, 20).map((a) => {
              const q = QUESTIONS.find((x) => x.id === a.questionId);
              return (
                <li key={a.id} className="rounded-xl bg-white px-3 py-2">
                  <span className="text-xs text-ink-soft">{q ? `${q.subject} / ${q.gradeBand}` : a.questionId}</span>
                  <span className="block">{q?.prompt ?? ""}</span>
                  <span className="block text-ink-soft">
                    {a.correct ? "正解" : "解説を読んだ"}
                    {a.thinking ? ` / ${a.thinking}` : ""}
                  </span>
                </li>
              );
            })}
          </ul>
        )}
      </Card>
    </PageShell>
  );
}
