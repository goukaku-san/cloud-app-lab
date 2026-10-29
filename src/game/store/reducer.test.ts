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

  it("教室に参加すると秘密値ができ、抜けると送信待ちの帰還も消える", () => {
    let s = gameReducer(createInitialState(), { type: "createPlayer", id: "p1", now });
    s = gameReducer(s, { type: "joinClassroom", code: "ABCD-2345", secret: "s".repeat(64), consentVersion: "2026-10-29", now });
    expect(s.classroom?.code).toBe("ABCD-2345");
    expect(s.deviceSecret).toBe("s".repeat(64));
    s = gameReducer(s, { type: "outboxAdd", item: { id: "o1", kind: "return", dayKey: "2026-10-29", hash: "a".repeat(64), code: "ABCD-2345" } });
    s = gameReducer(s, { type: "outboxAdd", item: { id: "o2", kind: "pulse", dayKey: "2026-10-29", hash: "a".repeat(64), event: "open" } });
    expect(s.outbox).toHaveLength(2);
    s = gameReducer(s, { type: "leaveClassroom" });
    expect(s.classroom).toBeNull();
    expect(s.outbox.map((o) => o.kind)).toEqual(["pulse"]);
    s = gameReducer(s, { type: "outboxRemove", ids: ["o2"] });
    expect(s.outbox).toHaveLength(0);
  });

  it("古い保存データに教室の項目がなくても補われる", () => {
    const old = { ...createInitialState() } as Record<string, unknown>;
    delete old.classroom;
    delete old.outbox;
    const s = gameReducer(createInitialState(), { type: "hydrate", state: old as never });
    expect(s.classroom).toBeNull();
    expect(s.outbox).toEqual([]);
  });

  it("reset で初期状態に戻る", () => {
    let s = gameReducer(createInitialState(), { type: "createPlayer", id: "p1", now });
    s = gameReducer(s, { type: "markPreviewSeen" });
    expect(gameReducer(s, { type: "reset" })).toEqual(createInitialState());
  });
});
