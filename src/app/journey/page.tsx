"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useGame } from "@/game/store/GameProvider";
import { useRouteGuard } from "@/components/useRouteGuard";
import { Button, Card, Loading, Note, PageShell } from "@/components/ui";
import { formatClock, formatElapsed } from "@/game/logic/time";

export default function JourneyPage() {
  const [leaving, setLeaving] = useState(false);
  const ok = useRouteGuard({ active: "require", paused: leaving });
  const { state, returnFromSession, clock } = useGame();
  const router = useRouter();
  const [now, setNow] = useState<number>(() => clock.now().getTime());
  const [confirmSkip, setConfirmSkip] = useState(false);

  useEffect(() => {
    const id = window.setInterval(() => setNow(clock.now().getTime()), 15_000);
    return () => window.clearInterval(id);
  }, [clock]);

  const session = state.sessions.find((s) => s.id === state.activeSessionId);
  if (!ok || !session) return <Loading />;

  const elapsed = now - new Date(session.startedAt).getTime();

  const skip = () => {
    setLeaving(true);
    returnFromSession("skip");
    router.push("/room");
  };

  return (
    <PageShell title="出発中">
      <Card className="text-center">
        <p className="text-2xl font-bold">いってらっしゃい</p>
        <p className="mt-2 text-lg font-semibold" data-testid="journey-quest">
          {session.quest.title}
        </p>
        <p className="text-sm text-ink-soft">目安 {session.quest.estimatedMinutes} 分 / 出発 {formatClock(session.startedAt)}</p>
        <p className="mt-3 text-sm" aria-live="polite">
          経過 {formatElapsed(elapsed)}（端末の時計）
        </p>
      </Card>
      <Card>
        <p className="font-bold">この画面は閉じて大丈夫です。</p>
        <p className="mt-1 text-sm leading-relaxed">
          端末を置いて、現実で行動してください。戻ってきたら「帰還する」を押します。アプリを閉じても出発中のままで、通知は送りません。途中でやめても罰はありません。
        </p>
      </Card>
      <Button className="w-full" onClick={() => router.push("/return")} data-testid="return">
        帰還する
      </Button>
      {confirmSkip ? (
        <Card className="flex flex-col gap-2">
          <p className="text-sm">この出発は記録せずに部屋へ戻ります。部屋は変わらず、減ることもありません。</p>
          <Button variant="danger" onClick={skip} data-testid="skip-confirm">
            記録せずに戻る
          </Button>
          <Button variant="ghost" onClick={() => setConfirmSkip(false)}>
            やっぱり続ける
          </Button>
        </Card>
      ) : (
        <Button variant="ghost" className="w-full" onClick={() => setConfirmSkip(true)} data-testid="skip">
          記録せずに部屋へ戻る
        </Button>
      )}
      <Note>経過時間は記録のためだけに使い、部屋の成長には影響しません。端末を触らなかったことを証明するものでもありません。</Note>
    </PageShell>
  );
}
