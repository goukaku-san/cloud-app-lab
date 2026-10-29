"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { useGame } from "@/game/store/GameProvider";
import { useRouteGuard } from "@/components/useRouteGuard";
import { Button, Card, Loading, Note, PageShell } from "@/components/ui";
import { KIND_LABEL, MAX_QUEST_MINUTES, MIN_QUEST_MINUTES, QUEST_POOL } from "@/game/content/quests";
import { suggestQuests } from "@/game/logic/suggest";
import type { Quest, QuestKind } from "@/game/types";

const KINDS: QuestKind[] = ["study", "review", "rest"];

export default function PlanPage() {
  const [leaving, setLeaving] = useState(false);
  const ok = useRouteGuard({ active: "redirect", paused: leaving });
  const { state, startSession } = useGame();
  const router = useRouter();
  const suggestions = useMemo(() => suggestQuests(QUEST_POOL, state.sessions.length), [state.sessions.length]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [custom, setCustom] = useState({ title: "", kind: "study" as QuestKind });
  const [minutes, setMinutes] = useState(10);

  if (!ok) return <Loading />;

  const selected: Quest | null =
    selectedId === "custom"
      ? custom.title.trim()
        ? { id: "custom", subject: "自分で決めた", title: custom.title.trim().slice(0, 40), estimatedMinutes: minutes, kind: custom.kind, difficulty: 1 }
        : null
      : (suggestions.find((q) => q.id === selectedId) ?? null);

  const choose = (q: Quest) => {
    setSelectedId(q.id);
    setMinutes(q.estimatedMinutes);
  };
  const clampMinutes = (v: number) => Math.max(MIN_QUEST_MINUTES, Math.min(MAX_QUEST_MINUTES, Math.round(v) || MIN_QUEST_MINUTES));

  const depart = () => {
    if (!selected) return;
    setLeaving(true);
    startSession({ ...selected, estimatedMinutes: minutes });
    router.push("/journey");
  };

  return (
    <PageShell title="作戦会議" backHref="/room" backLabel="部屋">
      <Note>今日の現実の行動をひとつ選びます。3 案は固定の候補からの提案で、押し付けではありません。自分で決めてもかまいません。</Note>
      <div role="radiogroup" aria-label="今日の行動" className="flex flex-col gap-2">
        {suggestions.map((q, i) => {
          const on = selectedId === q.id;
          return (
            <button
              key={q.id}
              type="button"
              role="radio"
              aria-checked={on}
              onClick={() => choose(q)}
              data-testid={`quest-${i}`}
              className={`flex min-h-14 items-center justify-between rounded-2xl border px-4 py-3 text-left focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-dusk ${
                on ? "border-terracotta bg-terracotta/10" : "border-line bg-paper"
              }`}
            >
              <span>
                <span className="block font-bold">{q.title}</span>
                <span className="block text-xs text-ink-soft">
                  {KIND_LABEL[q.kind]} / {q.subject} / 目安 {q.estimatedMinutes} 分
                </span>
              </span>
              <span aria-hidden="true" className={`h-5 w-5 rounded-full border-2 ${on ? "border-terracotta bg-terracotta" : "border-line"}`} />
            </button>
          );
        })}
        <button
          type="button"
          role="radio"
          aria-checked={selectedId === "custom"}
          onClick={() => setSelectedId("custom")}
          className={`flex min-h-14 items-center justify-between rounded-2xl border px-4 py-3 text-left focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-dusk ${
            selectedId === "custom" ? "border-terracotta bg-terracotta/10" : "border-line bg-paper"
          }`}
        >
          <span className="font-bold">自分で決める</span>
          <span aria-hidden="true" className={`h-5 w-5 rounded-full border-2 ${selectedId === "custom" ? "border-terracotta bg-terracotta" : "border-line"}`} />
        </button>
      </div>

      {selectedId === "custom" ? (
        <Card className="flex flex-col gap-3">
          <label className="flex flex-col gap-1 text-sm font-semibold">
            やること（40 文字まで）
            <input
              type="text"
              value={custom.title}
              maxLength={40}
              onChange={(e) => setCustom({ ...custom, title: e.target.value })}
              placeholder="例: 英語の長文を1つ読む"
              className="min-h-12 rounded-2xl border border-line bg-white px-4 text-base font-normal focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-dusk"
            />
          </label>
          <fieldset className="flex flex-col gap-2">
            <legend className="text-sm font-semibold">種類</legend>
            <div role="radiogroup" aria-label="種類" className="flex gap-2">
              {KINDS.map((k) => (
                <button
                  key={k}
                  type="button"
                  role="radio"
                  aria-checked={custom.kind === k}
                  onClick={() => setCustom({ ...custom, kind: k })}
                  className={`min-h-11 flex-1 rounded-2xl border text-sm font-semibold focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-dusk ${
                    custom.kind === k ? "border-terracotta bg-terracotta text-white" : "border-line bg-white"
                  }`}
                >
                  {KIND_LABEL[k]}
                </button>
              ))}
            </div>
          </fieldset>
        </Card>
      ) : null}

      {selectedId ? (
        <Card>
          <p className="text-sm font-semibold">所要時間（自分で決められます）</p>
          <div className="mt-2 flex items-center gap-3">
            <Button type="button" variant="secondary" aria-label="5 分減らす" onClick={() => setMinutes((m) => clampMinutes(m - 5))}>
              −5
            </Button>
            <label className="flex flex-1 items-center justify-center gap-1 text-lg font-bold">
              <input
                type="number"
                inputMode="numeric"
                min={MIN_QUEST_MINUTES}
                max={MAX_QUEST_MINUTES}
                value={minutes}
                onChange={(e) => setMinutes(clampMinutes(Number(e.target.value)))}
                aria-label="分"
                className="w-20 rounded-xl border border-line bg-white px-2 py-2 text-center focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-dusk"
              />
              分
            </label>
            <Button type="button" variant="secondary" aria-label="5 分増やす" onClick={() => setMinutes((m) => clampMinutes(m + 5))}>
              +5
            </Button>
          </div>
          <Note>時間は目安です。短くても、途中でやめても、帰還すれば部屋は進みます。</Note>
        </Card>
      ) : null}

      <Button className="mt-auto w-full" onClick={depart} disabled={!selected} data-testid="depart">
        現実へ出発
      </Button>
    </PageShell>
  );
}
