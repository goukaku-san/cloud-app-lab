import type { ClassroomSummary } from "@/game/classroom/protocol";
import { starPositions } from "@/game/content/starsDemo";

// 教室の星空。合計の数だけ星を置く（最大 200）。個人を示す情報は一切持たない。
export function ClassroomSky({ summary, label, extraStars = 0 }: { summary: ClassroomSummary; label: string; extraStars?: number }) {
  const total = summary.days.reduce((s, d) => s + (d.returns ?? 0), 0);
  const stars = starPositions(Math.min(200, total), 11);
  const mine = starPositions(Math.min(30, extraStars), 99);
  return (
    <svg viewBox="0 0 360 230" role="img" aria-label={label} className="h-auto w-full rounded-3xl border border-line">
      <defs>
        <linearGradient id="classroom-sky" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#1c2541" />
          <stop offset="1" stopColor="#3a4d7a" />
        </linearGradient>
      </defs>
      <rect width="360" height="230" fill="url(#classroom-sky)" />
      {stars.map((s, i) => (
        <circle key={`s${i}`} cx={s.x} cy={s.y} r={s.r} fill="#f2d479" opacity="0.7" className="anim-twinkle" style={{ animationDelay: `${(i % 7) * 0.4}s` }} />
      ))}
      {mine.map((s, i) => (
        <circle key={`m${i}`} cx={s.x} cy={s.y} r={s.r + 1.2} fill="#ffffff" />
      ))}
      <path d="M0 230 Q90 190 180 212 Q270 190 360 230 Z" fill="#2f4a3c" />
      {total === 0 ? (
        <text x="180" y="120" textAnchor="middle" fill="#dfe6f5" fontSize="14">
          まだ表示できる星がありません
        </text>
      ) : null}
    </svg>
  );
}

export function SummaryTable({ summary }: { summary: ClassroomSummary }) {
  return (
    <table className="w-full text-sm" data-testid="summary-table">
      <thead>
        <tr className="text-left text-ink-soft">
          <th className="py-1 font-semibold">日付</th>
          <th className="py-1 font-semibold">帰還の合計</th>
          <th className="py-1 font-semibold">参加端末</th>
        </tr>
      </thead>
      <tbody>
        {summary.days.map((d) => (
          <tr key={d.dayKey} className="border-t border-line">
            <td className="py-1">{d.dayKey}</td>
            <td className="py-1">{d.suppressed ? `表示しない（${summary.k} 端末未満）` : `${d.returns} 回`}</td>
            <td className="py-1">{d.suppressed ? "—" : `${d.participants} 台`}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
