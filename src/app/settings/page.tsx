"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useGame } from "@/game/store/GameProvider";
import { useRouteGuard } from "@/components/useRouteGuard";
import { Button, Card, LinkButton, Loading, Note, PageShell } from "@/components/ui";

function Switch({ label, checked, onChange, disabled, note }: { label: string; checked: boolean; onChange?: (v: boolean) => void; disabled?: boolean; note?: string }) {
  return (
    <div className="flex items-center justify-between gap-3 py-2">
      <div>
        <p className="font-semibold">{label}</p>
        {note ? <p className="text-xs text-ink-soft">{note}</p> : null}
      </div>
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        aria-label={label}
        disabled={disabled}
        onClick={() => onChange?.(!checked)}
        className={`relative h-8 w-14 shrink-0 rounded-full border transition-colors focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-dusk disabled:opacity-40 ${
          checked ? "border-sage-deep bg-sage" : "border-line bg-white"
        }`}
      >
        <span aria-hidden="true" className={`absolute top-0.5 h-6 w-6 rounded-full bg-white shadow transition-all ${checked ? "left-7" : "left-0.5"}`} />
        <span className="sr-only">{checked ? "オン" : "オフ"}</span>
      </button>
    </div>
  );
}

export default function SettingsPage() {
  const ok = useRouteGuard({ active: "redirect" });
  const { state, updateSettings, resetAll, persistent } = useGame();
  const router = useRouter();
  const [confirm, setConfirm] = useState(false);
  const [deleting, setDeleting] = useState(false);
  if (!ok || !state.player) return <Loading />;
  const s = state.player.settings;

  const remove = async () => {
    setDeleting(true);
    await resetAll();
    router.replace("/intro");
  };

  return (
    <PageShell title="設定" backHref="/room" backLabel="部屋">
      <Card>
        <h2 className="font-bold">表示と動き</h2>
        <Switch label="動きを減らす" checked={s.reduceMotion} onChange={(v) => updateSettings({ reduceMotion: v })} note="星のまたたきなどのアニメーションを止めます。OS の設定でも止まります。" />
        <Switch label="文字を大きく" checked={s.largeText} onChange={(v) => updateSettings({ largeText: v })} />
      </Card>
      <Card>
        <h2 className="font-bold">音と通知</h2>
        <Switch
          label="音（実験）"
          checked={s.sound}
          onChange={(v) => updateSettings({ sound: v })}
          note="端末内で合成する静かな環境音。音声ファイルや外部通信は使いません。実機での聴感は未検証です。"
        />
        {s.sound ? (
          <label className="flex items-center gap-3 py-2 text-sm">
            音量
            <input
              type="range"
              min={0}
              max={100}
              step={5}
              value={Math.round(s.soundVolume * 100)}
              onChange={(e) => updateSettings({ soundVolume: Number(e.target.value) / 100 })}
              aria-label="音量"
              className="flex-1"
            />
            <span className="w-10 text-right">{Math.round(s.soundVolume * 100)}%</span>
          </label>
        ) : null}
        <p className="py-2 text-sm">
          <span className="font-semibold">通知: </span>この版では通知を送りません。通知の許可も求めません。
        </p>
      </Card>
      <Card>
        <h2 className="font-bold">プライバシーとデータ</h2>
        <p className="mt-1 text-sm leading-relaxed">
          すべてのデータはこの端末の中だけに保存され、外部には送信されません。端末の紛失やブラウザのデータ削除で記録は消えます。
          {persistent ? "" : " 現在この端末では保存ができません。"}
        </p>
        <LinkButton href="/about" className="mt-3 w-full">
          保護者の方・説明を読む
        </LinkButton>
      </Card>
      <Card>
        <h2 className="font-bold">データの削除</h2>
        <p className="mt-1 text-sm">分身・部屋・記録をすべてこの端末から消します。元に戻せません。</p>
        {confirm ? (
          <div className="mt-3 flex flex-col gap-2">
            <Button variant="danger" onClick={remove} disabled={deleting} data-testid="delete-confirm">
              本当に削除する
            </Button>
            <Button variant="ghost" onClick={() => setConfirm(false)}>
              やめる
            </Button>
          </div>
        ) : (
          <Button variant="danger" className="mt-3 w-full" onClick={() => setConfirm(true)} data-testid="delete">
            すべてのデータを削除
          </Button>
        )}
      </Card>
      <Note>バージョン 0.1（実機検証前のデモ）</Note>
    </PageShell>
  );
}
