// 実験機能: 端末内で合成する静かな環境音。音声ファイルも外部通信も使わない。
// 初期 OFF。設定で ON にしたときだけ鳴る。実機での聴感は未検証。
export class AmbientSound {
  private ctx: AudioContext | null = null;
  private master: GainNode | null = null;
  private stopping: Promise<void> | null = null;

  get running(): boolean {
    return this.ctx !== null;
  }

  async start(volume: number): Promise<void> {
    if (this.ctx || typeof window === "undefined") return;
    const Ctor = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!Ctor) return;
    const ctx = new Ctor();
    const master = ctx.createGain();
    master.gain.value = 0;
    master.connect(ctx.destination);

    // 静かな和音（A3, C4, E4）をゆっくり揺らす
    const freqs = [220, 261.63, 329.63];
    freqs.forEach((f, i) => {
      const osc = ctx.createOscillator();
      osc.type = "sine";
      osc.frequency.value = f;
      const g = ctx.createGain();
      g.gain.value = 0.06;
      const lfo = ctx.createOscillator();
      lfo.frequency.value = 0.05 + i * 0.02;
      const lfoGain = ctx.createGain();
      lfoGain.gain.value = 0.03;
      lfo.connect(lfoGain).connect(g.gain);
      osc.connect(g).connect(master);
      osc.start();
      lfo.start();
    });

    this.ctx = ctx;
    this.master = master;
    if (ctx.state === "suspended") {
      try {
        await ctx.resume();
      } catch {
        // ユーザー操作後に resume() を呼び直す
      }
    }
    master.gain.setTargetAtTime(this.clamp(volume), ctx.currentTime, 1.5);
  }

  async resume(): Promise<void> {
    if (this.ctx && this.ctx.state === "suspended") {
      try {
        await this.ctx.resume();
      } catch {
        // 無視
      }
    }
  }

  setVolume(volume: number): void {
    if (!this.ctx || !this.master) return;
    this.master.gain.setTargetAtTime(this.clamp(volume), this.ctx.currentTime, 0.2);
  }

  async stop(): Promise<void> {
    const ctx = this.ctx;
    const master = this.master;
    this.ctx = null;
    this.master = null;
    if (!ctx || !master) return;
    master.gain.setTargetAtTime(0, ctx.currentTime, 0.4);
    this.stopping = new Promise((resolve) => setTimeout(resolve, 1200)).then(() => ctx.close().catch(() => undefined));
    await this.stopping;
  }

  private clamp(v: number): number {
    return Math.max(0, Math.min(1, v)) * 0.5;
  }
}
