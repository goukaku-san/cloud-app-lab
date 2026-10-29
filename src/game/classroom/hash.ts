// 日替わりハッシュ: 端末内の秘密値と日付から作る。翌日には別の値になり、名寄せできない。
function toHex(bytes: Uint8Array): string {
  let out = "";
  for (const b of bytes) out += b.toString(16).padStart(2, "0");
  return out;
}

/** WebCrypto が使えない環境（非 HTTPS など）向けの決定的フォールバック。暗号学的強度はない。 */
function fallbackHash(input: string): string {
  const bytes = new Uint8Array(32);
  let h1 = 0x811c9dc5;
  let h2 = 0x01000193;
  for (let i = 0; i < input.length; i += 1) {
    const c = input.charCodeAt(i);
    h1 = Math.imul(h1 ^ c, 0x01000193) >>> 0;
    h2 = Math.imul(h2 + c, 0x9e3779b1) >>> 0;
  }
  for (let i = 0; i < 32; i += 1) {
    h1 = Math.imul(h1 ^ (h1 >>> 15), 0x2c1b3c6d) >>> 0;
    h2 = Math.imul(h2 ^ (h2 >>> 13), 0x297a2d39) >>> 0;
    bytes[i] = (h1 ^ h2 ^ i) & 0xff;
  }
  return toHex(bytes);
}

export async function dayHash(secret: string, dayKey: string): Promise<string> {
  const input = `${secret}:${dayKey}`;
  const subtle = globalThis.crypto?.subtle;
  if (subtle) {
    const digest = await subtle.digest("SHA-256", new TextEncoder().encode(input));
    return toHex(new Uint8Array(digest));
  }
  return fallbackHash(input);
}

export function randomSecret(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return toHex(bytes);
}
