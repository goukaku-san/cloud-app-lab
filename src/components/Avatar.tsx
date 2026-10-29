import type { AvatarConfig } from "@/game/types";

// 鏡の自分。性別・容姿の固定観念に依存しない丸いシルエット。
export const HAIR_STYLES = ["ふんわり", "ながめ", "おだんご"] as const;
export const OUTFIT_COLORS = [
  { name: "れんが", hex: "#c9704a" },
  { name: "わかくさ", hex: "#6f9f78" },
  { name: "たそがれ", hex: "#5b6c8f" },
  { name: "からし", hex: "#d9a441" },
] as const;
export const COMPANIONS = ["なし", "ねこ", "ことり"] as const;

const SKIN = "#f1d2b6";
const HAIR = "#4a3a36";

/** 部屋の SVG に埋め込む分身（100×120 の座標系）。 */
export function AvatarFigure({ avatar, x = 0, y = 0, scale = 1 }: { avatar: AvatarConfig; x?: number; y?: number; scale?: number }) {
  const outfit = OUTFIT_COLORS[avatar.outfitColor]?.hex ?? OUTFIT_COLORS[0].hex;
  return (
    <g transform={`translate(${x} ${y}) scale(${scale})`}>
      {/* 体 */}
      <rect x="30" y="62" width="40" height="52" rx="16" fill={outfit} />
      {/* 髪（ながめ は後ろ髪を先に描く） */}
      {avatar.hairStyle === 1 ? <path d="M27 40 Q50 6 73 40 L76 78 Q50 68 24 78 Z" fill={HAIR} /> : null}
      {/* 顔 */}
      <circle cx="50" cy="40" r="22" fill={SKIN} />
      <circle cx="42" cy="40" r="2.2" fill={HAIR} />
      <circle cx="58" cy="40" r="2.2" fill={HAIR} />
      <path d="M44 49 Q50 54 56 49" stroke={HAIR} strokeWidth="2" fill="none" strokeLinecap="round" />
      <circle cx="37" cy="46" r="3" fill="#f4a9a0" opacity="0.6" />
      <circle cx="63" cy="46" r="3" fill="#f4a9a0" opacity="0.6" />
      {/* 前髪 */}
      <path d="M28 38 Q50 8 72 38 Q62 26 50 28 Q38 26 28 38 Z" fill={HAIR} />
      {avatar.hairStyle === 2 ? <circle cx="50" cy="15" r="9" fill={HAIR} /> : null}
      {/* 相棒 */}
      {avatar.companion === 1 ? (
        <g transform="translate(70 92)">
          <circle cx="12" cy="12" r="10" fill="#8c7b74" />
          <path d="M4 6 L6 -2 L12 5 Z" fill="#8c7b74" />
          <path d="M20 6 L18 -2 L12 5 Z" fill="#8c7b74" />
          <circle cx="9" cy="11" r="1.5" fill="#2e2222" />
          <circle cx="15" cy="11" r="1.5" fill="#2e2222" />
        </g>
      ) : null}
      {avatar.companion === 2 ? (
        <g transform="translate(4 28)">
          <ellipse cx="10" cy="10" rx="9" ry="7" fill="#7fb0c8" />
          <circle cx="16" cy="6" r="5" fill="#7fb0c8" />
          <path d="M20 6 L25 7 L20 8 Z" fill="#e8a33c" />
          <circle cx="17" cy="5" r="1.2" fill="#2e2222" />
        </g>
      ) : null}
    </g>
  );
}

/** 単体表示用（カスタマイズ画面）。 */
export function AvatarPreview({ avatar, size = 160, label = "鏡の自分" }: { avatar: AvatarConfig; size?: number; label?: string }) {
  return (
    <svg
      viewBox="0 0 100 120"
      width={size}
      height={size * 1.2}
      role="img"
      aria-label={label}
      className="mx-auto"
    >
      <AvatarFigure avatar={avatar} />
    </svg>
  );
}
