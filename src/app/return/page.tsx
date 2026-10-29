"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useGame } from "@/game/store/GameProvider";
import { useRouteGuard } from "@/components/useRouteGuard";
import { Button, Card, Loading, Note, PageShell } from "@/components/ui";
import { REPORT_LABEL } from "@/game/content/labels";
import { formatElapsed } from "@/game/logic/time";
import type { SelfReport } from "@/game/types";

const CHOICES: Array<{ report: Exclude<SelfReport, "skip">; hint: string }> = [
  { report: "done", hint: "決めたことを、やった" },
  { report: "partial", hint: "少しだけ、やった" },
  { report: "rest", hint: "今日は休むと決めた" },
];

export default function ReturnPage() {
  const [leaving, setLeaving] = useState(false);
  const ok = useRouteGuard({ active: "require", paused: leaving });
  const { state, returnFromSession, clock } = useGame();
  const router = useRouter();
  const [report, setReport] = useState<SelfReport | null>(null);
  const [reflection, setReflection] = useState("");

  const session = state.sessions.find((s) => s.id === state.activeSessionId);
  if (!ok || (!session && !leaving)) return <Loading />;
  if (!session) return <Loading text="鏡を見ています…" />;
  const elapsed = clock.now().getTime() - new Date(session.startedAt).getTime();

  const submit = () => {
    if (!report) return;
    setLeaving(true);
    returnFromSession(report, reflection);
    router.push("/change");
  };

  return (
    <PageShell title="帰還">
      <Card className="text-center">
        <p className="text-2xl font-bold">おかえりなさい</p>
        <p className="mt-1 font-semibold">{session.quest.title}</p>
        <p className="text-sm text-ink-soft">経過 {formatElapsed(elapsed)}（端末の時計）</p>
      </Card>
      <fieldset className="flex flex-col gap-2">
        <legend className="mb-1 text-sm font-semibold">どうでしたか？ どれを選んでも部屋は進みます。</legend>
        <div role="radiogroup" aria-label="自己申告" className="flex flex-col gap-2">
          {CHOICES.map((c) => {
            const on = report === c.report;
            return (
              <button
                key={c.report}
                type="button"
                role="radio"
                aria-checked={on}
                onClick={() => setReport(c.report)}
                data-testid={`report-${c.report}`}
                className={`flex min-h-14 items-center justify-between rounded-2xl border px-4 py-3 text-left focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-dusk ${
                  on ? "border-terracotta bg-terracotta/10" : "border-line bg-paper"
                }`}
              >
                <span>
                  <span className="block text-lg font-bold">{REPORT_LABEL[c.report]}</span>
                  <span className="block text-xs text-ink-soft">{c.hint}</span>
                </span>
                <span aria-hidden="true" className={`h-5 w-5 rounded-full border-2 ${on ? "border-terracotta bg-terracotta" : "border-line"}`} />
              </button>
            );
          })}
        </div>
      </fieldset>
      <label className="flex flex-col gap-1 text-sm font-semibold">
        ひとこと（任意・140 文字まで）
        <textarea
          value={reflection}
          onChange={(e) => setReflection(e.target.value)}
          maxLength={140}
          rows={2}
          placeholder="気づいたこと、次にやりたいこと"
          className="rounded-2xl border border-line bg-white px-4 py-3 text-base font-normal focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-dusk"
        />
      </label>
      <Note>これは自己申告です。部屋の変化は申告にもとづき、学習の証明にはなりません。</Note>
      <Button className="mt-auto w-full" onClick={submit} disabled={!report} data-testid="see-mirror">
        鏡を見る
      </Button>
    </PageShell>
  );
}
