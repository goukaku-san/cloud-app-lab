"use client";

import { useGame } from "@/game/store/GameProvider";
import { useRouteGuard } from "@/components/useRouteGuard";
import { Card, Loading, Note, PageShell } from "@/components/ui";
import { REPORT_LABEL } from "@/game/content/labels";
import { formatClock, formatDayKey } from "@/game/logic/time";

export default function LogPage() {
  const ok = useRouteGuard({ active: "redirect" });
  const { state } = useGame();
  if (!ok) return <Loading />;
  const sessions = [...state.sessions].reverse();

  return (
    <PageShell title="旅の記録" backHref="/room" backLabel="部屋">
      <Note>この記録はあなたにだけ表示され、外部には送られません。</Note>
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
    </PageShell>
  );
}
