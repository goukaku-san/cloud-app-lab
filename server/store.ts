// 集計サーバーの保存層。保存するのは教室コード・日付・合計・日替わりハッシュ（当日分のみ）だけ。
// 個人の記録、ニックネーム、申告の内訳、時間帯、IP は保存しない。
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import type { MetricsDay, PulseEvent } from "../src/game/classroom/protocol.ts";

export interface ClassroomRecord {
  code: string;
  ownerId: string;
  createdAt: string;
}

export interface DayRecord {
  dayKey: string;
  returns: number;
  participants: number;
}

export interface AggregateStore {
  createClassroom(rec: ClassroomRecord): Promise<void>;
  getClassroom(code: string): Promise<ClassroomRecord | null>;
  recordReturn(code: string, dayKey: string, hash: string, perHashCap: number): Promise<{ counted: boolean }>;
  listDays(code: string, dayKeys: string[]): Promise<DayRecord[]>;
  recordPulse(dayKey: string, hash: string, event: PulseEvent, cap: number): Promise<{ counted: boolean }>;
  listPulse(dayKeys: string[]): Promise<MetricsDay[]>;
  /** keepFromDayKey より前の日のハッシュ表を消す（合計は残す）。 */
  purgeHashes(keepFromDayKey: string): Promise<void>;
}

interface DayBucket {
  returns: number;
  hashes: Record<string, number>; // 日替わりハッシュ → その日の回数（当日分のみ保持）
  participants: number; // ハッシュ表を消した後も人数は残す
}

interface PulseBucket {
  opens: number;
  returns: number;
  hashes: Record<string, { open: number; return: number }>;
  devices: number;
}

interface Snapshot {
  classrooms: Record<string, ClassroomRecord>;
  days: Record<string, DayBucket>; // `${code}:${dayKey}`
  pulse: Record<string, PulseBucket>; // dayKey
}

export class MemoryStore implements AggregateStore {
  protected data: Snapshot = { classrooms: {}, days: {}, pulse: {} };

  async createClassroom(rec: ClassroomRecord): Promise<void> {
    this.data.classrooms[rec.code] = rec;
    await this.persist();
  }

  async getClassroom(code: string): Promise<ClassroomRecord | null> {
    return this.data.classrooms[code] ?? null;
  }

  async recordReturn(code: string, dayKey: string, hash: string, perHashCap: number): Promise<{ counted: boolean }> {
    const key = `${code}:${dayKey}`;
    const bucket = (this.data.days[key] ??= { returns: 0, hashes: {}, participants: 0 });
    const used = bucket.hashes[hash] ?? 0;
    if (used >= perHashCap) return { counted: false };
    if (used === 0) bucket.participants += 1;
    bucket.hashes[hash] = used + 1;
    bucket.returns += 1;
    await this.persist();
    return { counted: true };
  }

  async listDays(code: string, dayKeys: string[]): Promise<DayRecord[]> {
    return dayKeys.map((dayKey) => {
      const b = this.data.days[`${code}:${dayKey}`];
      return { dayKey, returns: b?.returns ?? 0, participants: b?.participants ?? 0 };
    });
  }

  async recordPulse(dayKey: string, hash: string, event: PulseEvent, cap: number): Promise<{ counted: boolean }> {
    const bucket = (this.data.pulse[dayKey] ??= { opens: 0, returns: 0, hashes: {}, devices: 0 });
    const h = (bucket.hashes[hash] ??= { open: 0, return: 0 });
    if (h.open === 0 && h.return === 0) bucket.devices += 1;
    if (h[event] >= cap) return { counted: false };
    h[event] += 1;
    if (event === "open") bucket.opens += 1;
    else bucket.returns += 1;
    await this.persist();
    return { counted: true };
  }

  async listPulse(dayKeys: string[]): Promise<MetricsDay[]> {
    return dayKeys.map((dayKey) => {
      const b = this.data.pulse[dayKey];
      return { dayKey, opens: b?.opens ?? 0, returns: b?.returns ?? 0, devices: b?.devices ?? 0 };
    });
  }

  async purgeHashes(keepFromDayKey: string): Promise<void> {
    for (const [key, bucket] of Object.entries(this.data.days)) {
      const dayKey = key.slice(key.indexOf(":") + 1);
      if (dayKey < keepFromDayKey) bucket.hashes = {};
    }
    for (const [dayKey, bucket] of Object.entries(this.data.pulse)) {
      if (dayKey < keepFromDayKey) bucket.hashes = {};
    }
    await this.persist();
  }

  /** テストと点検用: 保存内容をそのまま返す。 */
  snapshot(): Snapshot {
    return JSON.parse(JSON.stringify(this.data)) as Snapshot;
  }

  protected async persist(): Promise<void> {
    // メモリ実装は何もしない
  }
}

/** JSON ファイルに保存する実装（クローズド試行用）。本番規模では PostgreSQL 実装に差し替える。 */
export class FileStore extends MemoryStore {
  private readonly file: string;
  private writing: Promise<void> = Promise.resolve();

  constructor(file: string) {
    super();
    this.file = file;
  }

  async load(): Promise<void> {
    try {
      const raw = await readFile(this.file, "utf8");
      const parsed = JSON.parse(raw) as Partial<Snapshot>;
      this.data = {
        classrooms: parsed.classrooms ?? {},
        days: parsed.days ?? {},
        pulse: parsed.pulse ?? {},
      };
    } catch {
      this.data = { classrooms: {}, days: {}, pulse: {} };
    }
  }

  protected async persist(): Promise<void> {
    const json = JSON.stringify(this.data);
    this.writing = this.writing.then(async () => {
      await mkdir(path.dirname(this.file), { recursive: true });
      await writeFile(this.file, json, "utf8");
    });
    await this.writing;
  }
}
