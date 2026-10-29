"use client";

import { useEffect, useState } from "react";
import { useGame } from "@/game/store/GameProvider";
import { useRouteGuard } from "@/components/useRouteGuard";
import { Button, Card, Loading, Note, PageShell } from "@/components/ui";
import { ClassroomSky } from "@/components/ClassroomSky";
import { isValidClassroomCode, MOCK_DEMO_CODE, normalizeCode } from "@/game/classroom/client";
import { CONSENT_VERSION, NOT_SENT_FIELDS, SENT_FIELDS, type ClassroomSummary } from "@/game/classroom/protocol";
import { formatDayKey } from "@/game/logic/time";

// 教室の星図への参加（任意）。塾に渡るのは教室単位の匿名の合計だけ。
export default function ClassroomPage() {
  const ok = useRouteGuard({ active: "redirect" });
  const { state, classroomClient, joinClassroom, leaveClassroom } = useGame();
  const [codeInput, setCodeInput] = useState("");
  const [understood, setUnderstood] = useState(false);
  const [confirmLeave, setConfirmLeave] = useState(false);
  const [summary, setSummary] = useState<ClassroomSummary | null>(null);
  const [summaryError, setSummaryError] = useState<string | null>(null);

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
        if (!cancelled) setSummaryError("教室の合計をいま取得できません（オフラインか、接続先が応答していません）。");
      });
    return () => {
      cancelled = true;
    };
  }, [joinedCode, classroomClient, state.outbox.length]);

  if (!ok || !state.player) return <Loading />;
  const mock = classroomClient.mode === "mock";
  const normalized = normalizeCode(codeInput);
  const canJoin = isValidClassroomCode(normalized) && understood;
  const pending = state.outbox.filter((o) => o.kind === "return").length;
  const myReturns = state.sessions.filter((s) => s.returnedAt && s.selfReport !== "skip").length;

  return (
    <PageShell title="教室の星図" backHref="/settings" backLabel="設定">
      {mock ? (
        <p className="rounded-xl bg-star/40 px-3 py-2 text-sm font-semibold" data-testid="classroom-mock-label">
          モック: この版は集計サーバーに接続していません。送信は端末内で模擬され、外部には何も送られません。
        </p>
      ) : (
        <Note>接続先: {classroomClient.baseUrl}</Note>
      )}

      {state.classroom ? (
        <>
          <Card>
            <p className="text-sm text-ink-soft">参加中の教室</p>
            <p className="text-2xl font-bold tracking-wider" data-testid="joined-code">
              {state.classroom.code}
            </p>
            <p className="text-sm">参加日: {formatDayKey(state.classroom.joinedAt.slice(0, 10))}</p>
            <p className="text-sm" data-testid="outbox-status">
              {pending === 0 ? "送信待ちはありません。" : `送信待ち ${pending} 件（接続後に送ります）。`}
            </p>
          </Card>
          <Card>
            <h2 className="font-bold">この 7 日の教室の星</h2>
            {summary ? (
              <>
                <ClassroomSky summary={summary} label="教室の星空" extraStars={myReturns} />
                <p className="mt-2 text-sm" data-testid="classroom-week-total">
                  {summary.weekSuppressedDays === 7
                    ? `まだ表示できません。参加端末が ${summary.k} 台以上になった日から、合計が星になります。`
                    : `この 7 日の帰還の合計: ${summary.weekTotal} 回（表示しない日が ${summary.weekSuppressedDays} 日）`}
                </p>
                <Note>白い星はあなたの帰還。黄色い星は教室全体の合計です。誰が何回かは、あなたにも塾にも分かりません。</Note>
              </>
            ) : (
              <Note role="status">{summaryError ?? "読み込み中…"}</Note>
            )}
          </Card>
          <Card>
            <h2 className="font-bold">教室から抜ける</h2>
            <p className="mt-1 text-sm">抜けると、以後は何も送りません。これまでの合計から自分の分を引くことはできません（引ける情報をサーバーが持っていないためです）。</p>
            {confirmLeave ? (
              <div className="mt-2 flex flex-col gap-2">
                <Button variant="danger" onClick={() => { leaveClassroom(); setConfirmLeave(false); setSummary(null); }} data-testid="leave-confirm">
                  抜ける
                </Button>
                <Button variant="ghost" onClick={() => setConfirmLeave(false)}>
                  やめる
                </Button>
              </div>
            ) : (
              <Button variant="danger" className="mt-2 w-full" onClick={() => setConfirmLeave(true)} data-testid="leave">
                教室から抜ける
              </Button>
            )}
          </Card>
        </>
      ) : (
        <>
          <Card>
            <h2 className="font-bold">教室の星図とは</h2>
            <p className="mt-1 text-sm leading-relaxed">
              塾や学校の教室ごとに、みんなの帰還が星になって集まる空です。参加は任意で、参加しなくても何も変わりません。塾の先生に見えるのは「教室全体で何回帰還したか」だけで、誰が何回かは分かりません。
            </p>
          </Card>
          <Card>
            <h2 className="font-bold">送られるもの</h2>
            <ul className="mt-1 list-disc pl-5 text-sm" data-testid="sent-fields">
              {SENT_FIELDS.map((f) => (
                <li key={f}>{f}</li>
              ))}
            </ul>
            <h2 className="mt-3 font-bold">送られないもの</h2>
            <ul className="mt-1 list-disc pl-5 text-sm" data-testid="not-sent-fields">
              {NOT_SENT_FIELDS.map((f) => (
                <li key={f}>{f}</li>
              ))}
            </ul>
            <Note>参加端末が少ない日は、合計も表示されません（個人の行動が推測されないようにするためです）。同意文面の版: {CONSENT_VERSION}</Note>
          </Card>
          <Card className="flex flex-col gap-3">
            <label className="flex flex-col gap-1 text-sm font-semibold">
              教室コード（先生から受け取ったもの）
              <input
                type="text"
                value={codeInput}
                onChange={(e) => setCodeInput(e.target.value)}
                placeholder="例: ABCD-2345"
                autoCapitalize="characters"
                autoComplete="off"
                maxLength={9}
                className="min-h-12 rounded-2xl border border-line bg-white px-4 font-mono text-lg font-normal tracking-wider focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-dusk"
              />
            </label>
            {mock ? <Note>モックでは、架空の教室 {MOCK_DEMO_CODE} を入れると合計の見え方を確認できます。</Note> : null}
            <label className="flex items-start gap-2 text-sm">
              <input type="checkbox" checked={understood} onChange={(e) => setUnderstood(e.target.checked)} className="mt-1 h-5 w-5" />
              送られるもの・送られないものを読み、理解しました。いつでも抜けられることも分かりました。
            </label>
            <Button disabled={!canJoin} onClick={() => joinClassroom(normalized)} data-testid="join">
              この教室に参加する
            </Button>
          </Card>
          <Note>保護者の方へ: 参加の前に、設定 → 保護者の方・説明をご覧ください。塾には個人の記録は渡りません。</Note>
        </>
      )}
    </PageShell>
  );
}
