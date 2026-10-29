import { describe, expect, it } from "vitest";
import { gameReducer } from "@/game/store/reducer";
import { createInitialState } from "@/game/types";
import { QUEST_POOL } from "@/game/content/quests";

const now = new Date(2026, 9, 29, 12, 0).toISOString();
const later = new Date(2026, 9, 29, 12, 15).toISOString();

describe("gameReducer", () => {
  it("ニックネームなしでもプレイヤーを作れる", () => {
    const s = gameReducer(createInitialState(), { type: "createPlayer", id: "p1", nickname: "   ", now });
    expect(s.player?.id).toBe("p1");
    expect(s.player?.nickname).toBeUndefined();
    expect(s.player?.settings.notifications).toBe(false);
  });

  it("出発 → 帰還 で状態が進み、出発中は二重に出発できない", () => {
    let s = gameReducer(createInitialState(), { type: "createPlayer", id: "p1", now });
    s = gameReducer(s, { type: "startSession", id: "s1", quest: QUEST_POOL[0], now });
    expect(s.activeSessionId).toBe("s1");
    const dup = gameReducer(s, { type: "startSession", id: "s2", quest: QUEST_POOL[1], now });
    expect(dup.sessions).toHaveLength(1);
    s = gameReducer(s, { type: "returnSession", report: "done", reflection: "よかった", now: later });
    expect(s.activeSessionId).toBeNull();
    expect(s.lastChange?.afterStage).toBe(1);
    expect(s.sessions[0].selfReport).toBe("done");
    expect(s.sessions[0].elapsedMinutes).toBe(15);
    expect(s.sessions[0].reflection).toBe("よかった");
  });

  it("出発中でない帰還は無視する", () => {
    const s = gameReducer(createInitialState(), { type: "returnSession", report: "done", now });
    expect(s).toEqual(createInitialState());
  });

  it("設定変更しても通知は常に送らない", () => {
    let s = gameReducer(createInitialState(), { type: "createPlayer", id: "p1", now });
    s = gameReducer(s, { type: "updateSettings", patch: { reduceMotion: true, largeText: true } });
    expect(s.player?.settings.reduceMotion).toBe(true);
    expect(s.player?.settings.notifications).toBe(false);
  });

  it("reset で初期状態に戻る", () => {
    let s = gameReducer(createInitialState(), { type: "createPlayer", id: "p1", now });
    s = gameReducer(s, { type: "markPreviewSeen" });
    expect(gameReducer(s, { type: "reset" })).toEqual(createInitialState());
  });
});
