"use client";

import { useMemo, useState } from "react";
import { useGame } from "@/game/store/GameProvider";
import { useRouteGuard } from "@/components/useRouteGuard";
import { Button, Card, LinkButton, Loading, Note, PageShell } from "@/components/ui";
import { QUESTIONS, THINKING_OPTIONS } from "@/game/content/questions";
import { pickQuestion } from "@/game/logic/quiz";

// 一問の魔法（任意）。成長点は付与しない。正誤で責めない。
export default function QuizPage() {
  const ok = useRouteGuard({ active: "redirect" });
  const { state, recordAttempt, setAttemptThinking } = useGame();
  const [round, setRound] = useState(0);
  const [choice, setChoice] = useState<number | null>(null);
  const [attemptId, setAttemptId] = useState<string | null>(null);
  const [thinking, setThinking] = useState<string | null>(null);

  const question = useMemo(
    () => pickQuestion(QUESTIONS, state.attempts, state.attempts.length + round),
    // round は「もう一問」で進める
    [state.attempts, round],
  );

  if (!ok || !question) return <Loading />;
  const answered = attemptId !== null;
  const correct = answered && choice === question.answerIndex;

  const submit = () => {
    if (choice === null) return;
    setAttemptId(recordAttempt(question.id, choice, choice === question.answerIndex));
  };
  const next = () => {
    setRound((r) => r + 1);
    setChoice(null);
    setAttemptId(null);
    setThinking(null);
  };
  const pickThinking = (t: string) => {
    if (!attemptId) return;
    setThinking(t);
    setAttemptThinking(attemptId, t);
  };

  return (
    <PageShell title="一問の魔法" backHref="/room" backLabel="部屋">
      {!question.reviewed ? (
        <p className="rounded-xl bg-star/40 px-3 py-2 text-sm font-semibold" data-testid="quiz-demo-label">
          デモ（監修前）: この問題と解説は AI が下書きしたもので、人手の確認を受けていません。誤りを含む可能性があります。
        </p>
      ) : null}
      <Card>
        <p className="text-xs text-ink-soft">
          {question.subject} / {question.gradeBand}
        </p>
        <p className="mt-1 text-lg font-bold" data-testid="quiz-prompt">
          {question.prompt}
        </p>
        <div role="radiogroup" aria-label="答え" className="mt-3 flex flex-col gap-2">
          {question.choices.map((c, i) => {
            const on = choice === i;
            const isAnswer = answered && i === question.answerIndex;
            return (
              <button
                key={c}
                type="button"
                role="radio"
                aria-checked={on}
                disabled={answered}
                onClick={() => setChoice(i)}
                data-testid={`choice-${i}`}
                className={`flex min-h-12 items-center justify-between rounded-2xl border px-4 py-2 text-left focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-dusk disabled:opacity-100 ${
                  isAnswer ? "border-sage-deep bg-sage/30" : on ? "border-terracotta bg-terracotta/10" : "border-line bg-white"
                }`}
              >
                <span>{c}</span>
                {isAnswer ? <span className="text-xs font-semibold text-sage-deep">正答</span> : null}
              </button>
            );
          })}
        </div>
        {!answered ? (
          <Button className="mt-3 w-full" onClick={submit} disabled={choice === null} data-testid="quiz-submit">
            答える
          </Button>
        ) : null}
      </Card>

      {answered ? (
        <Card>
          <p className="text-lg font-bold" data-testid="quiz-result">
            {correct ? "正解です。" : "ちがっていました。"}
          </p>
          {!correct ? <p className="text-sm">間違いは地図になります。解説を読んでみましょう。</p> : null}
          <p className="mt-2 text-sm leading-relaxed" data-testid="quiz-explanation">
            {question.explanation}
          </p>
        </Card>
      ) : null}

      {answered ? (
        <Card>
          <p className="font-semibold">どう考えましたか？（任意）</p>
          <Note>考え方を言葉にしておくと、次に同じ問題に出会ったときの手がかりになります。どれを選んでもかまいません。</Note>
          <div role="radiogroup" aria-label="考え方" className="mt-2 flex flex-col gap-2">
            {THINKING_OPTIONS.map((t) => (
              <button
                key={t}
                type="button"
                role="radio"
                aria-checked={thinking === t}
                onClick={() => pickThinking(t)}
                className={`min-h-11 rounded-2xl border px-4 text-left text-sm focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-dusk ${
                  thinking === t ? "border-terracotta bg-terracotta/10" : "border-line bg-white"
                }`}
              >
                {t}
              </button>
            ))}
          </div>
        </Card>
      ) : null}

      {answered ? (
        <div className="flex flex-col gap-2">
          <Button variant="secondary" onClick={next} data-testid="quiz-next">
            もう一問
          </Button>
          <LinkButton href="/room" variant="primary">
            部屋へ戻る
          </LinkButton>
        </div>
      ) : null}
      <Note>一問の魔法は任意です。解いても解かなくても部屋の成長は変わりません。正誤は記録されますが、順位や点数はつけません。</Note>
    </PageShell>
  );
}
