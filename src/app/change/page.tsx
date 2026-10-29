"use client";

import { useRef, useState } from "react";
import { useGame } from "@/game/store/GameProvider";
import { useRouteGuard } from "@/components/useRouteGuard";
import { MirrorRoom } from "@/components/MirrorRoom";
import { Button, Card, LinkButton, Loading, Note, PageShell } from "@/components/ui";
import { objectName, ROOM_STAGES } from "@/game/content/roomStages";
import { CAPPED_NOTE, STORY_IS_DRAFT } from "@/game/content/story";
import { REPORT_LABEL } from "@/game/content/labels";
import { dayKeyOf } from "@/game/logic/time";

async function svgToImage(svg: SVGSVGElement): Promise<HTMLImageElement> {
  const xml = new XMLSerializer().serializeToString(svg);
  const url = URL.createObjectURL(new Blob([xml], { type: "image/svg+xml;charset=utf-8" }));
  try {
    const img = new Image();
    await new Promise<void>((resolve, reject) => {
      img.onload = () => resolve();
      img.onerror = () => reject(new Error("svg load failed"));
      img.src = url;
    });
    return img;
  } finally {
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
}

export default function ChangePage() {
  const ok = useRouteGuard({ active: "redirect", requireChange: true });
  const { state, clock } = useGame();
  const beforeRef = useRef<SVGSVGElement>(null);
  const afterRef = useRef<SVGSVGElement>(null);
  const [saveMessage, setSaveMessage] = useState<string | null>(null);

  if (!ok || !state.player || !state.lastChange) return <Loading />;
  const change = state.lastChange;
  const world = state.world;
  const beforeObjects = world.unlockedObjects.filter((id) => !change.newObjects.includes(id));

  const saveImage = async () => {
    try {
      if (!beforeRef.current || !afterRef.current) throw new Error("no svg");
      const [a, b] = await Promise.all([svgToImage(beforeRef.current), svgToImage(afterRef.current)]);
      const w = 360;
      const h = 300;
      const pad = 24;
      const canvas = document.createElement("canvas");
      canvas.width = w * 2 + pad * 3;
      canvas.height = h + pad * 2 + 60;
      const ctx = canvas.getContext("2d");
      if (!ctx) throw new Error("no canvas");
      ctx.fillStyle = "#fbf4e8";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.fillStyle = "#3b2f2f";
      ctx.font = "bold 20px sans-serif";
      ctx.fillText("前", pad, pad + 20);
      ctx.fillText("後", pad * 2 + w, pad + 20);
      ctx.drawImage(a, pad, pad + 32, w, h);
      ctx.drawImage(b, pad * 2 + w, pad + 32, w, h);
      ctx.font = "14px sans-serif";
      ctx.fillStyle = "#6f615c";
      ctx.fillText("受験生の鏡 — 自己申告にもとづく部屋の変化", pad, canvas.height - 12);
      const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, "image/png"));
      if (!blob) throw new Error("no blob");
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = `kagami-${dayKeyOf(clock.now())}.png`;
      link.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      setSaveMessage("画像を保存しました。ニックネームなどの個人情報は含まれていません。");
    } catch {
      setSaveMessage("この端末では画像を保存できませんでした。");
    }
  };

  return (
    <PageShell title="部屋が変わりました">
      <p className="text-sm">
        自己申告: <strong data-testid="change-report">{REPORT_LABEL[change.selfReport]}</strong>
      </p>
      <div className="grid grid-cols-2 gap-2" data-testid="before-after">
        <figure>
          <figcaption className="mb-1 text-center text-sm font-semibold">前</figcaption>
          <MirrorRoom
            svgRef={beforeRef}
            stage={change.beforeStage}
            objects={beforeObjects}
            avatar={state.player.avatar}
            idPrefix="before"
            label={`前: ${ROOM_STAGES[change.beforeStage].name}`}
          />
        </figure>
        <figure>
          <figcaption className="mb-1 text-center text-sm font-semibold">後</figcaption>
          <MirrorRoom
            svgRef={afterRef}
            stage={change.afterStage}
            objects={world.unlockedObjects}
            avatar={state.player.avatar}
            idPrefix="after"
            label={`後: ${ROOM_STAGES[change.afterStage].name}`}
          />
        </figure>
      </div>
      <Card>
        <p className="text-sm text-ink-soft">
          第{change.story.chapter}章{STORY_IS_DRAFT ? "（物語は草案です）" : ""}
        </p>
        <h2 className="text-lg font-bold" data-testid="story-title">
          {change.story.title}
        </h2>
        <p className="mt-1 leading-relaxed">{change.story.text}</p>
      </Card>
      <Card>
        <p className="text-sm">
          部屋: {ROOM_STAGES[change.beforeStage].name} → <strong data-testid="after-stage">{ROOM_STAGES[change.afterStage].name}</strong>
        </p>
        <p className="text-sm" data-testid="growth-delta">
          成長 +{change.growthDelta}
        </p>
        {change.newObjects.length > 0 ? (
          <p className="mt-1 text-sm">現れたもの: {change.newObjects.map(objectName).join("、")}</p>
        ) : null}
        {change.capped ? (
          <p className="mt-2 rounded-xl bg-sage/30 px-3 py-2 text-sm" data-testid="capped-note">
            {CAPPED_NOTE}
          </p>
        ) : null}
      </Card>
      <Note>この変化はあなたの自己申告にもとづきます。実際の学習を証明するものではありません。</Note>
      <div className="flex flex-col gap-2">
        <Button variant="secondary" onClick={saveImage} data-testid="save-image">
          ビフォー・アフターの画像を保存
        </Button>
        {saveMessage ? <Note role="status">{saveMessage}</Note> : null}
        <LinkButton href="/room" variant="primary">
          部屋へ戻る
        </LinkButton>
      </div>
    </PageShell>
  );
}
