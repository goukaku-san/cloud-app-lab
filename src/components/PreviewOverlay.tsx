"use client";

import { useEffect, useRef } from "react";
import type { AvatarConfig } from "@/game/types";
import { MirrorRoom } from "@/components/MirrorRoom";
import { Button, Note } from "@/components/ui";
import { objectsForGrowth, ROOM_STAGES, STAGE_THRESHOLDS } from "@/game/content/roomStages";

const PREVIEW_STAGE = 3;

// 初回 3 分以内に「未来の部屋」を見せる。プレビューであることを明示し、成長点は付与しない。
export function PreviewOverlay({ avatar, onClose }: { avatar: AvatarConfig; onClose: () => void }) {
  const headingRef = useRef<HTMLHeadingElement>(null);
  useEffect(() => {
    headingRef.current?.focus();
  }, []);
  const growth = STAGE_THRESHOLDS[PREVIEW_STAGE];

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="preview-title"
      data-testid="preview-dialog"
      className="fixed inset-0 z-20 flex items-end justify-center overflow-y-auto bg-ink/40 p-3 sm:items-center"
    >
      <div className="anim-fade-in my-auto w-full max-w-md rounded-3xl bg-paper p-4 shadow-lg">
        <h2 id="preview-title" ref={headingRef} tabIndex={-1} className="text-lg font-bold outline-none">
          未来の部屋のプレビュー
        </h2>
        <p className="mt-1 rounded-xl bg-star/40 px-3 py-2 text-sm font-semibold">
          これはプレビューです。実際の行動で、あなたの部屋がこう変わっていきます。成長はまだ加算されていません。
        </p>
        <div className="mt-3">
          <MirrorRoom
            stage={PREVIEW_STAGE}
            objects={objectsForGrowth(growth)}
            avatar={avatar}
            idPrefix="preview"
            label={`プレビュー: ${ROOM_STAGES[PREVIEW_STAGE].name}`}
          />
        </div>
        <Note>{ROOM_STAGES[PREVIEW_STAGE].description}</Note>
        <Button className="mt-4 w-full" onClick={onClose}>
          自分の部屋へ
        </Button>
      </div>
    </div>
  );
}
