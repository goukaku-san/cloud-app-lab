"use client";

import { useState } from "react";
import { useGame } from "@/game/store/GameProvider";
import { Button, Card, Note, PageShell } from "@/components/ui";
import { ClassroomSky, SummaryTable } from "@/components/ClassroomSky";
import { MOCK_DEMO_CODE, normalizeCode } from "@/game/classroom/client";
import { NOT_SENT_FIELDS, SENT_FIELDS, type ClassroomSummary } from "@/game/classroom/protocol";

// 塾・教育機関向けの画面。合計と星空だけが出る。個人は一切出ない。
export default function JukuPage() {
  const { classroomClient } = useGame();
  const mock = classroomClient.mode === "mock";
  const [token, setToken] = useState(mock ? "mock" : "");
  const [code, setCode] = useState(mock ? MOCK_DEMO_CODE : "");
  const [summary, setSummary] = useState<ClassroomSummary | null>(null);
  const [created, setCreated] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  const load = async () => {
    setMessage(null);
    try {
      setSummary(await classroomClient.getAdminSummary(normalizeCode(code), token, 28));
    } catch (e) {
      setSummary(null);
      setMessage(`取得できませんでした（${(e as Error).message}）。トークンと教室コードを確認してください。`);
    }
  };
  const create = async () => {
    setMessage(null);
    try {
      const r = await classroomClient.createClassroom(token);
      setCreated(r.code);
      setCode(r.code);
    } catch (e) {
      setMessage(`教室を作れませんでした（${(e as Error).message}）。`);
    }
  };

  return (
    <PageShell title="塾・教育機関の方へ" backHref="/about" backLabel="説明">
      {mock ? (
        <p className="rounded-xl bg-star/40 px-3 py-2 text-sm font-semibold" data-testid="juku-mock-label">
          モック（架空データ）: 集計サーバーに接続していません。ここで見える数字はすべて架空です。
        </p>
      ) : (
        <Note>接続先: {classroomClient.baseUrl}</Note>
      )}
      <Card>
        <h2 className="font-bold">教室の星図でできること</h2>
        <p className="mt-1 text-sm leading-relaxed">
          教室コードを生徒に配ると、生徒が現実で行動して帰還した回数が、教室の星空として集まります。教室に掲示したり、保護者会で見せたりできます。
        </p>
        <h3 className="mt-3 text-sm font-bold">先生に見えるもの</h3>
        <ul className="list-disc pl-5 text-sm">
          <li>教室ごとの、日ごとの帰還の合計と参加端末の数</li>
          <li>参加端末が少ない日は「表示しない」とだけ出ます</li>
        </ul>
        <h3 className="mt-3 text-sm font-bold">先生に見えないもの（送られてもいません）</h3>
        <ul className="list-disc pl-5 text-sm">
          {NOT_SENT_FIELDS.map((f) => (
            <li key={f}>{f}</li>
          ))}
          <li>教室どうしの比較や順位</li>
        </ul>
        <Note>生徒の端末から送られるのは {SENT_FIELDS.join("・")} の 3 つだけです。帰還は自己申告であり、学習の証明ではありません。参加の強制や、参加・不参加を評価に使うことは契約で禁止します。</Note>
      </Card>
      <Card className="flex flex-col gap-3">
        <h2 className="font-bold">教室の画面</h2>
        <label className="flex flex-col gap-1 text-sm font-semibold">
          塾のトークン
          <input type="password" value={token} onChange={(e) => setToken(e.target.value)} autoComplete="off" className="min-h-12 rounded-2xl border border-line bg-white px-4 font-normal focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-dusk" />
        </label>
        <label className="flex flex-col gap-1 text-sm font-semibold">
          教室コード
          <input type="text" value={code} onChange={(e) => setCode(e.target.value)} autoComplete="off" maxLength={9} className="min-h-12 rounded-2xl border border-line bg-white px-4 font-mono text-lg font-normal tracking-wider focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-dusk" />
        </label>
        <div className="grid grid-cols-2 gap-2">
          <Button onClick={load} data-testid="juku-load">
            合計を見る
          </Button>
          <Button variant="secondary" onClick={create} data-testid="juku-create">
            新しい教室コード
          </Button>
        </div>
        {created ? (
          <p className="text-sm" data-testid="juku-created">
            新しい教室コード: <strong className="font-mono tracking-wider">{created}</strong>（生徒に配ってください）
          </p>
        ) : null}
        {message ? <Note role="alert">{message}</Note> : null}
      </Card>
      {summary ? (
        <Card>
          <p className="text-sm text-ink-soft">教室 {summary.code} / 最小表示人数 {summary.k} 台</p>
          <ClassroomSky summary={summary} label={`教室 ${summary.code} の星空`} />
          <p className="mt-2 text-sm font-semibold" data-testid="juku-week-total">
            この 7 日の帰還の合計: {summary.weekTotal} 回{summary.weekSuppressedDays > 0 ? `（表示しない日が ${summary.weekSuppressedDays} 日）` : ""}
          </p>
          <p className="rounded-xl bg-paper px-3 py-2 text-xs">帰還は生徒の自己申告であり、学習の証明ではありません。</p>
          <div className="mt-2">
            <SummaryTable summary={summary} />
          </div>
        </Card>
      ) : null}
      <Note>お申し込み・お問い合わせの窓口は公開時に設けます。料金はこの版では提示していません。</Note>
    </PageShell>
  );
}
