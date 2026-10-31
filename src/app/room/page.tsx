"use client";

import { useGame } from "@/game/store/GameProvider";
import { useRouteGuard } from "@/components/useRouteGuard";
import { MirrorRoom } from "@/components/MirrorRoom";
import { PreviewOverlay } from "@/components/PreviewOverlay";
import { Card, LinkButton, Loading, Note, PageShell } from "@/components/ui";
import { ROOM_STAGES } from "@/game/content/roomStages";
import { EPILOGUE_THEME, STORY_CHAPTERS } from "@/game/content/story";
import { dayKeyOf } from "@/game/logic/time";
import { seasonOf } from "@/game/logic/season";

export default function RoomPage() {
  const ok = useRouteGuard({ active: "redirect" });
  const { state, markPreviewSeen, persistent, clock } = useGame();
  if (!ok || !state.player) return <Loading />;

  const { world, player } = state;
  const stage = ROOM_STAGES[world.roomStage];
  const todayKey = dayKeyOf(clock.now());
  const season = seasonOf(clock.now());
  const returnsToday = state.sessions.filter(
    (s) => s.returnedAt && s.selfReport !== "skip" && dayKeyOf(new Date(s.returnedAt)) === todayKey,
  ).length;
  const hasStarted = world.activeDays.length > 0;
  const chapter = STORY_CHAPTERS[world.chapter - 1];
  // 最終章を過ぎたら章番号は進まない。見出しだけ「その後の日々」に替えて、同じ章名が何週間も居座らないようにする
  const inEpilogue = world.activeDays.length > STORY_CHAPTERS.length;
  const chapterLabel = inEpilogue ? `第${world.chapter}章のあと「${EPILOGUE_THEME}」` : `第${world.chapter}章「${chapter.theme}」`;
  const who = player.nickname ? `${player.nickname}の` : "";
  // 物語の記録: 帰還した日の数（減らない。連続かどうかは数えない）
  const storyRead = Math.min(world.activeDays.length, STORY_CHAPTERS.length);

  return (
    <PageShell title={`${who}鏡の部屋`}>
      {!state.previewSeen ? <PreviewOverlay avatar={player.avatar} season={season} onClose={markPreviewSeen} /> : null}
      <div data-testid="room" data-growth={world.growth} data-stage={world.roomStage}>
        <MirrorRoom stage={world.roomStage} objects={world.unlockedObjects} avatar={player.avatar} season={season} />
      </div>
      <Card>
        <div className="flex items-start justify-between gap-2">
          <p className="text-lg font-bold" data-testid="room-stage">
            {stage.name}
          </p>
          <p
            className="shrink-0 rounded-full border-2 border-ink bg-star/60 px-3 py-0.5 text-xs font-black"
            data-testid="story-progress"
          >
            物語の記録 {storyRead}/{STORY_CHAPTERS.length}
          </p>
        </div>
        <p className="text-sm text-ink-soft">{stage.description}</p>
        <p className="mt-2 text-sm">
          {hasStarted ? chapterLabel : "物語は、最初の出発から始まります。"}
        </p>
        <p className="text-sm" data-testid="today-status">
          {returnsToday === 0 ? "今日はまだ出発していません。" : `今日は${returnsToday}回、帰還しました。`}
        </p>
      </Card>
      <LinkButton href="/plan" variant="primary" className="w-full">
        作戦会議へ
      </LinkButton>
      <div className="grid grid-cols-3 gap-2">
        <LinkButton href="/avatar" size="sm">
          姿を変える
        </LinkButton>
        <LinkButton href="/log" size="sm">
          旅の記録
        </LinkButton>
        <LinkButton href="/settings" size="sm">
          設定
        </LinkButton>
      </div>
      <div className="grid grid-cols-2 gap-2">
        <LinkButton href="/quiz" size="sm">
          一問の魔法（任意）
        </LinkButton>
        <LinkButton href="/stars" size="sm">
          星図（デモ）
        </LinkButton>
      </div>
      <Note>部屋はあなたの自己申告にもとづいて変わります。実際の学習を証明するものではありません。</Note>
      {!persistent ? <Note role="alert">この端末では保存ができないため、閉じると記録が消えます。</Note> : null}
    </PageShell>
  );
}
