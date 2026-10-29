// 部屋の段階と、部屋に現れる物。累積成長点で決まる（時間では変わらない）。

export const STAGE_THRESHOLDS = [0, 1, 3, 6, 10, 15] as const;
export const MAX_STAGE = STAGE_THRESHOLDS.length - 1;

export interface RoomStageDef {
  stage: number;
  name: string;
  description: string;
}

export const ROOM_STAGES: RoomStageDef[] = [
  { stage: 0, name: "静かな部屋", description: "まだ何も起きていない、静かな部屋。窓の外は薄い灰色。" },
  { stage: 1, name: "灯りのともる部屋", description: "机に小さな灯りがともった。壁が少し暖かい色になった。" },
  { stage: 2, name: "窓辺に緑", description: "窓辺に鉢植えが置かれ、外の景色に緑が差し込んだ。" },
  { stage: 3, name: "夕焼けの窓", description: "窓の外が夕焼けに染まり、本が増え、カーテンが揺れる。" },
  { stage: 4, name: "星の見える部屋", description: "夜空に星が出た。庭に芽が顔を出している。" },
  { stage: 5, name: "庭の咲く部屋", description: "庭に花が咲き、ランタンが灯り、ときどき流れ星が通る。" },
];

export function stageForGrowth(growth: number): number {
  let stage = 0;
  for (let i = 0; i < STAGE_THRESHOLDS.length; i += 1) {
    if (growth >= STAGE_THRESHOLDS[i]) stage = i;
  }
  return stage;
}

export interface RoomObjectDef {
  id: string;
  name: string;
  /** この累積成長点に達すると現れる。Infinity は特別な条件でのみ現れる物。 */
  unlockAt: number;
}

export const ROOM_OBJECTS: RoomObjectDef[] = [
  { id: "lamp", name: "机の灯り", unlockAt: 1 },
  { id: "plant", name: "窓辺の小さな鉢", unlockAt: 2 },
  { id: "books", name: "本の山", unlockAt: 3 },
  { id: "curtain", name: "やわらかいカーテン", unlockAt: 4 },
  { id: "teacup", name: "湯気の立つカップ", unlockAt: 5 },
  { id: "star", name: "窓の外の最初の星", unlockAt: 6 },
  { id: "sprout", name: "庭の芽", unlockAt: 7 },
  { id: "map", name: "壁の地図", unlockAt: 8 },
  { id: "moon", name: "三日月", unlockAt: 9 },
  { id: "flowers", name: "庭の花", unlockAt: 10 },
  { id: "bird", name: "窓辺の小鳥", unlockAt: 12 },
  { id: "lantern", name: "庭のランタン", unlockAt: 14 },
  { id: "meteor", name: "流れ星", unlockAt: 15 },
  { id: "blanket", name: "ひざ掛け（はじめて休んだ日に）", unlockAt: Number.POSITIVE_INFINITY },
  // 選んだ行動の教科ではじめて帰還した日に現れる物（部屋が一人ひとり違う形になる）
  { id: "subj-math", name: "壁の方眼紙（数学）", unlockAt: Number.POSITIVE_INFINITY },
  { id: "subj-english", name: "窓辺の絵はがき（英語）", unlockAt: Number.POSITIVE_INFINITY },
  { id: "subj-japanese", name: "机の上の筆と紙（国語）", unlockAt: Number.POSITIVE_INFINITY },
  { id: "subj-science", name: "棚のフラスコ（理科）", unlockAt: Number.POSITIVE_INFINITY },
  { id: "subj-social", name: "小さな地球儀（社会）", unlockAt: Number.POSITIVE_INFINITY },
  { id: "subj-review", name: "ふせんだらけのノート（復習）", unlockAt: Number.POSITIVE_INFINITY },
  { id: "subj-custom", name: "自分で選んだ鉛筆立て（自分で決めた行動）", unlockAt: Number.POSITIVE_INFINITY },
];

/** 教科 → 部屋に現れる物。該当がなければ null（「どれでも」「休息」など）。 */
export function subjectObjectId(subject: string): string | null {
  switch (subject) {
    case "数学":
      return "subj-math";
    case "英語":
      return "subj-english";
    case "国語":
      return "subj-japanese";
    case "理科":
      return "subj-science";
    case "社会":
      return "subj-social";
    case "復習":
      return "subj-review";
    case "自分で決めた":
      return "subj-custom";
    default:
      return null;
  }
}

export function objectsForGrowth(growth: number): string[] {
  return ROOM_OBJECTS.filter((o) => growth >= o.unlockAt).map((o) => o.id);
}

export function objectName(id: string): string {
  return ROOM_OBJECTS.find((o) => o.id === id)?.name ?? id;
}
