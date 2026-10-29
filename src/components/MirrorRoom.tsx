import type { Ref } from "react";
import type { AvatarConfig } from "@/game/types";
import { AvatarFigure } from "@/components/Avatar";
import { ROOM_STAGES } from "@/game/content/roomStages";

// 鏡の部屋。段階（stage）と部屋に現れた物（objects）で描き分ける。時間では変わらない。
const WALL = ["#e9e3da", "#f4e8d6", "#f6ead7", "#f7e3cc", "#e2d6c8", "#ddd0c4"];
const SKY: Array<[string, string]> = [
  ["#d8d5d0", "#c7c3bd"],
  ["#f3e6d2", "#f8efe0"],
  ["#bfe0ee", "#e7f1dc"],
  ["#f6a86b", "#fbd9a3"],
  ["#243253", "#3a4d7a"],
  ["#2a2250", "#45558f"],
];

const STAR_POSITIONS = [
  [214, 56],
  [240, 48],
  [268, 62],
  [296, 50],
  [306, 78],
  [228, 80],
  [256, 70],
  [286, 92],
];

export interface MirrorRoomProps {
  stage: number;
  objects: string[];
  avatar: AvatarConfig;
  label?: string;
  className?: string;
  svgRef?: Ref<SVGSVGElement>;
  idPrefix?: string;
}

