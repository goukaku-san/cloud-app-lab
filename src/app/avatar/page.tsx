"use client";

import { useRouter } from "next/navigation";
import { useGame } from "@/game/store/GameProvider";
import { useRouteGuard } from "@/components/useRouteGuard";
import { AvatarPreview, COMPANIONS, HAIR_STYLES, OUTFIT_COLORS } from "@/components/Avatar";
import { Button, Card, Loading, Note, PageShell } from "@/components/ui";
import type { AvatarConfig } from "@/game/types";

function OptionGroup<T extends number>({
  label,
  options,
  value,
  onChange,
  swatches,
}: {
  label: string;
  options: readonly string[];
  value: T;
  onChange: (v: T) => void;
  swatches?: readonly string[];
}) {
  return (
    <fieldset className="flex flex-col gap-2">
      <legend className="text-sm font-semibold">{label}</legend>
      <div role="radiogroup" aria-label={label} className="flex flex-wrap gap-2">
        {options.map((name, i) => {
          const selected = value === i;
          return (
            <button
              key={name}
              type="button"
              role="radio"
              aria-checked={selected}
              onClick={() => onChange(i as T)}
              className={`inline-flex min-h-11 items-center gap-2 rounded-2xl border px-4 text-sm font-semibold focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-dusk ${
                selected ? "border-terracotta bg-terracotta text-white" : "border-line bg-white text-ink"
              }`}
            >
              {swatches ? <span aria-hidden="true" className="h-4 w-4 rounded-full border border-white/60" style={{ background: swatches[i] }} /> : null}
              {name}
            </button>
          );
        })}
      </div>
    </fieldset>
  );
}

export default function AvatarPage() {
  const ok = useRouteGuard({ active: "redirect" });
  const { state, setAvatar } = useGame();
  const router = useRouter();
  if (!ok || !state.player) return <Loading />;
  const avatar = state.player.avatar;
  const update = (patch: Partial<AvatarConfig>) => setAvatar({ ...avatar, ...patch });
  const firstTime = state.sessions.length === 0 && !state.previewSeen;

  return (
    <PageShell title="鏡の自分" backHref={firstTime ? undefined : "/room"} backLabel="部屋">
      <Card>
        <AvatarPreview avatar={avatar} />
        <Note>あとからいつでも変えられます。</Note>
      </Card>
      <OptionGroup label="髪型" options={HAIR_STYLES} value={avatar.hairStyle} onChange={(v) => update({ hairStyle: v })} />
      <OptionGroup
        label="服の色"
        options={OUTFIT_COLORS.map((c) => c.name)}
        swatches={OUTFIT_COLORS.map((c) => c.hex)}
        value={avatar.outfitColor}
        onChange={(v) => update({ outfitColor: v })}
      />
      <OptionGroup label="相棒" options={COMPANIONS} value={avatar.companion} onChange={(v) => update({ companion: v })} />
      <Button className="mt-2 w-full" onClick={() => router.push("/room")}>
        この姿にする
      </Button>
    </PageShell>
  );
}
