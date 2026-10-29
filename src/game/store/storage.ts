import { GAME_STATE_VERSION, type GameState } from "@/game/types";

// データアクセス層の抽象化（docs/03-data-model.md）。
// 初期版は端末内の IndexedDB のみ。将来の同期はこのインターフェースの実装追加で対応する。
export interface StorageAdapter {
  load(): Promise<GameState | null>;
  save(state: GameState): Promise<void>;
  clear(): Promise<void>;
}

export const DB_NAME = "kagami";
export const STORE_NAME = "state";
export const RECORD_KEY = "game";

export class MemoryStorage implements StorageAdapter {
  private value: GameState | null = null;
  async load(): Promise<GameState | null> {
    return this.value;
  }
  async save(state: GameState): Promise<void> {
    this.value = state;
  }
  async clear(): Promise<void> {
    this.value = null;
  }
}

function requestToPromise<T>(req: IDBRequest<T>): Promise<T> {
  return new Promise((resolve, reject) => {
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error ?? new Error("IndexedDB request failed"));
  });
}

function txDone(tx: IDBTransaction): Promise<void> {
  return new Promise((resolve, reject) => {
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error ?? new Error("IndexedDB transaction failed"));
    tx.onabort = () => reject(tx.error ?? new Error("IndexedDB transaction aborted"));
  });
}

export class IndexedDbStorage implements StorageAdapter {
  private dbPromise: Promise<IDBDatabase> | null = null;

  constructor(private readonly factory: IDBFactory) {}

  private open(): Promise<IDBDatabase> {
    if (!this.dbPromise) {
      this.dbPromise = new Promise((resolve, reject) => {
        const req = this.factory.open(DB_NAME, 1);
        req.onupgradeneeded = () => {
          const db = req.result;
          if (!db.objectStoreNames.contains(STORE_NAME)) db.createObjectStore(STORE_NAME);
        };
        req.onsuccess = () => resolve(req.result);
        req.onerror = () => reject(req.error ?? new Error("IndexedDB open failed"));
        req.onblocked = () => reject(new Error("IndexedDB open blocked"));
      });
    }
    return this.dbPromise;
  }

  async load(): Promise<GameState | null> {
    const db = await this.open();
    const tx = db.transaction(STORE_NAME, "readonly");
    const value = await requestToPromise(tx.objectStore(STORE_NAME).get(RECORD_KEY));
    await txDone(tx);
    return isGameState(value) ? value : null;
  }

  async save(state: GameState): Promise<void> {
    const db = await this.open();
    const tx = db.transaction(STORE_NAME, "readwrite");
    tx.objectStore(STORE_NAME).put(state, RECORD_KEY);
    await txDone(tx);
  }

  async clear(): Promise<void> {
    const db = await this.open();
    const tx = db.transaction(STORE_NAME, "readwrite");
    tx.objectStore(STORE_NAME).clear();
    await txDone(tx);
  }
}

export function isGameState(value: unknown): value is GameState {
  if (!value || typeof value !== "object") return false;
  const v = value as Partial<GameState>;
  return (
    v.version === GAME_STATE_VERSION &&
    typeof v.world === "object" &&
    v.world !== null &&
    Array.isArray(v.sessions) &&
    ("player" in v)
  );
}

export interface StorageHandle {
  adapter: StorageAdapter;
  persistent: boolean;
}

/** 利用可能なら IndexedDB、使えない環境ではメモリ保存にフォールバックする。 */
export async function createStorage(factory?: IDBFactory): Promise<StorageHandle> {
  const f = factory ?? (typeof indexedDB !== "undefined" ? indexedDB : undefined);
  if (!f) return { adapter: new MemoryStorage(), persistent: false };
  const adapter = new IndexedDbStorage(f);
  try {
    await adapter.load();
    return { adapter, persistent: true };
  } catch {
    return { adapter: new MemoryStorage(), persistent: false };
  }
}