export function MirrorRoom({ stage, objects, avatar, label, className = "", svgRef, idPrefix = "room" }: MirrorRoomProps) {
  const s = Math.max(0, Math.min(WALL.length - 1, stage));
  const has = (id: string) => objects.includes(id);
  const night = s >= 4;
  const skyId = `${idPrefix}-sky`;
  const glowId = `${idPrefix}-glow`;
  const stageName = ROOM_STAGES[s]?.name ?? "";

  return (
    <svg
      ref={svgRef}
      viewBox="0 0 360 300"
      width="360"
      height="300"
      role="img"
      aria-label={label ?? `鏡の部屋: ${stageName}`}
      className={`h-auto w-full rounded-3xl border border-line ${className}`}
      data-stage={s}
    >
      <defs>
        <linearGradient id={skyId} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={SKY[s][0]} />
          <stop offset="1" stopColor={SKY[s][1]} />
        </linearGradient>
        <radialGradient id={glowId}>
          <stop offset="0" stopColor="#f2d479" stopOpacity="0.55" />
          <stop offset="1" stopColor="#f2d479" stopOpacity="0" />
        </radialGradient>
      </defs>

      {/* 壁と床 */}
      <rect x="0" y="0" width="360" height="222" fill={WALL[s]} />
      <rect x="0" y="222" width="360" height="78" fill={night ? "#a67f5f" : "#c99a72"} />
      <rect x="0" y="222" width="360" height="4" fill="#8a6a4f" opacity="0.5" />
      {night ? <rect x="0" y="0" width="360" height="222" fill="#1e2440" opacity="0.28" /> : null}

      {/* 壁の地図 */}
      {has("map") ? (
        <g>
          <rect x="34" y="46" width="76" height="54" rx="4" fill="#f6ecd8" stroke="#b89a7a" strokeWidth="2" />
          <path d="M42 86 Q60 60 78 74 T104 58" stroke="#c9704a" strokeWidth="2" fill="none" strokeDasharray="4 3" />
          <circle cx="78" cy="74" r="3" fill="#5b6c8f" />
        </g>
      ) : null}

      {/* 窓 */}
      <rect x="198" y="36" width="124" height="116" rx="6" fill={`url(#${skyId})`} />
      {s >= 2 ? <path d="M198 128 Q236 98 268 122 Q296 104 322 124 L322 152 L198 152 Z" fill={night ? "#2f4a3c" : "#9ccf9a"} /> : null}
      {s === 3 ? <circle cx="292" cy="112" r="14" fill="#fff0b3" opacity="0.9" /> : null}
      {night
        ? STAR_POSITIONS.slice(0, has("star") ? STAR_POSITIONS.length : 3).map(([x, y], i) => (
            <circle
              key={`${x}-${y}`}
              cx={x}
              cy={y}
              r={i % 3 === 0 ? 2.2 : 1.5}
              fill="#f2d479"
              className="anim-twinkle"
              style={{ animationDelay: `${(i * 0.7) % 3}s` }}
            />
          ))
        : null}
      {has("moon") ? <path d="M232 60 a12 12 0 1 0 10 18 a9 9 0 1 1 -10 -18 z" fill="#f7e7a8" /> : null}
      {has("meteor") ? <line x1="312" y1="44" x2="300" y2="52" stroke="#fff6cf" strokeWidth="2" strokeLinecap="round" className="anim-meteor" /> : null}
      {has("sprout") ? (
        <g>
          <path d="M226 150 L226 138" stroke="#4f7a58" strokeWidth="3" strokeLinecap="round" />
          <ellipse cx="221" cy="139" rx="5" ry="3" fill="#8fb996" />
          <ellipse cx="231" cy="136" rx="5" ry="3" fill="#8fb996" />
        </g>
      ) : null}
      {has("flowers") ? (
        <g>
          {[246, 262, 280].map((x, i) => (
            <g key={x}>
              <path d={`M${x} 150 L${x} 136`} stroke="#4f7a58" strokeWidth="2.5" strokeLinecap="round" />
              <circle cx={x} cy="133" r="5" fill={["#f4a9a0", "#f2d479", "#e8a1c8"][i]} />
            </g>
          ))}
        </g>
      ) : null}
      {has("lantern") ? (
        <g>
          <rect x="300" y="128" width="10" height="16" rx="3" fill="#8a6a4f" />
          <rect x="302" y="131" width="6" height="9" fill="#f2d479" />
          <circle cx="305" cy="136" r="16" fill={`url(#${glowId})`} />
        </g>
      ) : null}
      <rect x="194" y="32" width="132" height="124" rx="8" fill="none" stroke="#8a6a4f" strokeWidth="7" />
      <line x1="260" y1="36" x2="260" y2="152" stroke="#8a6a4f" strokeWidth="5" />
      <line x1="198" y1="94" x2="322" y2="94" stroke="#8a6a4f" strokeWidth="5" />
      <rect x="188" y="154" width="144" height="8" rx="3" fill="#a07c5c" />

      {/* カーテン */}
      {has("curtain") ? (
        <g>
          <path d="M186 30 Q196 90 184 160 L206 160 Q212 90 204 30 Z" fill="#e9b8a2" opacity="0.95" className="anim-sway" />
          <path d="M334 30 Q324 90 336 160 L314 160 Q308 90 316 30 Z" fill="#e9b8a2" opacity="0.95" className="anim-sway" />
        </g>
      ) : null}

      {/* 窓辺の鉢と小鳥 */}
      {has("plant") ? (
        <g>
          <path d="M214 154 L222 154 L220 140 L216 140 Z" fill="#b5674d" />
          <path d="M218 140 Q210 128 216 122 Q222 130 218 140 Z" fill="#6f9f78" />
          <path d="M218 140 Q226 126 224 120 Q216 128 218 140 Z" fill="#8fb996" />
        </g>
      ) : null}
      {has("bird") ? (
        <g transform="translate(296 138)">
          <ellipse cx="8" cy="8" rx="8" ry="6" fill="#7fb0c8" />
          <circle cx="14" cy="4" r="4" fill="#7fb0c8" />
          <path d="M18 4 L22 5 L18 6 Z" fill="#e8a33c" />
          <circle cx="15" cy="3" r="1" fill="#2e2222" />
        </g>
      ) : null}

      {/* 椅子とひざ掛け */}
      <rect x="84" y="132" width="52" height="60" rx="8" fill="#9c6b4b" />
      {has("blanket") ? <path d="M84 150 Q110 142 136 150 L136 184 Q110 192 84 184 Z" fill="#8fb996" /> : null}

      {/* 鏡の自分 */}
      <AvatarFigure avatar={avatar} x={72} y={60} scale={0.8} />

      {/* 机 */}
      <rect x="40" y="178" width="170" height="12" rx="4" fill="#b0845f" />
      <rect x="50" y="190" width="10" height="48" fill="#8f6a4a" />
      <rect x="190" y="190" width="10" height="48" fill="#8f6a4a" />
      <rect x="110" y="166" width="46" height="12" rx="2" fill="#fff8ea" stroke="#d9c6ab" />

      {/* 机の灯り */}
      {has("lamp") ? (
        <g>
          <circle cx="182" cy="150" r="30" fill={`url(#${glowId})`} />
          <rect x="178" y="150" width="4" height="28" fill="#6b5e5a" />
          <path d="M164 150 L196 150 L188 134 L172 134 Z" fill="#c9704a" />
          <rect x="170" y="176" width="20" height="4" rx="2" fill="#6b5e5a" />
        </g>
      ) : (
        <g opacity="0.35">
          <rect x="178" y="150" width="4" height="28" fill="#6b5e5a" />
          <path d="M164 150 L196 150 L188 134 L172 134 Z" fill="#9b8f8a" />
        </g>
      )}

      {/* 本の山 */}
      {has("books") ? (
        <g>
          <rect x="18" y="206" width="40" height="10" rx="2" fill="#5b6c8f" />
          <rect x="22" y="196" width="36" height="10" rx="2" fill="#c9704a" />
          <rect x="20" y="186" width="34" height="10" rx="2" fill="#8fb996" />
        </g>
      ) : null}

      {/* 湯気の立つカップ */}
      {has("teacup") ? (
        <g>
          <rect x="68" y="168" width="14" height="11" rx="3" fill="#fff8ea" stroke="#b89a7a" />
          <path d="M82 171 q5 2 0 6" stroke="#b89a7a" fill="none" />
          <path d="M72 164 q2 -3 0 -6" stroke="#cfc3b4" strokeWidth="1.5" fill="none" className="anim-steam" />
          <path d="M78 164 q2 -3 0 -6" stroke="#cfc3b4" strokeWidth="1.5" fill="none" className="anim-steam" style={{ animationDelay: "1s" }} />
        </g>
      ) : null}
    </svg>
  );
}
