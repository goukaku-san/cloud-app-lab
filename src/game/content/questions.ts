import type { Question } from "@/game/types";

// 一問の魔法: 学習問題（数学中心）。
// すべて AI が下書きしたもので、人手の監修を受けていない（reviewed: false）。
// 画面では「デモ（監修前）」と明示し、監修済みデータに差し替えるまで完成扱いにしない。
// AI 生成問題の隔離（設計書 2-E）: source: "ai-draft" のものは監修後に reviewed: true / source: "human" へ更新する。
const draft = (q: Omit<Question, "reviewed" | "source">): Question => ({ ...q, reviewed: false, source: "ai-draft" });

export const QUESTIONS: Question[] = [
  draft({ id: "m01", subject: "数学", gradeBand: "中1", prompt: "(−3) + 5 − (−2) を計算すると？", choices: ["0", "4", "−4", "6"], answerIndex: 1, explanation: "−(−2) は +2。−3 + 5 = 2、2 + 2 = 4。" }),
  draft({ id: "m02", subject: "数学", gradeBand: "中1", prompt: "3x + 2x − x を簡単にすると？", choices: ["4x", "5x", "6x", "4"], answerIndex: 0, explanation: "同じ文字の項は係数をまとめる。3 + 2 − 1 = 4 なので 4x。" }),
  draft({ id: "m03", subject: "数学", gradeBand: "中1", prompt: "方程式 2x + 3 = 11 の解は？", choices: ["x = 3", "x = 4", "x = 5", "x = 7"], answerIndex: 1, explanation: "両辺から 3 を引いて 2x = 8、両辺を 2 で割って x = 4。" }),
  draft({ id: "m04", subject: "数学", gradeBand: "中1", prompt: "y は x に比例し、x = 2 のとき y = 6。x = 5 のとき y は？", choices: ["10", "12", "15", "18"], answerIndex: 2, explanation: "y = ax に代入すると 6 = 2a で a = 3。y = 3x なので x = 5 のとき y = 15。" }),
  draft({ id: "m05", subject: "数学", gradeBand: "中1", prompt: "半径 3 cm の円の面積は？（円周率は π）", choices: ["6π cm²", "9π cm²", "3π cm²", "36π cm²"], answerIndex: 1, explanation: "円の面積は 半径 × 半径 × π。3 × 3 × π = 9π。" }),
  draft({ id: "m06", subject: "数学", gradeBand: "中1", prompt: "定価 2000 円の品物を 20% 引きで買うと、代金は？", choices: ["1600 円", "1800 円", "400 円", "1500 円"], answerIndex: 0, explanation: "20% 引きは定価の 80%。2000 × 0.8 = 1600。" }),
  draft({ id: "m07", subject: "数学", gradeBand: "中2", prompt: "連立方程式 x + y = 7, x − y = 1 の x の値は？", choices: ["3", "4", "5", "6"], answerIndex: 1, explanation: "2 つの式を足すと 2x = 8 で x = 4（このとき y = 3）。" }),
  draft({ id: "m08", subject: "数学", gradeBand: "中2", prompt: "一次関数 y = 2x − 1 のグラフの傾きは？", choices: ["−1", "1", "2", "3"], answerIndex: 2, explanation: "y = ax + b の a が傾き。ここでは a = 2。−1 は切片。" }),
  draft({ id: "m09", subject: "数学", gradeBand: "中2", prompt: "三角形の内角の和は？", choices: ["90°", "180°", "270°", "360°"], answerIndex: 1, explanation: "どんな三角形でも内角の和は 180°。四角形は 360°。" }),
  draft({ id: "m10", subject: "数学", gradeBand: "中2", prompt: "さいころを 1 回投げて偶数の目が出る確率は？", choices: ["1/6", "1/3", "1/2", "2/3"], answerIndex: 2, explanation: "目は 1〜6 の 6 通り、偶数は 2, 4, 6 の 3 通り。3/6 = 1/2。" }),
  draft({ id: "m11", subject: "数学", gradeBand: "中2", prompt: "5, 7, 9, 11, 13 の平均は？", choices: ["8", "9", "10", "11"], answerIndex: 1, explanation: "合計 45 を個数 5 で割って 9。等間隔に並ぶ数の平均は真ん中の値。" }),
  draft({ id: "m12", subject: "数学", gradeBand: "中3", prompt: "(x + 3)(x − 3) を展開すると？", choices: ["x² − 9", "x² + 9", "x² − 6x + 9", "x² + 6x + 9"], answerIndex: 0, explanation: "(a + b)(a − b) = a² − b²。x² − 3² = x² − 9。" }),
  draft({ id: "m13", subject: "数学", gradeBand: "中3", prompt: "x² + 5x + 6 を因数分解すると？", choices: ["(x + 1)(x + 6)", "(x + 2)(x + 3)", "(x − 2)(x − 3)", "(x + 5)(x + 1)"], answerIndex: 1, explanation: "足して 5、かけて 6 になる 2 つの数は 2 と 3。" }),
  draft({ id: "m14", subject: "数学", gradeBand: "中3", prompt: "√16 の値は？", choices: ["4", "±4", "8", "2"], answerIndex: 0, explanation: "根号 √ は正の平方根を表す。16 の正の平方根は 4。（16 の平方根は ±4 だが、√16 は 4）" }),
  draft({ id: "m15", subject: "数学", gradeBand: "中3", prompt: "√2 × √8 を計算すると？", choices: ["√10", "4", "2√2", "16"], answerIndex: 1, explanation: "√2 × √8 = √16 = 4。" }),
  draft({ id: "m16", subject: "数学", gradeBand: "中3", prompt: "二次方程式 x² − 5x + 6 = 0 の解は？", choices: ["x = 2, 3", "x = −2, −3", "x = 1, 6", "x = −1, −6"], answerIndex: 0, explanation: "(x − 2)(x − 3) = 0 と因数分解できるので x = 2, 3。" }),
  draft({ id: "m17", subject: "数学", gradeBand: "中3", prompt: "関数 y = x² で x = −3 のとき y の値は？", choices: ["−9", "9", "6", "−6"], answerIndex: 1, explanation: "(−3)² = (−3) × (−3) = 9。負の数の 2 乗は正。" }),
  draft({ id: "m18", subject: "数学", gradeBand: "中3", prompt: "直角をはさむ 2 辺が 3 cm と 4 cm の直角三角形の斜辺の長さは？", choices: ["5 cm", "6 cm", "7 cm", "√7 cm"], answerIndex: 0, explanation: "三平方の定理 3² + 4² = 9 + 16 = 25 = 5²。斜辺は 5 cm。" }),
  draft({ id: "m19", subject: "数学", gradeBand: "中3", prompt: "相似比が 1 : 2 の 2 つの図形の面積比は？", choices: ["1 : 2", "1 : 4", "1 : 8", "2 : 4"], answerIndex: 1, explanation: "面積比は相似比の 2 乗。1² : 2² = 1 : 4。" }),
  draft({ id: "m20", subject: "数学", gradeBand: "中3", prompt: "同じ弧に対する円周角は、中心角の何倍？", choices: ["2 倍", "1/2 倍", "同じ", "1/4 倍"], answerIndex: 1, explanation: "円周角の定理: 円周角 = 中心角の半分。" }),
  draft({ id: "m21", subject: "数学", gradeBand: "高1", prompt: "(a + b)² を展開すると？", choices: ["a² + b²", "a² + 2ab + b²", "a² − 2ab + b²", "a² + ab + b²"], answerIndex: 1, explanation: "(a + b)(a + b) = a² + ab + ab + b² = a² + 2ab + b²。" }),
  draft({ id: "m22", subject: "数学", gradeBand: "高1", prompt: "二次関数 y = (x − 1)² + 2 のグラフの頂点は？", choices: ["(1, 2)", "(−1, 2)", "(1, −2)", "(2, 1)"], answerIndex: 0, explanation: "y = (x − p)² + q の頂点は (p, q)。p = 1, q = 2。" }),
  draft({ id: "m23", subject: "数学", gradeBand: "高1", prompt: "5 人の中から 2 人を選ぶ組合せは何通り？", choices: ["5 通り", "10 通り", "20 通り", "25 通り"], answerIndex: 1, explanation: "₅C₂ = (5 × 4) ÷ (2 × 1) = 10。順番は区別しない。" }),
  draft({ id: "m24", subject: "数学", gradeBand: "高1", prompt: "sin 30° の値は？", choices: ["1/2", "√3/2", "1", "√2/2"], answerIndex: 0, explanation: "30°, 60°, 90° の直角三角形の辺の比 1 : √3 : 2 より、sin 30° = 1/2。" }),
  draft({ id: "e01", subject: "英語", gradeBand: "中2", prompt: "I (　) to the library yesterday.", choices: ["go", "went", "gone", "going"], answerIndex: 1, explanation: "yesterday があるので過去形。go の過去形は went。" }),
  draft({ id: "e02", subject: "英語", gradeBand: "中1", prompt: "There (　) three cats on the sofa.", choices: ["is", "are", "am", "be"], answerIndex: 1, explanation: "three cats は複数なので are。" }),
  draft({ id: "j01", subject: "国語", gradeBand: "中学", prompt: "「朝令暮改」の意味として正しいものは？", choices: ["朝に決めたことを夕方には必ず実行すること", "命令や方針がすぐに変わって定まらないこと", "朝から晩まで働き続けること", "古い決まりを新しく改めること"], answerIndex: 1, explanation: "朝に出した命令を夕方には改める、という意味から。" }),
  draft({ id: "j02", subject: "国語", gradeBand: "中学", prompt: "「彼は静かに走った。」の述語はどれ？", choices: ["彼は", "静かに", "走った", "は"], answerIndex: 2, explanation: "「どうする」にあたる語が述語。「走った」。「彼は」は主語、「静かに」は修飾語。" }),
  draft({ id: "s01", subject: "理科", gradeBand: "中1", prompt: "1 気圧のもとで水が沸騰する温度は？", choices: ["0 ℃", "50 ℃", "100 ℃", "200 ℃"], answerIndex: 2, explanation: "水の沸点は 1 気圧で 100 ℃。融点（氷がとける温度）は 0 ℃。" }),
  draft({ id: "h01", subject: "社会", gradeBand: "中3", prompt: "日本国憲法の三つの基本原理に含まれないものは？", choices: ["国民主権", "基本的人権の尊重", "平和主義", "天皇主権"], answerIndex: 3, explanation: "三つの基本原理は国民主権・基本的人権の尊重・平和主義。" }),
];

export const THINKING_OPTIONS = [
  "公式や決まりを思い出して解いた",
  "図や式を書いて確かめた",
  "選択肢を見比べて絞った",
  "直感で選んだ",
  "わからなかったので解説を読んだ",
] as const;

export const QUESTIONS_ARE_DEMO = QUESTIONS.some((q) => !q.reviewed);
