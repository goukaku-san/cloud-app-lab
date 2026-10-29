"use client";

import { useEffect, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { useGame } from "@/game/store/GameProvider";
import { Button, Card, Loading, Note, PageShell } from "@/components/ui";

export default function IntroPage() {
  const { state, ready, createPlayer, persistent } = useGame();
  const router = useRouter();
  const [nickname, setNickname] = useState("");
  const [leaving, setLeaving] = useState(false);

  useEffect(() => {
    if (ready && state.player && !leaving) router.replace("/room");
  }, [ready, state.player, leaving, router]);

  if (!ready) return <Loading />;

  const onSubmit = (e: FormEvent) => {
    e.preventDefault();
    setLeaving(true);
    createPlayer(nickname);
    router.push("/avatar");
  };

  return (
    <PageShell title="受験生の鏡">
      <p className="text-2xl font-bold leading-snug">閉じるほど、物語が動き出す。</p>
      <Card>
        <h2 className="font-bold">この作品の約束</h2>
        <ul className="mt-2 list-disc space-y-1 pl-5 text-sm leading-relaxed">
          <li>ゲームで小さな目標を選び、端末を置いて、現実で行動します。戻ると、鏡の自分と部屋が変わります。</li>
          <li>行動は自己申告です。「やった」「少しやった」「今日は休んだ」のどれを選んでも、部屋は前に進みます。罰も減点もありません。</li>
          <li>連続記録や順位はありません。通知も送りません。</li>
          <li>データはこの端末の中だけに保存され、外部には送りません。端末を変えたりブラウザのデータを消したりすると記録も消えます。</li>
          <li>学習の提案はルールにもとづく固定の候補です。この版では AI を使っていません。</li>
        </ul>
      </Card>
      <form onSubmit={onSubmit} className="flex flex-col gap-3">
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
            className="min-h-12 rounded-2xl border border-line bg-white px-4 text-base font-normal focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-dusk"
          />
        </label>
        <Note>本名や学校名は入れないでください。ニックネームはこの端末の中でだけ使われます。</Note>
        {!persistent ? (
          <Note role="alert">この端末（またはブラウザの設定）では保存ができないため、閉じると記録が消えます。</Note>
        ) : null}
        <Button type="submit" className="w-full">
          はじめる
        </Button>
      </form>
    </PageShell>
  );
}
