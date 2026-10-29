// 時計の抽象化。初期版は端末時計を使う（設計書 R1 参照）。
// サーバー時刻を使う段階では、この Clock の実装を差し替える。
export interface Clock {
  now(): Date;
}

export const deviceClock: Clock = {
  now: () => new Date(),
};
