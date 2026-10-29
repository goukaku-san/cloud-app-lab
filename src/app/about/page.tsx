"use client";

import { Card, LinkButton, PageShell } from "@/components/ui";

export default function AboutPage() {
  return (
    <PageShell title="保護者の方・説明" backHref="/settings" backLabel="設定">
      <Card>
        <h2 className="font-bold">このアプリでできること</h2>
        <p className="mt-1 text-sm leading-relaxed">
          受験生が「今日の小さな行動」を自分で選び、端末を置いて現実で行動し、戻ってきたら自己申告するアプリです。申告にもとづいて、画面の中の小さな部屋が少しずつ変わります。受験の心構え、学び方、時間の使い方、休むことの大切さを、ゲームの形で体験することが目的です。
        </p>
      </Card>
      <Card>
        <h2 className="font-bold">自己申告の限界</h2>
        <p className="mt-1 text-sm leading-relaxed">
          部屋の変化は本人の自己申告にもとづきます。実際に学習したことや、端末に触れなかったことを証明するものではありません。学習の記録や成績の管理には使わないでください。
        </p>
      </Card>
      <Card>
        <h2 className="font-bold">AI の限界</h2>
        <p className="mt-1 text-sm leading-relaxed">
          この版のアプリは AI（大規模言語モデル）と通信しません。行動の提案は固定の候補から選ばれ、物語はあらかじめ書かれた文章です。「一問の魔法」の問題と解説は AI が下書きしたもので、人手の監修を受けるまで「デモ（監修前）」と表示します。誤りを含む可能性があるため、学習の判断材料にはしないでください。進路や適性、学力を判定する機能はありません。相談員や医療者の代わりにはなりません。
        </p>
      </Card>
      <Card>
        <h2 className="font-bold">広告と収益</h2>
        <p className="mt-1 text-sm leading-relaxed">
          この版に広告や課金はありません。将来も、未成年の個人データや学習履歴を広告のターゲティングに使うことはありません。滞在時間を延ばすための仕組み（連続記録、通知、ランキング、ガチャ）は設計上禁止しています。
        </p>
      </Card>
      <Card>
        <h2 className="font-bold">データの扱い</h2>
        <p className="mt-1 text-sm leading-relaxed">
          入力項目は任意のニックネームだけです。すべてのデータはこの端末のブラウザ内（IndexedDB）に保存され、サーバーへ送信しません。分析タグや第三者 SDK も入っていません。設定画面からいつでも完全に削除できます。
        </p>
      </Card>
      <Card>
        <h2 className="font-bold">教室の星図（塾・学校との関わり）</h2>
        <p className="mt-1 text-sm leading-relaxed">
          塾や学校から教室コードを受け取った場合、本人の操作で任意に参加できます。参加すると、帰還のたびに「教室コード・日付・帰還 1 回という事実」の 3 つだけが送られ、教室全体の合計が星になります。ニックネーム、振り返りの文章、自己申告の種類、時間帯、端末を特定できる情報は送られません。塾に見えるのは教室全体の合計だけで、個人の記録は見えません。参加しなくても不利益はなく、いつでも抜けられます。
        </p>
        <LinkButton href="/juku" className="mt-3 w-full">
          塾・教育機関の方へ
        </LinkButton>
      </Card>
      <Card>
        <h2 className="font-bold">この版の状態</h2>
        <p className="mt-1 text-sm leading-relaxed">
          バージョン 0.1 は実機検証前のデモです。物語の文章は草案で、監修前です。iPhone や Android の実機、読み上げソフトでの検証はこれからです。
        </p>
      </Card>
    </PageShell>
  );
}
