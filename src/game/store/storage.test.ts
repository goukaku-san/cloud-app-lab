import { describe, expect, it } from "vitest";
import { IDBFactory } from "fake-indexeddb";
import { createStorage, IndexedDbStorage, isGameState, MemoryStorage } from "@/game/store/storage";
import { createInitialState } from "@/game/types";

describe("IndexedDbStorage", () => {
  it("保存 → 読込 → 削除 ができる", async () => {
    const storage = new IndexedDbStorage(new IDBFactory());
    expect(await storage.load()).toBeNull();
    const state = { ...createInitialState(), previewSeen: true };
    await storage.save(state);
    const loaded = await storage.load();
    expect(loaded).toEqual(state);
    await storage.clear();
    expect(await storage.load()).toBeNull();
  });

  it("別インスタンスでも同じデータベースを読める（再起動の代替）", async () => {
    const factory = new IDBFactory();
    const a = new IndexedDbStorage(factory);
    await a.save({ ...createInitialState(), previewSeen: true });
    const b = new IndexedDbStorage(factory);
    expect((await b.load())?.previewSeen).toBe(true);
  });

  it("壊れたレコードは null として扱う", () => {
    expect(isGameState(null)).toBe(false);
    expect(isGameState({ version: 99 })).toBe(false);
    expect(isGameState(createInitialState())).toBe(true);
  });
});

describe("createStorage", () => {
  it("IndexedDB があれば永続、なければメモリにフォールバック", async () => {
    const withIdb = await createStorage(new IDBFactory());
    expect(withIdb.persistent).toBe(true);
    expect(withIdb.adapter).toBeInstanceOf(IndexedDbStorage);
    const without = await createStorage(undefined);
    expect(without.persistent).toBe(false);
    expect(without.adapter).toBeInstanceOf(MemoryStorage);
  });
});
