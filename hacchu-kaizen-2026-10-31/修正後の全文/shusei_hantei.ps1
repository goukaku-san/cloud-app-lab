# shusei_hantei.ps1 — 担当者の「修正あり」の字が、注文か、倉庫から持ち出した報告かを見分ける（曖昧なら確かめ待ち）
# 2026-10-31 草案（発注チェーンの点検 項目5・本番未投入）。語だけで却下しない。出庫の語が1つでもあれば、注文の語があっても「確かめ待ち」（数を変えない）
#   由来＝フレスト天満 11/12：尾崎さんの字の最後が「倉庫から出庫しました！」なのに、9品の数を直して反映し、阿川食品へ送られた（10/29〜10/30）
$SHUKKO_GO = @('出庫', '持ち出', '持出', '持って行', '持っていき', '持参', '倉庫から出', '倉庫より出', '運びました', '移動しました', '移しました')
$CHUMON_GO = @('追加', '注文', '発注', 'お願い', '頼み', '頼んで', '足して', '増やして')
function Get-ShuseiKubun([string]$Text) {
    $s = [string]$Text
    $shukko = @($SHUKKO_GO | Where-Object { $s.Contains($_) })
    $chumon = @($CHUMON_GO | Where-Object { $s.Contains($_) })
    $kubun = $(if ($shukko.Count) { '確かめ待ち' } else { '通常' })
    return [pscustomobject]@{ 区分 = $kubun; 出庫の語 = $shukko; 注文の語 = $chumon }
}
