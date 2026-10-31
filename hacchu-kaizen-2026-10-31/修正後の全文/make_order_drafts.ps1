# 発注の下書きを Outlook に作る（送信は絶対にしない）。第3版 2026-09-18 蔵人（統合設計の会話・倉庫メインPC）
# 【このファイルの持ち主】2026-10-03 から発注ボード専用の会話（玉井さん：ボード上で起こるすべてに発注ボードが責任を持つ）。直したい会話は発注ボードへ依頼する。
# 種類：メール／新木さん（新木さんへの手配依頼メール）／電話メモ（自分宛）／FAX（eFax宛・発注書PDF添付）
# 第3版（発注ボード対応）：
#   -CandidatesPath  送信候補の群（相手・方法・中身の要約・宛先・本文…）を JSON に書く。ボードの台帳の元
#   -CaseId / -Label 案件ID（機械の照合用）と、人向けの印（例「近鉄和歌山 10/28」）。件名の頭に [発注] 印｜相手 を付ける
#   -Only            相手の名前を1つ指定し、その1通だけ下書きを作る（ボードの［中身を見て送る］）
#   -Open            作った下書きをその場で開く
#   -DraftFolder     下書きの置き場＝「下書き」の中のサブフォルダ名（既定 発注ボード）。既定の「下書き」には置かない（口座元の下書きと混ざらない）
#   作った下書きは「DRAFT<TAB>相手<TAB>EntryID<TAB>StoreID<TAB>件名」の行で報告する（ボードが台帳に書く）
# 使い方（例）:
#   & '<このフォルダ>\make_order_drafts.ps1' -Budget 3000000 -Type C -DeliveryDate 2026/10/1 `
#     -Address '〒730-8548 広島市中区胡町6-26' -Venue '(株)福屋 八丁堀本店7.8階 北海道物産展会場' -Attn '「和商市場内クシロー」新木重幸 宛' -Tel '082-246-6111' -Days 13 -Test
# -Account 下書きを置くアカウント（既定 kumada@gokaku.company。無ければ止まる）  -Test 件名の頭に【試験】
# -PlanPath 発注案（発注量・下書き・マネキン人数）を書くファイル  -NoDrafts 下書きを作らず発注案・候補だけ
param(
    [Parameter(Mandatory)][double]$Budget,
    [Parameter(Mandatory)][ValidateSet('A','B','C','D','E','40','45','50','55','60','65')][string]$Type,   # 2026-09-30 E（地下催事）が抜けていた＝E型は下の $col まで届かず、必ず止まっていた／2026-10-23 40〜65＝学問のだるまの割合（玉井さん 19:00・24代目ボス）
    [Parameter(Mandatory)][string]$DeliveryDate,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Address,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Venue,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Attn,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Tel,
    [int]$Days = 0,
    [double]$W1Budget = 0,
    [double]$W2Budget = 0,
    [int]$W1Days = 7,
    [string]$Brand = 'クシロー',
    [string]$Account = 'kumada@gokaku.company',
    [string]$FaxAccount = 'info@gokaku.company',
    [string]$Workbook = '',
    [string]$PlanPath = '',
    [string]$CandidatesPath = '',
    [string]$CaseId = '',
    [string]$Label = '',
    [string]$Only = '',
    [string]$FixPath = '',   # 2026-09-30 確認\〈案件ID〉.json。担当者が「修正あり」で直した一覧を本文に反映する（反映できなければ下書きを作らない）
    [string]$ShuseiAtsukai = '',   # 2026-10-31 草案（発注チェーンの点検・本番未投入） 項目5：人が決めた修正の扱い（注文／報告）
    [string]$ShuseiKagi = '',   # その決めがどの答え（確認の 答えた日時）に対してか。違えば効かない
    [string]$ShuseiZenkai = '',   # 前の回の台帳の 担当者の確認.反映
    [string]$ShuseiZenkaiKagi = '',   # 前の回の台帳の 担当者の確認.答えた日時
    [string]$NaoshiDir = '',   # 2026-10-07 発注案\予定の直し。鍵を持つ人が窓で直した行（確認\〈案件ID〉.json の候補の品目と同じ形）を、担当者の修正の後・供給上限の前に、同じ反映（Reflect-Rows）で当てる
    [string]$SentJson = '',   # 2026-10-08 もう送った相手→送った時の中身（JSON）。倉庫の引当で、送った数より下へ本文を削らない
    [string]$DashitaJson = '',   # 2026-10-16 倉庫出しの行がもう「倉庫から出した」の催事＝その行の引き当て（JSON の配列）。倉庫の今を見ず、出した量だけを当てる
    [string]$DraftFolder = '発注ボード',
    [switch]$Open,
    [switch]$Taishougai,   # 2026-09-30 仕組みの対象外の催事＝倉庫の引当をしない（別の経路で頼むので、倉庫出しが押されない）
    [switch]$NoDrafts,
    [switch]$Test
)
$ErrorActionPreference = 'Stop'
if (-not $Workbook) { $Workbook = Join-Path $PSScriptRoot '商品マスター_クシロー.xlsx' }
$col = @{ A = 'G'; B = 'H'; C = 'I'; D = 'J'; E = 'Q'; '40' = 'V'; '45' = 'W'; '50' = 'X'; '55' = 'Y'; '60' = 'Z'; '65' = 'AA' }[$Type]   # 2026-09-23 玉井さん：地下の催事はE型（商品マスターのQ列・ダルマ40%／いろりいか16%）。物産展は今までどおりA〜D
#   2026-10-23 玉井さん 19:00（商品マスターの会話で直接）「だるまの割合のボタンは40%から…65%まで」＝学問のするめの型 40・45・50・55・60・65 → 商品マスター_学問のするめ.xlsx「構成比の型」の V・W・X・Y・Z・AA 列（発注量の試算!B5 は INDIRECT で列の字を読む＝AA も通る）。
#   型が空の学問の催事は process_budget_files が屋号.json の既定の型 A（＝G列）を入れる＝AIかおりの割合のボタンが入るまで今の候補は動かない。クシローの A〜E はそのまま。割合の型は学問のするめだけ（ほかの屋号の商品マスターに V〜AA の型は無い）
if (-not $col) { throw "知らない型です：$Type（使えるのは A・B・C・D・E と、学問のするめの 40・45・50・55・60・65）" }
if ($Type -match '^\d+$' -and $Brand -ne '学問のするめ') { throw "だるまの割合の型（$Type）は学問のするめだけです（屋号＝$Brand）" }
# 2026-10-16 メール移行 B5：署名の Mail は board_config.json の Signature.Mail から読む（切替日に co.jp へ替える＝決め打ちをやめた）。無ければ今までどおり kumada@gokaku.company
$sigMail = 'kumada@gokaku.company'; try { $cfgSig = (Get-Content (Join-Path $PSScriptRoot 'board_config.json') -Raw -Encoding UTF8 | ConvertFrom-Json).Signature; if ($cfgSig -and [string]$cfgSig.Mail) { $sigMail = [string]$cfgSig.Mail } } catch {}
$sig = @"
⬠ ⬟ ⬠ ⬟ ⬠ ⬟ ⬠ ⬟ ⬠ ⬟ ⬠ ⬟ ⬠ ⬟ ⬠ ⬟
  株式会社合格
  熊　田　か　お　り
  Mobile：080-3133-0059
  〒818-0117 太宰府市宰府1-14-36
  TEL：092-918-2526
  FAX：092-918-2525
  Mail：$sigMail
  URL：https://www.gokaku.co.jp
⬠ ⬟ ⬠ ⬟ ⬠ ⬟ ⬠ ⬟ ⬠ ⬟ ⬠ ⬟ ⬠ ⬟ ⬠ ⬟
"@
$stamp = Get-Date -Format 'yyyyMMddHHmmss'
$utf8bom = New-Object Text.UTF8Encoding $true

# 0) 掛け率の材料＝棚卸の実績（初日と最終日がそろった会期だけ・1会期×1品目＝1行）
function Get-UsageRows {
    $root = Split-Path $PSScriptRoot -Parent
    $sd = Join-Path $root '棚卸'; $pd = Join-Path $root '発注案'
    $out = @()
    if (-not (Test-Path $sd)) { return $out }
    foreach ($fb in (Get-ChildItem $sd -Filter '*_最終日.json' -ErrorAction SilentlyContinue)) {
        $id = $fb.BaseName -replace '_最終日$', ''
        $fa = Join-Path $sd ($id + '_初日.json'); $fp = Join-Path $pd ($id + '.json')
        if (-not (Test-Path $fa) -or -not (Test-Path $fp)) { continue }
        try {
            $ja = Get-Content $fa -Raw -Encoding UTF8 | ConvertFrom-Json; $jb = Get-Content $fb.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $jp = Get-Content $fp -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch { continue }
        $days = [double]$jp.納品.営業日数; if ($days -le 0) { continue }
        $sum = { param($j) $h = @{}; foreach ($i in @($j.品目)) { $c = [string]$i.品目; if (-not $c) { $c = [string]$i.品目コード }; if ($c.Length -ge 4) { $c = $c.Substring(0, 4) } else { continue }; $h[$c] = $(if ($h.ContainsKey($c)) { $h[$c] } else { 0 }) + [double]$i.kg }; $h }
        $a = & $sum $ja; $b = & $sum $jb
        $so = @{}; foreach ($x in @($jb.'売り切れ')) { if ($x.品目) { $c = ([string]$x.品目).Substring(0, 4); $so[$c] = $(if ($x.いつ -eq '最終日より前') { 1 } elseif ($x.いつ -eq '最終日') { 2 } else { $null }) } }
        foreach ($c in $a.Keys) {
            if ($a[$c] -le 0) { continue }
            $out += [pscustomobject]@{ End = [datetime]$jp.会期終了; Brand = [string]$jp.屋号; Case = $id; Code = $c; DaySales = [math]::Round([double]$jp.売上予算 / $days)
                In = [math]::Round($a[$c], 2); Ret = [math]::Round($(if ($b.ContainsKey($c)) { $b[$c] } else { 0 }), 2); SoldOut = $so[$c] }
        }
    }
    return $out
}

# 1) Excel のコピーで計算する（原本は触らない）
$tmp = Join-Path $env:TEMP ('order_work_' + $stamp + '.xlsx')
Copy-Item $Workbook $tmp -Force
$mails = @(); $items = @(); $mq = @{}
$xl = New-Object -ComObject Excel.Application; $xl.DisplayAlerts = $false
try {
    $wb = $xl.Workbooks.Open($tmp)
    $s = $wb.Worksheets.Item('発注量の試算')
    $s.Range('B4').Value2 = $Budget; $s.Range('B5').Value2 = $col
    $m = $wb.Worksheets.Item('発注メールの下書き')
    $m.Range('B4').NumberFormat = '@'; $m.Range('B4').Value2 = [string]$DeliveryDate
    $m.Range('B5').Value2 = $Address; $m.Range('B6').Value2 = $Venue; $m.Range('B7').Value2 = $Attn; $m.Range('B8').Value2 = $Tel
    $k = $wb.Worksheets.Item('マネキン人数')
    if ($Days -gt 0) { $k.Range('B25').Value2 = $Brand; $k.Range('B26').Value2 = $Budget; $k.Range('B27').Value2 = [double]$Days }
    # 週ごとの売上予算（2026-09-21 玉井さん「予算は1週目と2週目で分けるべき。基準も週ごとに」）：商品マスターの表 D26〜D29 に入れると B29/B30 が週ごとの1日の売上で判定される。1週目＝初日から7日間／2週目＝8日目から最終日
    if ($Days -gt 7 -and $W1Budget -gt 0 -and $W2Budget -gt 0) { $k.Range('D26').Value2 = $W1Budget; $k.Range('D27').Value2 = [double]$W1Days; $k.Range('D28').Value2 = $W2Budget; $k.Range('D29').Value2 = [double]($Days - $W1Days) }   # 2026-09-22：区切りは出店リストに合わせて変わる（例 八木橋 12日＋6日）＝ -W1Days で受ける。既定7日
    # 1a) 掛け率（売れた割合で次の量を上下・2026-09-21 玉井さん「構成比の高い品に限り売り切れを重く見る」）
    #     統合設計＝入口と実績の行を入れるだけ。式と、数量への掛け算は商品マスターの持ち場（シート「掛け率」「発注量の試算」）
    $kr = $null; try { $kr = $wb.Worksheets.Item('掛け率') } catch {}
    if ($kr) {
        $kr.Range('B14').Value2 = $Brand; $kr.Range('B15').Value2 = $Type
        if ($Days -gt 0) { $kr.Range('B16').Formula = [string][int64][math]::Round($Budget / $Days) }
        $r = 22
        foreach ($u in (Get-UsageRows)) {
            if ($r -gt 2000) { break }
            $kr.Cells.Item($r, 11).Formula = ('=DATE({0},{1},{2})' -f $u.End.Year, $u.End.Month, $u.End.Day)   # 日付は式で入れる（COMの日付ずれ対策）
            $kr.Cells.Item($r, 12).Value2 = $u.Brand; $kr.Cells.Item($r, 13).Value2 = $u.Case; $kr.Cells.Item($r, 15).Value2 = $u.Code
            $kr.Cells.Item($r, 16).Value2 = [double]$u.DaySales; $kr.Cells.Item($r, 17).Value2 = [double]$u.In; $kr.Cells.Item($r, 18).Value2 = [double]$u.Ret
            if ($u.SoldOut) { $kr.Cells.Item($r, 19).Value2 = [int]$u.SoldOut }   # 1＝最終日より前に売り切れ／2＝最終日に売り切れ／空＝答えなし
            $r++
        }
    }
    $xl.CalculateFull()
    $kake = @()
    if ($kr) {
        for ($r = 21; $r -le 46; $r++) {
            $c = [string]$kr.Cells.Item($r, 1).Text; if (-not $c) { continue }
            $kake += [ordered]@{ 品目コード = $c; 主力 = [string]$kr.Cells.Item($r, 3).Text; 比べた回数 = [string]$kr.Cells.Item($r, 4).Text; 掛け率 = [string]$kr.Cells.Item($r, 7).Text; 理由 = [string]$kr.Cells.Item($r, 8).Text }
        }
    }
    for ($r = 11; $r -le 30; $r++) {
        $name = [string]$m.Cells.Item($r, 1).Value2
        if (-not $name -or $name.StartsWith('※')) { continue }
        $mails += [pscustomobject]@{
            Name = $name; To = [string]$m.Cells.Item($r, 2).Value2; CC = [string]$m.Cells.Item($r, 3).Value2
            Body = [string]$m.Cells.Item($r, 4).Value2; Send = [string]$m.Cells.Item($r, 5).Value2; Subject = [string]$m.Cells.Item($r, 6).Value2
            Kind = [string]$m.Cells.Item($r, 7).Value2; Att = [string]$m.Cells.Item($r, 8).Value2; FaxQty = [string]$m.Cells.Item($r, 9).Value2
        }
    }
    for ($r = 8; $r -le 32; $r++) {
        $code = [string]$s.Cells.Item($r, 1).Text
        if (-not $code) { continue }
        # 2026-10-08 学問 v4：P列（Cs）の単位は V列（「袋」／「c/s」）。袋物は P列が袋の数＝そのまま c/s と書くと「142c/s」になる。
        #   W列＝1箱の入数（袋）・X列＝荷姿コード。V列が無い表（クシロー）は今までどおり c/s
        $tani = [string]$s.Cells.Item($r, 22).Text; if ($tani -ne '袋') { $tani = 'c/s' }
        $items += [pscustomobject]@{ Code = $code; Name = [string]$s.Cells.Item($r, 2).Text; Kg = [string]$s.Cells.Item($r, 12).Text; Cs = [string]$s.Cells.Item($r, 16).Text; Pay = [string]$s.Cells.Item($r, 18).Text
            Tani = $tani; Iri = [string]$s.Cells.Item($r, 23).Text; Nisugata = [string]$s.Cells.Item($r, 24).Text }
    }
    if ($Days -gt 0) { $mq = @{ Day = $k.Range('B28').Text; W1 = $k.Range('B29').Text; W2 = $k.Range('B30').Text }; if ($Days -gt 7 -and $W1Budget -gt 0 -and $W2Budget -gt 0) { $mq.Day = '1週目 ' + $k.Range('D30').Text + '円・2週目 ' + $k.Range('D31').Text } }
    $wb.Close($false)
} finally { $xl.Quit(); [void][Runtime.InteropServices.Marshal]::ReleaseComObject($xl); Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
# 2026-10-12 頼み直し（下の 1a'''''''''）が本文の行の字を借りるための、Excel から出たままの本文（あとで反映・引当が書き換える前の写し）
$mailsMoto = @{}
foreach ($x in $mails) { $mailsMoto[[string]$x.Name] = [pscustomobject]@{ Body = [string]$x.Body; FaxQty = [string]$x.FaxQty } }

# 2026-10-01 品名の照合は、ひらがなとカタカナを同じものとして見る。
#   由来＝本文の「削りタコかま（10kg）」と品名「削りたこかま」が一致せず、新木さんの発注が丸ごと止まった（阪神 1週目）。
function Kana-Norm([string]$s) {
    $a = $s.ToCharArray()
    for ($k = 0; $k -lt $a.Length; $k++) { $c = [int]$a[$k]; if ($c -ge 0x3041 -and $c -le 0x3093) { $a[$k] = [char]($c + 0x60) } }
    return (-join $a)
}
function Kana-Same([string]$line, [string]$name) { return (Kana-Norm $line).Contains((Kana-Norm $name)) }

# 2026-10-01 品目.json に「本文名」があれば、本文の行を探すときはそれを使う（値は商品マスターの持ち場・こちらは読むだけ）。
#   由来＝K033「ソフト帆立」が、阿川食品あての本文では「ソフト貝柱2S 600粒×2」。名前が合わず、新木さんの10品の下書きが丸ごと止まった。
$honName = @{}
# 2026-10-01 荷姿（K008-01 のように枝番の付いたコード）。商品マスターが品目.json に「荷姿」セクションを新設した。
#   いまは**止まった理由を正しく言うためだけ**に読んでいる。台帳と本文に荷姿の行を足す実装はまだ無い（統合設計の宿題・期限＝阪神2週目の要項が動くまで）。
$nisugata = @{}
# 2026-10-01 ここで足した荷姿の行の控え。**「修正あり」でない催事でも引当が読む**ので、必ず外側で作っておく
#   （中で作っていたら、確認が「OK」の井上で空のまま呼ばれて落ちた）
$ngLines = @{}
$jUchi = @{}   # 倉庫にある現物の荷姿（人が数えた実数の原文）。実数のファイルが無い回でも空で通るよう、必ず外側で作る
$jNi = @{}     # 2026-10-08 倉庫にある現物の荷姿（荷姿コード・1個kg・原文の品名）。倉庫出しの字を現物の形で書くのに使う（ダルマ 13kgの箱でなく 1kg袋×13）
$sentMap = @{}   # 2026-10-08 もう送った相手→送った時の中身（倉庫の引当で送った数より下へ削らない）
if ($SentJson) { try { foreach ($sp in @(($SentJson | ConvertFrom-Json).PSObject.Properties)) { $sentMap[[string]$sp.Name] = [string]$sp.Value } } catch {} }
$hinMeta = @{}   # 2026-10-07 品目コード→品目.json の行（品名・原価kg・発注単位kg）。予定の直しの「もう頼んである」が支払額を出すのに読む
$hinP = Join-Path $PSScriptRoot '品目.json'
if (Test-Path $hinP) {
    try { $hj = Get-Content $hinP -Raw -Encoding UTF8 | ConvertFrom-Json
          foreach ($pp in @($hj.品目.PSObject.Properties)) { if ($pp.Value.本文名) { $honName[[string]$pp.Name] = [string]$pp.Value.本文名 } }
          foreach ($pp in @($hj.品目.PSObject.Properties)) { $hinMeta[[string]$pp.Name] = $pp.Value }
          foreach ($np in @($hj.荷姿.PSObject.Properties)) { $nisugata[[string]$np.Name] = $np.Value } } catch {}
}
#   照合の順番は **品名 → 本文名**（商品マスターの会話の決まり・2026-10-01）。本文名が無い品目は今までどおり品名だけで当たる。
function Hon-Name($code) {
    $c = [string]$code; if ($c.Length -ge 4) { $c = $c.Substring(0, 4) }
    if ($honName.ContainsKey($c)) { return $honName[$c] }
    return ''
}

# 1a'') 担当者の「修正あり」を本文に反映する（2026-09-30 統合設計）
#   穴＝これまでは「修正あり」でも下書き可＝true のままで、直す前の数量のまま下書きが作れた。
#   直し方＝確認\〈案件ID〉.json の「候補の品目」（担当者が直した後の一覧）を正として、本文の「・品名 Nc/s」の c/s を書き換える。
#   **確かめられないものは直さず、下書きそのものを止める（fail-closed）**＝一覧に無い品目・本文の行が見つからない/2つ以上ある・文章と写真だけの修正。
# 2026-10-07 反映の関数。担当者の修正（確認\〈案件ID〉.json の候補の品目）と、予定の直し（発注案\予定の直し\〈案件ID〉_*.json の行）を**同じ道**で本文と品目に当てる。
#   新しい反映コードは書かない（点検役(2)）。$Moto＝'確認'｜'直し'。違いは2つだけ＝直しは「確認の一覧に無い品目」で止めない・「一覧が無い」で止めない。
#   書き足す先（$fixNote・$fixDone・$items・$handSouko）は $script: で親に戻す。$fixTouched・$ngLines は辞書なのでそのまま効く
# 2026-10-12 ★10/11「確認後は数字を変えない」（11代目ボス裁定）：当てる鍵＝品目コード＋商品の末尾（大袋／小袋）。
#   学問は大袋・小袋が同じ品目コード（K006 ×2）＝コードだけで引くと小袋の数が大袋に入る。確認ファイルに #2 は出ない（fork 15 10/12）＝商品の字の末尾で分ける。
#   クシローなど末尾が無い品は「コード|」＝今までどおり。片側だけ末尾がある時は、その品目コードが発注案と確認の両方で1行ずつの時に限り当てる
function Fix-Suffix([string]$nm) { if ($nm -match '\s(大袋|小袋)\s*$') { return $Matches[1] }; return '' }
function Fix-Key([string]$cd, [string]$nm) { return ($cd + '|' + (Fix-Suffix $nm)) }
function Find-Fix($fm, $it) {
    $k = Fix-Key ([string]$it.Code) ([string]$it.Name)
    if ($fm.ContainsKey($k)) { return $k }
    $pre = [string]$it.Code + '|'
    $fks = @(@($fm.Keys) | Where-Object { ([string]$_).StartsWith($pre) })
    $its = @(@($script:items) | Where-Object { [string]$_.Code -eq [string]$it.Code })
    if ($fks.Count -eq 1 -and $its.Count -eq 1) { return [string]$fks[0] }
    return ''
}
# 本文の行の字を荷姿から組む（学問の袋物＝本文が「黒ごま炙りいわし 90g（60袋入）」で、Excel の行名「黒ごま炙りいわし 大袋」では当たらない）。
#   荷姿コード＝商品マスター Excel の X列（$i.Nisugata）・入数＝W列（無ければ品目.json の荷姿の 1箱の入数）。品名は Excel の行名から末尾を外した字（本文と同じ字）
function Pack-Name($it) {
    if (-not (Fix-Suffix ([string]$it.Name)) -or -not [string]$it.Nisugata -or -not $nisugata.ContainsKey([string]$it.Nisugata)) { return '' }
    $ng = $nisugata[[string]$it.Nisugata]; $iri = [string]$it.Iri; if (-not $iri) { $iri = [string]$ng.'1箱の入数' }
    if (-not [string]$ng.荷姿 -or -not $iri) { return '' }
    return ((([string]$it.Name) -replace '\s*(大袋|小袋)\s*$', '') + ' ' + [string]$ng.荷姿 + '（' + $iri + '袋入）')
}
function Reflect-Rows([object[]]$Rows, [string]$Moto) {
    $fixMap = @{}
    # 2026-10-06 「人が読む」行（LINEの直接発注を担当者の答えとして受ける・玉井さん 10/6「例外的にOK」）。
    #   品目コードが無い・品目表の1ケースの重さで数えられない品（「2kg×4を2ケース」「15kg」など）は、数量を計算しない。
    #   担当者が書いた字（本文の字）をそのまま、頼む先の下書きに「・※」で足す。計算する行（同じ品目コードの行）は0にして消す。
    #   これまでは1品でも直せないと催事まるごと止まっていた（下書き0通）。止める単位を品にする。形は5代目ボス・AIかおり fork 7 と 10/6 に決めた
    #   （候補の品目の1行＝品目コード／商品／発注量kg／ケース＋人が読む／本文の字／頼む先／注意）
    $handRows = @()
    # 2026-10-12 11代目ボス（誤った数の下書きを作らない）：同じ鍵（品目コード＋大袋/小袋）が2行ある時は、どちらの数か決められない＝反映しないで止める
    #   （10/12 昼の見張り「同じコード2行なら止める」は、鍵にコード＋大袋/小袋を入れたので、本当に同じ鍵の時だけに狭めた）
    $dupCd = @(@($Rows) | Where-Object { $_ -and $_.人が読む -ne $true -and [string]$_.品目コード } | Group-Object { Fix-Key ([string]$_.品目コード) ([string]$_.商品) } | Where-Object { $_.Count -ge 2 })
    if ($dupCd.Count) { $script:fixNote += ('同じ品目が2行ある（' + (($dupCd | ForEach-Object { [string]$_.Name }) -join '・') + '）＝どちらの数か決められないので反映しない＝下書きを作らない'); return }
    foreach ($p in @($Rows)) {
        $cd = [string]$p.品目コード
        if ($p.人が読む -eq $true) {
            $handRows += $p
            if ($cd) { $fixMap[(Fix-Key $cd ([string]$p.商品))] = [pscustomobject]@{ 品目コード = $cd; 商品 = [string]$p.商品; 発注量kg = '0'; ケース = '0'; 人が読む = $true } }
            continue
        }
        # 2026-10-09 調査役の指摘（10代目ボス経由）：確認ファイルの kg は答えた時の古い1ケースkg のことがある（鮭燻製ソフト 8c=16kg＝2kg/c）。
        #   ケースは担当者の答え・kg は 品目.json の今の発注単位kg で出し直す（4桁のコードで、発注単位kg がある品だけ）
        #   ロット品（倉庫ストック品.json＝羅臼・しそひじき）は袋（1kg）で出すので除く（井上の 10kg が 1ケース×15kg に化けた 10/9）
        #   2026-10-12 大袋/小袋の行は1箱の重さが違う（K008 大袋90g×60＝5.4kg・小袋30g×80＝2.4kg）＝品目の発注単位kg でなく、発注案の行の荷姿（X列）の 1箱kg で出す。引けなければ出し直さない
        if ($Moto -eq '確認' -and $cd -match '^K\d{3}$' -and $hinMeta.ContainsKey($cd) -and -not ($cd -in @('K014', 'K015'))) {
            $tk = 0.0; $cs0 = 0.0; $tkS = [string]$hinMeta[$cd].発注単位kg
            if (Fix-Suffix ([string]$p.商品)) {
                $tkS = ''; $pk = Fix-Key $cd ([string]$p.商品)
                $it1 = @(@($items) | Where-Object { (Fix-Key ([string]$_.Code) ([string]$_.Name)) -eq $pk }) | Select-Object -First 1
                if ($it1 -and [string]$it1.Nisugata -and $nisugata.ContainsKey([string]$it1.Nisugata) -and $nisugata[[string]$it1.Nisugata].'1箱kg') { $tkS = [string]$nisugata[[string]$it1.Nisugata].'1箱kg' }
                elseif ((Fix-Suffix ([string]$p.商品)) -eq '大袋') { $tkS = [string]$hinMeta[$cd].発注単位kg }   # 大袋で荷姿に 1箱kg が無い（K017 ダルマ13kg）＝品目の発注単位kg。小袋で引けない時は出し直さない（確認の kg のまま）
            }
            if ([double]::TryParse($tkS, [ref]$tk) -and $tk -gt 0 -and [double]::TryParse([string]$p.ケース, [ref]$cs0)) {
                $kg1 = [Math]::Round($cs0 * $tk, 2)
                if ([string]$p.発注量kg -ne [string]$kg1) { $p = $p | Select-Object *; $p | Add-Member -NotePropertyName 確認時のkg -NotePropertyValue ([string]$p.発注量kg) -Force; $p.発注量kg = [string]$kg1 }   # 2026-10-19 玉井さん 10/18『担当者がOKした数を作り直しで変えない』（18代目ボス②）：確認の時の kg を別の欄に残し、違えば⚠（ケースは確認のまま）
            }
        }
        if ($cd) { $fixMap[(Fix-Key $cd ([string]$p.商品))] = $p }
    }
    # 2026-10-09 玉井さん「1」（10代目ボス経由・近鉄和歌山）：確認の一覧に無い品を、決めた催事では「頼まない（0）」にする（仕組み\確認に無い品は頼まない.json）
    if ($Moto -eq '確認' -and $fixMap.Count) {
        $nashi0 = $null; try { $nashi0 = @((Get-Content (Join-Path $PSScriptRoot '確認に無い品は頼まない.json') -Raw -Encoding UTF8 | ConvertFrom-Json).催事) | Where-Object { [string]$_.案件ID -eq $CaseId } | Select-Object -First 1 } catch {}
        if ($nashi0) { foreach ($i in $items) { if ($i.Kg -and $i.Kg -ne '0' -and -not (Find-Fix $fixMap $i)) { $fixMap[(Fix-Key ([string]$i.Code) ([string]$i.Name))] = [pscustomobject]@{ 品目コード = [string]$i.Code; 商品 = [string]$i.Name; 発注量kg = '0'; ケース = '0' }; $script:fixDone += ([string]$i.Code + ' ' + [string]$i.Name + '：確認の一覧に無い＝この催事では頼まない（0）') } } }
    }
    if ($Moto -eq '確認' -and -not $fixMap.Count -and -not $handRows.Count) {
        # 2026-10-29 13枚目（玉井さん 21:35 ハンコ）：答えが文字や写真だけで品目の行が1つも無い時も、催事を止めない。熊田さんの画面に「文字だけの答え」で出す（下書きは今の候補の数のまま）。
        #   字も写真も無い時は「文字だけの答え」ではない＝今までどおり止める
        $mjJi = [string]$fx.修正リスト原文; if (-not $mjJi.Trim() -and @(@($fx.修正の写真) | Where-Object { $_ }).Count) { $mjJi = '（写真だけ ' + @(@($fx.修正の写真) | Where-Object { $_ }).Count + '枚＝G:\LINE保存\発注の修正リスト）' }
        if ($mjJi.Trim()) { $script:mojiChumon += [pscustomobject][ordered]@{ 字 = $mjJi.Trim(); 頼む先 = ''; 理由 = '文字だけの答え（品目の行が無い）' } }
        else { $script:fixNote += '確認に品目の一覧が無い（文章・写真だけの修正＝人が読む）' }
    }
    # 2026-10-01 逆方向の検査と、荷姿の行の足し込み。
    #   ここまでは「発注案にあって確認に無い品目」だけを見ていたので、「確認にあって発注案に無い品目」が**黙って落ちていた**
    #   （阪神2週目の黒ごま炙りいわし270g入り・21.6kg・66,081円）。$items は商品マスターのExcelから組むので、枝番の荷姿は出てこない。
    #   現場が指定した荷姿は、Excelの構成比には足さず**台帳側（ここ）で足す**（2026-10-01 統合設計の裁定・商品マスター同意）。
    #   支払額＝発注量kg × 荷姿の原価kg の**素の掛け算**。構成比・掛け率・歩留まりは掛けない＝それらは「何kg買うか」を決める係数で、
    #   買う重さが決まったあとの金額には入らない（商品マスター 10/1。検算＝K017 65kg×4,870＝316,550 が台帳と一致）。
    #   現場の指定は確定値なので掛け率も掛けない（9/23 玉井さん「現場の発注が正」）。
    # 2026-10-12 鍵＝品目コード＋大袋/小袋。発注案の行から当たった鍵を先に数え、当たらない確認の行だけをここで扱う（$cd は確認の行の品目コード）
    $itemCodes = @{}
    foreach ($i in $items) { $fk0 = Find-Fix $fixMap $i; if ($fk0) { $itemCodes[$fk0] = $true } }
    foreach ($fkey in @($fixMap.Keys)) {
        if ($itemCodes.ContainsKey([string]$fkey)) { continue }
        $pm = $fixMap[$fkey]; $cd = [string]$pm.品目コード
        if ($pm.人が読む -eq $true) { continue }   # 2026-10-06 人が読む行は下でそのまま足す（発注案に無い品でも止めない）
        $ng = $nisugata[[string]$cd]
        $atama = '確認にあるのに発注案に無い品目：' + [string]$cd + ' ' + [string]$pm.品名 + '（' + [string]$pm.ケース + 'c/s・' + [string]$pm.発注量kg + 'kg）。'
        if (-not $ng) { $script:fixNote += ($atama + '品目.json にこのコードが無い＝商品マスターに足してもらう'); continue }
        $ngKg = [double](([string]$pm.発注量kg) -replace '[^\d\.]', ''); $ngCs = [string]$pm.ケース
        $ngTan = [double]([string]$ng.原価kg)
        if ($ngKg -le 0 -or -not $ngCs) { $script:fixNote += ($atama + '確認にケースか発注量kgが無い'); continue }
        if ($ngTan -le 0) { $script:fixNote += ($atama + '品目.json の荷姿に原価kgが入っていない＝商品マスターに入れてもらう'); continue }
        # 本文の行の字は**規則から組む**（品目.json の「本文の組み立て」・商品マスター 2026-10-01）。
        #   品名 ＋ 半角スペース ＋ 荷姿 ＋ （1箱の入数袋入） ＝「黒ごま炙りいわし 270g（20袋入）」
        #   荷姿に本文名は置かない＝品名と入数が別の欄にあるので二重管理になり、実際に食い違った（カタカナ／ひらがな）。
        #   組み立てられないときだけ、商品マスターが置いた本文名を使う（橋渡し。言い方そのものが違う品はこちら）。
        $ngHon = ''
        if ($ng.品名 -and $ng.荷姿 -and [double]([string]$ng.'1箱の入数') -gt 0) {
            $ngHon = [string]$ng.品名 + ' ' + [string]$ng.荷姿 + '（' + [string]$ng.'1箱の入数' + '袋入）'
        } elseif ($ng.本文名) { $ngHon = [string]$ng.本文名 }
        if (-not $ngHon) { $script:fixNote += ($atama + '本文の行を組めない（品目.json の荷姿に 1箱の入数 も 本文名 も無い）＝商品マスターに入れてもらう'); continue }
        # 本文に足す場所＝**同じ品物の他の荷姿の行のすぐ下**（90g入りの次に270g入り）。熊田さんの実物のFAXがその並び（商品マスター 10/1）
        $oya = [string]$ng.品目; $ph = @()
        foreach ($nm in @((Hon-Name $oya), [string]$ng.品名)) {
            if (-not $nm -or $ph.Count) { continue }
            foreach ($x in $mails) {
                foreach ($fld in @($(if ($x.Kind -eq 'FAX') { 'FaxQty' } else { 'Body' }))) {
                    $txt = [string]$x.$fld; if (-not $txt) { continue }
                    $lsx = @($txt -split "`r?`n")
                    for ($n = 0; $n -lt $lsx.Count; $n++) { if ((Kana-Same $lsx[$n] $nm) -and $lsx[$n] -match '(\d+(?:\.\d+)?)\s*c/s') { $ph += [pscustomobject]@{ M = $x; F = $fld; N = $n } } }
                }
            }
        }
        if ($ph.Count -ne 1) { $script:fixNote += ($atama + '足す場所が本文で' + $ph.Count + '件（親の' + $oya + ' の行が1件でないと足さない）'); continue }
        $t = $ph[0]
        $lsx = @(([string]$t.M.($t.F)) -split "`r?`n")
        # 行の頭は**親の行に合わせる**。相手によって「・」が付く本文と付かない本文がある（セニヤの差し込みは付かない）。
        # 決め打ちで「・」を足すと、1行だけ形の違う行が混ざって相手に届く（10/1 実際にそうなった）。
        $kashira = ''
        if ([string]$lsx[$t.N] -match '^(\s*[・･\*\-]\s*)') { $kashira = $Matches[1] }
        $ngLine = $kashira + $ngHon + ' ' + $ngCs + 'c/s'
        $out = @()
        for ($n = 0; $n -lt $lsx.Count; $n++) { $out += $lsx[$n]; if ($n -eq $t.N) { $out += $ngLine } }
        $t.M.($t.F) = ($out -join "`r`n")
        # 2026-10-01 FAXは差し込みのほかに**メール本文にも同じ一覧が載る**ので、本文にも同じ行を足す。
        #   足さないと、本文だけ2行・PDFは3行になり、1通の中で品数が食い違う（阪神2週目のセニヤ。発注ボードの指摘）。
        if ($t.F -eq 'FaxQty' -and [string]$t.M.Body) {
            $bl = @(([string]$t.M.Body) -split "`r?`n"); $atari = @()
            foreach ($bn in 0..($bl.Count - 1)) { if ((Kana-Same $bl[$bn] ([string]$ng.品名)) -and $bl[$bn] -match '(\d+(?:\.\d+)?)\s*c/s') { $atari += $bn } }
            if ($atari.Count -eq 1) {
                $bi = $atari[0]; $bk = ''
                if ([string]$bl[$bi] -match '^(\s*[・･\*\-]\s*)') { $bk = $Matches[1] }
                $bout = @()
                for ($bn = 0; $bn -lt $bl.Count; $bn++) { $bout += $bl[$bn]; if ($bn -eq $bi) { $bout += ($bk + $ngHon + ' ' + $ngCs + 'c/s') } }
                $t.M.Body = ($bout -join "`r`n")
                $ngLines[($bk + $ngHon + ' ' + $ngCs + 'c/s')] = $true
            } else { $script:fixNote += ('FAXの本文に親の行が' + $atari.Count + '件：' + [string]$cd + '（差し込みには足したが本文には足していない。人が読んでください）') }
        }
        # 足した行を覚えておく。覚えないと、このあと親の品目（90g入り）を探すときに**自分が足した行まで数えて2件**になり、
        # 「1件でないと直さない」で親の数量が永久に直らない（10/1 実際にそうなった）。
        $ngLines[$ngLine] = $true
        $fixTouched[[string]$t.M.Name] = $true
        $ngPay = $(if ($pm.支払額) { [double]$pm.支払額 } else { [Math]::Round($ngKg * $ngTan) })
        $script:items += [pscustomobject]@{ Code = [string]$cd; Name = ([string]$ng.品名 + ' ' + [string]$ng.荷姿); Kg = [string]$ngKg; Cs = $ngCs; Pay = $ngPay.ToString('#,0'); 直し = ($Moto -eq '直し'); 注意 = $(if ($Moto -eq '直し') { '予定の直しで足した' } else { '' }) }
        $itemCodes[[string]$fkey] = $true
        $script:fixDone += ('' + [string]$cd + ' ' + $ngHon + '：本文と台帳に新しく足した（' + $ngCs + 'c/s・' + [string]$ngKg + 'kg・' + $ngPay.ToString('#,0') + '円）')
    }
    foreach ($i in $items) {
        if (-not $fixMap.Count) { break }
        if (-not $i.Kg -or $i.Kg -eq '0') { continue }
        $fk = Find-Fix $fixMap $i
        if (-not $fk) { if ($Moto -eq '確認') { $script:fixNote += ('確認の一覧に無い品目：' + $i.Code + ' ' + $i.Name) }; continue }   # 2026-10-07 予定の直しは「一覧に無い品」では止めない（直しは一部の品だけ書く・点検役(1)）
        $p = $fixMap[$fk]; $newCs = [string]$p.ケース; $newKg = [string]$p.発注量kg
        if ($Moto -eq '確認' -and [string]$p.確認時のkg) {   # 2026-10-19 18代目ボス②：確認の時の kg と今の1箱kgで出した kg が違う＝欄に残して⚠（数は確認のケースのまま）
            $i | Add-Member -NotePropertyName 確認時のkg -NotePropertyValue ([string]$p.確認時のkg) -Force
            $i | Add-Member -NotePropertyName 注意 -NotePropertyValue ((@([string]$i.注意, ('⚠ 担当者が確認した時の kg（' + [string]$p.確認時のkg + 'kg）と、今の1箱kgで出した kg（' + $newKg + 'kg・' + $newCs + 'c/s）が違う。ケースの数は確認のまま')) | Where-Object { $_ }) -join '／') -Force
        }
        if (-not $newCs) { $script:fixNote += ('確認にケースが無い：' + $i.Code + ' ' + $i.Name); continue }
        if ($newCs -eq [string]$i.Cs -and $newKg -eq [string]$i.Kg) { continue }
        $hits = @()
        foreach ($nm in @((Pack-Name $i), [string]$i.Name, (Hon-Name $i.Code))) {   # 品名で見つからなければ本文名で探す。2026-10-12 大袋/小袋の行は荷姿で組んだ本文の字を先に（学問）
            if (-not $nm -or $hits.Count) { continue }
            foreach ($x in $mails) {
                # 2026-10-01 FAXの相手は差し込み（FaxQty）が本体。両方を見ると同じ品が2件に数えられ、「1件でないと直さない」で必ず止まっていた（阪神・セニヤの3品）
                foreach ($fld in @($(if ($x.Kind -eq 'FAX') { 'FaxQty' } else { 'Body' }))) {
                    $txt = [string]$x.$fld; if (-not $txt) { continue }
                    # 2026-10-01 ヒロツクのFAXだけ作りが違う＝差し込みが**数量の数字だけ**で、品名はPDFの型に入っている（Get-Summary も「わさび昆布 Nc/s」と組み立てている）。
                    #   そのままでは品名の字がどこにも無く、わさび昆布だけ永久に当たらなかった。ここだけ「わさび昆布 Nc/s」という1行として見る。
                    #   **差し込みが数字1つだけのときに限る。** ヒロツクは6品（わさび昆布・しそ味ひじき・ラー油昆布・こもち昆布・ラー油きくらげ・カリカリ梅入りしそ味ひじき）を扱う。
                    #   いまの型はわさび昆布1行だけなので数字1つで済んでいる。2品目が足された日は差し込みの形が変わるので、ここは自動的に外れて普通の照合に戻る（商品マスターの指摘 10/1）。
                    $hiro = ($x.Kind -eq 'FAX' -and $x.Att -eq 'ヒロツク' -and $txt.Trim() -match '^\d+(\.\d+)?$')
                    # 2026-10-01 ここは $( if ) で書かないこと。1行だけの配列は $() を通ると**文字列に潰れ**、$ls[0] が1文字目になる（9/30にも同じ罠で [{}] が出た）
                    if ($hiro) { $ls = @('わさび昆布 ' + $txt.Trim() + 'c/s') } else { $ls = @($txt -split "`r?`n") }
                    for ($n = 0; $n -lt $ls.Count; $n++) { if ($ngLines.ContainsKey($ls[$n])) { continue }   # ここで足した荷姿の行は数えない
                                                           if ((Kana-Same $ls[$n] $nm) -and $ls[$n] -match '(\d+(?:\.\d+)?)\s*c/s') { $hits += [pscustomobject]@{ M = $x; F = $fld; N = $n; Hiro = $hiro; Nm = $nm } } }
                }
            }
        }
        if ($p.人が読む -eq $true -and $hits.Count -eq 0) { continue }   # 2026-10-06 人が読む行の計算の行が本文に無い＝消すものが無いだけ。止めない
        if ($hits.Count -ne 1) { $script:fixNote += ('本文で見つかった行が' + $hits.Count + '件：' + $i.Code + ' ' + $i.Name + '（1件でないと直さない）'); continue }
        $h = $hits[0]
        # 2026-10-23 r9（★10/23 夕「ロットの近似値で発注」・確認画面 版6 r9 ハンコ・24代目ボス 10/23 17:25「作ってよい」）：
        #   AIかおりの読み取りが袋数をいちばん近い箱の数に置いた行は、確認の行の「注意」に「箱の数：」の文が付く＝その便を「送る前に確認」にする印（PBF が確認の理由に写す）
        if ([string]$p.注意 -match '箱の数：') { $hako0 = @(([string]$p.注意) -split '／' | Where-Object { $_ -match '箱の数：' }); $h.M | Add-Member -NotePropertyName 箱の注 -NotePropertyValue (@(@($h.M.箱の注) | Where-Object { $_ }) + @($hako0 | ForEach-Object { [string]$i.Name + '　' + $_ })) -Force }
        if ($h.Hiro) {
            # ヒロツクのFAXは差し込みが数量の数字だけ。数字をそのまま書き換える（「わさび昆布 Nc/s」の形で書き戻すと発注書PDFが壊れる）
            $h.M.FaxQty = $(if (([double]$newCs) -le 0) { '' } else { [string]$newCs })
            if (-not $h.M.FaxQty) { $h.M.Send = '送らない' }
            # 2026-10-01 ヒロツクもメール本文に一覧が載る（本文「・わさび昆布 1kg×12　1c/s」／差し込み 2c/s で食い違っていた。発注ボードの指摘）
            if ([string]$h.M.Body) {
                $bl = @(([string]$h.M.Body) -split "`r?`n"); $atari = @()
                foreach ($bn in 0..($bl.Count - 1)) { if ($ngLines.ContainsKey($bl[$bn])) { continue }
                                                     if ((Kana-Same $bl[$bn] ([string]$i.Name)) -and $bl[$bn] -match '(\d+(?:\.\d+)?)\s*c/s') { $atari += $bn } }
                if ($atari.Count -eq 1) {
                    $bi = $atari[0]
                    if (([double]$newCs) -le 0) { $bl = @($bl | Where-Object { $_ -ne $bl[$bi] }) } else { $bl[$bi] = ($bl[$bi] -replace '(\d+(?:\.\d+)?)(\s*c/s)', ($newCs + '$2')) }
                    $h.M.Body = ($bl -join "`r`n")
                } elseif ($atari.Count -gt 1) { $script:fixNote += ('FAXの本文に同じ品の行が' + $atari.Count + '件：' + $i.Code + ' ' + $i.Name + '（差し込みは直したが本文は直していない。人が読んでください）') }
            }
        } else {
            $ls = @(([string]$h.M.($h.F)) -split "`r?`n"); $before = $ls[$h.N]
            if (([double]$newCs) -le 0) { $ls = @($ls | Where-Object { $_ -ne $before }) } else { $ls[$h.N] = ($before -replace '(\d+(?:\.\d+)?)(\s*c/s)', ($newCs + '$2')) }
            $h.M.($h.F) = ($ls -join "`r`n")
            # 2026-10-01 FAXの相手は、差し込み（FaxQty）のほかに**メール本文にも同じ一覧が載る**（eFaxは本文を表紙として送る）。
            #   差し込みだけ直すと、本文は直す前の数のまま相手に届く＝**1通の中に2通りの数字**が出る。
            #   実際に起きた＝阪神1週目のセニヤ（本文「くんあし1c/s・炙りいわし3c/s」／PDF「炙りいわし2c/s・くんあし無し」。発注ボードの指摘 10/1・送る前に止めた）。
            if ($h.F -eq 'FaxQty' -and [string]$h.M.Body) {
                $bl = @(([string]$h.M.Body) -split "`r?`n"); $atari = @()
                foreach ($bn in 0..($bl.Count - 1)) { if ($ngLines.ContainsKey($bl[$bn])) { continue }   # ここで足した荷姿の行は数えない（90gを直すときに270gの行まで数えて「2件」で止まる）
                                                     if ((Kana-Same $bl[$bn] ([string]$h.Nm)) -and $bl[$bn] -match '(\d+(?:\.\d+)?)\s*c/s') { $atari += $bn } }
                if ($atari.Count -eq 1) {
                    $bi = $atari[0]
                    if (([double]$newCs) -le 0) { $bl = @($bl | Where-Object { $_ -ne $bl[$bi] }) } else { $bl[$bi] = ($bl[$bi] -replace '(\d+(?:\.\d+)?)(\s*c/s)', ($newCs + '$2')) }
                    $h.M.Body = ($bl -join "`r`n")
                } elseif ($atari.Count -gt 1) {
                    $script:fixNote += ('FAXの本文に同じ品の行が' + $atari.Count + '件：' + $i.Code + ' ' + $i.Name + '（差し込みは直したが本文は直していない。人が読んでください）')
                }
            }
        }
        $fixTouched[[string]$h.M.Name] = $true
        $oldPay = [double](([string]$i.Pay) -replace '[^\d\.]', ''); $oldKg = [double](([string]$i.Kg) -replace '[^\d\.]', ''); $comma = ([string]$i.Pay).Contains(',')
        $newPay = $(if ($p.支払額) { [double]$p.支払額 } elseif ($oldKg -gt 0) { [Math]::Round($oldPay / $oldKg * [double](($newKg -replace '[^\d\.]', ''))) } else { $oldPay })
        $script:fixDone += ('' + $i.Code + ' ' + $i.Name + '：' + [string]$i.Cs + $(if ([string]$i.Tani -eq '袋') { '袋' } else { 'c/s' }) + ' → ' + $newCs + $(if ([string]$i.Tani -eq '袋') { '袋' } else { 'c/s' }) + '（' + [string]$i.Kg + 'kg → ' + $newKg + 'kg）')
        $i.Kg = $newKg; $i.Cs = $newCs; $i.Pay = $(if ($comma) { $newPay.ToString('#,0') } else { [string]$newPay })
        if ($Moto -eq '直し') { $i | Add-Member -NotePropertyName 直し -NotePropertyValue $true -Force; $i | Add-Member -NotePropertyName 注意 -NotePropertyValue ((@([string]$i.注意, ('予定の直し：' + $newCs + 'c/s・' + $newKg + 'kg')) | Where-Object { $_ }) -join '／') -Force }   # 2026-10-07 直しで触った品に印（仕入先未定が黙って0に戻さない）
    }
    # 2026-10-06 人が読む行を、頼む先の下書きに「・※本文の字」で足す。頼む先が見つからない行・字が無い行は、その行だけ止めた理由に出す（黙って落とさない）
    foreach ($hr in $handRows) {
        $ji = [string]$hr.本文の字; $saki = [string]$hr.頼む先
        $atama = '人が読む行：' + [string]$hr.商品 + '（頼む先「' + $saki + '」）'
        # 2026-10-29 13枚目（玉井さん 21:35 ハンコ）：担当者の確認の行（$Moto＝確認）は、入れられない文字の行で催事を止めない＝「文字の注文」に積んで熊田さんの画面に出す。予定の直し（$Moto＝直し）は今までどおり止める
        $mjSaki = $(if (-not $saki.Trim() -or $saki -match '不明') { '頼む先が決まっていない' } else { '頼む先が決まっていない（「' + $saki + '」は候補の相手に無い）' })
        if (-not $ji) { if ($Moto -eq '確認') { $script:mojiChumon += [pscustomobject][ordered]@{ 字 = $(if ([string]$hr.商品) { [string]$hr.商品 } else { '（字が無い）' }); 頼む先 = $saki; 理由 = '本文の字が無い・' + $mjSaki } } else { $script:fixNote += ($atama + '＝本文の字が無い') }; continue }
        if ($saki -eq '倉庫出し') { $script:handSouko += ('・※' + $ji); $script:fixDone += ('※' + $ji + '：倉庫出しに足した（人が読む）'); continue }
        $tgt = @($mails | Where-Object { [string]$_.Name -eq $saki }) | Select-Object -First 1
        if (-not $tgt) { if ($Moto -eq '確認') { $script:mojiChumon += [pscustomobject][ordered]@{ 字 = $ji; 頼む先 = $saki; 理由 = $mjSaki } } else { $script:fixNote += ($atama + '＝その相手の下書きが無い（相手の名前は発注案の候補の「相手」と同じ字で）') }; continue }
        if ($tgt.Kind -eq 'FAX' -and $tgt.Att -eq 'ヒロツク') { if ($Moto -eq '確認') { $script:mojiChumon += [pscustomobject][ordered]@{ 字 = $ji; 頼む先 = $saki; 理由 = 'ヒロツクの FAX 用紙は数しか書けない＝下書きに足せない（手で書くか、別の相手か）' } } else { $script:fixNote += ($atama + '＝ヒロツクはFAX用紙の数字だけなので足せない') }; continue }
        $bl = @(([string]$tgt.Body) -split "`r?`n"); $last = -1
        for ($bn = 0; $bn -lt $bl.Count; $bn++) { if ($bl[$bn].Trim().StartsWith('・')) { $last = $bn } }
        $out = @(); for ($bn = 0; $bn -lt $bl.Count; $bn++) { $out += $bl[$bn]; if ($bn -eq $last) { $out += ('・※' + $ji) } }
        if ($last -lt 0) { $out = @('・※' + $ji) + $bl }
        $tgt.Body = ($out -join "`r`n")
        if ($tgt.Kind -eq 'FAX' -and [string]$tgt.FaxQty) { $tgt.FaxQty = ([string]$tgt.FaxQty).TrimEnd() + "`r`n※" + $ji }
        $tgt.Send = '送る'; $fixTouched[[string]$tgt.Name] = $true
        # 2026-10-23 r9：人が読む行（字のまま）で「N袋」が箱の入数で割り切れない時は、数は変えず注だけ（熊田さんが送る時に箱の数に直す・★10/8 唯一の修正者）。入数は品目コードで荷姿が1つに引ける時だけ
        $ng9 = $null; if ([string]$hr.品目コード -and $nisugata.ContainsKey([string]$hr.品目コード)) { $ng9 = $nisugata[[string]$hr.品目コード] }
        $iri9 = 0.0; $fu9 = 0.0
        if ($ng9 -and [double]::TryParse([string]$ng9.'1箱の入数', [ref]$iri9) -and $iri9 -gt 0 -and $ji -match '(\d+)\s*袋' -and [double]::TryParse($Matches[1], [ref]$fu9) -and $fu9 -gt 0 -and ($fu9 % $iri9) -ne 0) {
            $lo9 = [Math]::Floor($fu9 / $iri9); $hi9 = $lo9 + 1; $dlo9 = $fu9 - $lo9 * $iri9; $dhi9 = $hi9 * $iri9 - $fu9
            if ($lo9 -lt 1 -or $dhi9 -lt $dlo9) { $n9 = $hi9 } elseif ($dlo9 -lt $dhi9) { $n9 = $lo9 } else { $n9 = 0 }
            $chu9 = $(if ($n9 -gt 0) { '箱の数：' + [string]$fu9 + '袋→いちばん近い箱の数 ' + [string]$n9 + '箱（' + [string]($n9 * $iri9) + '袋）。送る時に箱の数に直してください（1箱' + [string]$iri9 + '袋入）' } else { '箱の数：' + [string]$fu9 + '袋は ' + [string]$lo9 + '箱と' + [string]$hi9 + '箱の差が同じ＝どちらで頼むか決まりが無い。送る前に玉井さんに確かめてください（1箱' + [string]$iri9 + '袋入）' })
            $tgt | Add-Member -NotePropertyName 箱の注 -NotePropertyValue (@(@($tgt.箱の注) | Where-Object { $_ }) + ('※' + $ji + '　' + $chu9)) -Force
        }
        $script:fixDone += ('※' + $ji + '：' + $saki + 'の下書きに足した（人が読む）')
    }
    # 0c/s で全部消えた相手は送らない（倉庫出しと同じ扱い）
    foreach ($x in $mails) { if ($fixTouched.ContainsKey([string]$x.Name) -and $x.Body -and -not @($x.Body -split "`r?`n" | Where-Object { $_.Trim().StartsWith('・') }).Count) { $x.Send = '送らない' } }
}
. (Join-Path $PSScriptRoot 'shusei_hantei.ps1')   # 2026-10-31 草案（発注チェーンの点検・本番未投入） 項目5
$fixState = '対象外'; $fixDone = @(); $fixNote = @(); $fixTouched = @{}
$mojiChumon = @()   # 2026-10-29 13枚目：下書きに入れられない文字の注文（字・頼む先・理由）。催事は止めず、台帳 修正の反映.文字の注文 に書いて熊田さんの画面と朝の知らせに出す
$handSouko = @()   # 2026-10-06 人が読む行のうち、頼む先が「倉庫出し」のもの（倉庫出しの便は下で作るので、そこで足す）
if ($FixPath -and (Test-Path $FixPath)) {
    $fx = $null
    try { $fx = Get-Content $FixPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $fixState = '反映できない'; $fixNote += '確認のファイルが読めない' }
    if ($fx -and [string]$fx.候補の答え -eq '修正あり') {
        $fixState = '反映できない'
        if ([string]$fx.確認の段階 -ne '済') {
            # 2026-10-14 AIかおり 19：段階が「済」でない＝担当者の確認が途中（マネキン・個人手配の段）。止まりではない＝反映できないと書かない
            $fixState = '確認の途中'
        } else {
            # 2026-10-31 草案（発注チェーンの点検・本番未投入） 項目5：修正の字に「出庫・持ち出し」などの語がある＝倉庫から持ち出した報告か注文か分からない。語だけで捨てない。
            #   人が発注ボードで［注文として当てる］［報告なので当てない］を押すまで、数を変えずに「確かめ待ち」で止める（下書きも作らない）。
            #   前の回にもう当てていた答え（送った相手がいる）なら、その数のまま止める＝今の数を動かさない
            $skb = Get-ShuseiKubun ([string]$fx.修正リスト原文)
            $skKagi = [string]$fx.答えた日時
            $skKimeta = ([bool]$ShuseiAtsukai -and $ShuseiKagi -eq $skKagi)
            if ($skb.区分 -eq '確かめ待ち' -and $skKimeta -and $ShuseiAtsukai -eq '報告') {
                $fixState = '反映しない（報告と確かめた）'; $fixDone += '修正の字は倉庫から持ち出した報告と確かめた＝数は変えない'
            } elseif ($skb.区分 -eq '確かめ待ち' -and -not $skKimeta) {
                $zenkaiAri = ($ShuseiZenkaiKagi -eq $skKagi -and ($ShuseiZenkai -eq '反映した' -or $ShuseiZenkai -like '確かめ待ち（*反映済みの数のまま）'))
                if ($zenkaiAri) { Reflect-Rows @($fx.候補の品目) '確認' }
                $fixState = $(if ($zenkaiAri) { '確かめ待ち（報告か注文か・反映済みの数のまま）' } else { '確かめ待ち（報告か注文か）' })
                $fixNote += ('修正の字に「' + (@($skb.出庫の語) -join '・') + '」がある＝倉庫から持ち出した報告か、注文か分からない' + $(if (@($skb.注文の語).Count) { '（「' + (@($skb.注文の語) -join '・') + '」の語もある）' } else { '' }) + '。数は変えていない。発注ボードで［注文として当てる］か［報告なので当てない］を押す')
            } else {
                Reflect-Rows @($fx.候補の品目) '確認'
                # 2026-10-01 「修正あり」と押されたのに、直った数量が1つも無いなら止める。
                #   由来＝田中さんがページを送らないまま LINE で「あべのハルカス九州展の日程は？」と質問し、**質問文が修正リストとして飲み込まれて「済」まで進んだ**。
                #   品目は元の案と同じ23件だったので「直した品目0件＝反映した」と判定し、5,000,000円の発注が下書き可になっていた（AIかおり fork 5 の連絡で発覚・下書きは0通）。
                if (-not $fixNote.Count -and -not $fixDone.Count -and -not $mojiChumon.Count) { $fixNote += ('「修正あり」なのに直った数量が1つもありません（修正リスト＝「' + [string]$fx.修正リスト原文 + '」）。人が中身を読んでください') }
                if (-not $fixNote.Count) { $fixState = '反映した' }
            }
        }
    } elseif ($fx -and [string]$fx.候補の答え -eq 'OK' -and [string]$fx.確認の段階 -eq '済' -and @($fx.候補の品目).Count) {
        # 2026-10-12 ★10/11 玉井さん「候補は担当者が確認するまで精度を上げ続けて良い。確認後は検討段階なので数字を変えてはならない」（11代目ボス裁定）
        #   これまでは OK の時は何もせず、作り直しのたびに Excel で計算し直していた＝担当者が見て OK した数と、下書きの数がずれうる。
        #   OK でも確認\〈案件ID〉.json の候補の品目（担当者が見た数）を正として、修正ありと同じ道（Reflect-Rows）で当てる。
        #   当てられない（本文の行が無い・2件ある・確認に無い品が増えた）時は下書きを作らない＝確認した数と違う下書きを作らない（process_budget_files が止める）
        $fixState = '反映できない'
        Reflect-Rows @($fx.候補の品目) '確認'
        if (-not $fixNote.Count) { $fixState = '反映した' }
    }
}

# 1a'''') 予定の直し（発注案\予定の直し\〈案件ID〉_〈時刻〉_〈PC〉.json・2026-10-07 玉井さん「発注の予定＝鍵のかかった箱」）
#   鍵を持つPC（熊田さんのPC・倉庫メインPC・自宅メインPC）の窓で直した行。1直し＝1ファイル（Gドライブの衝突コピーを避け、消えない記録にもなる）。
#   読む側で合算する：種別「取り消し」のファイルは、取り消すファイル名の直しを無かったことにする（元のファイルは消さない）。
#   当てる順＝担当者の修正（上）→ ここ → 供給上限（下・物理の上限が勝つ）。種別「これから頼む」は確認の行と同じ反映（Reflect-Rows）で本文と品目を直す。
#   種別「もう頼んである」は本文を触らず、いちばん最後に台帳の品目へ足す（下の 1a'''''''' ）。
$naoshiNote = @(); $naoshiDone = @(); $naoshiLive = @(); $naoshiKiroku = @(); $naoshiCancelled = @(); $naoshiTanomu = @(); $naoshiYari = @()
if ($NaoshiDir -and $CaseId -and (Test-Path $NaoshiDir)) {
    $nAll = @()
    foreach ($nf in @(Get-ChildItem $NaoshiDir -Filter ($CaseId + '_*.json') -ErrorAction SilentlyContinue | Sort-Object Name)) {
        try { $nj = Get-Content $nf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json; $nj | Add-Member -NotePropertyName ファイル -NotePropertyValue $nf.Name -Force; $nAll += $nj }
        catch { $naoshiNote += ('直しのファイルが読めない：' + $nf.Name) }
    }
    $nCancel = @{}
    foreach ($nj in $nAll) { if ([string]$nj.種別 -eq '取り消し' -and [string]$nj.取り消すファイル) { $nCancel[[string]$nj.取り消すファイル] = [string]$nj.ファイル } }
    $naoshiCancelled = @($nCancel.Keys)
    $naoshiLive = @($nAll | Where-Object { [string]$_.種別 -ne '取り消し' -and -not $nCancel.ContainsKey([string]$_.ファイル) })
    foreach ($nj in $naoshiLive) {
        if (-not $nj.行 -or (-not [string]$nj.行.品目コード -and $nj.行.人が読む -ne $true)) { $naoshiNote += ('直しに行が無い：' + [string]$nj.ファイル); continue }
        if ([string]$nj.種別 -eq 'これから頼む' -and ([string]$nj.行.頼む先).EndsWith('〈頼み直し〉')) { $naoshiYari += @($nj.行) }   # 2026-10-12 送った相手への頼み直し＝別の便（下の 1a'''''''''）
        elseif ([string]$nj.種別 -eq 'これから頼む') { $naoshiTanomu += @($nj.行) }
        elseif ([string]$nj.種別 -in @('もう頼んである', '頼んだ分を減らした')) { $naoshiKiroku += $nj }   # 2026-10-08 穴23：送った後に相手へ減らした分の記録（下で引く）
        else { $naoshiNote += ('知らない種別「' + [string]$nj.種別 + '」：' + [string]$nj.ファイル) }
    }
    if (@($naoshiTanomu).Count) {
        $sv1 = @($fixNote); $sv2 = @($fixDone); $fixNote = @(); $fixDone = @()
        Reflect-Rows @($naoshiTanomu) '直し'
        $naoshiNote += @($fixNote); $naoshiDone += @($fixDone)
        $fixNote = $sv1; $fixDone = $sv2
    }
}

# 1a''''') 数量限定の品の割り振りを、実際の発注量に効かせる（2026-10-01 統合設計）
#   供給上限.json の 割り振り.内訳（決めた人＝玉井さん・決め方＝会期の早い順）を読み、この案件の割り振りkgに**本文と品目の数量を合わせる**。
#   これまでは「送る前に確認＋配る量kg」を出すだけで、**数量は人が手で直す宿題**だった（井上の棹前 30→20kg）。
#   担当者の修正より**後**に当てる＝物理の上限が勝つ。割り振り0の品は 発注量0 にして**行は残す**（黙って消さない・商品マスターの依頼）。
$genteiDone = @()
$kyP = Join-Path $PSScriptRoot '供給上限.json'
if ((Test-Path $kyP) -and $CaseId) {
    $ky = $null; try { $ky = Get-Content $kyP -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $ky = $null }
    foreach ($pp in @($ky.品目.PSObject.Properties)) {
        $wk = $null
        foreach ($u in @($pp.Value.割り振り.内訳)) { if ([string]$u.案件ID -eq $CaseId) { $wk = $u } }
        if (-not $wk -or $null -eq $wk.割り振りkg) { continue }
        $newKg = [double]$wk.割り振りkg
        foreach ($i in $items) {
            $c = [string]$i.Code; if ($c.Length -ge 4) { $c = $c.Substring(0, 4) }
            if ($c -ne [string]$pp.Name) { continue }
            $kgAll = [double](([string]$i.Kg) -replace '[^\d\.]', ''); $csAll = [double](([string]$i.Cs) -replace '[^\d\.]', '')
            if ($kgAll -le 0 -or $csAll -le 0) { continue }
            if ([Math]::Abs($kgAll - $newKg) -lt 0.001) { continue }
            $caseKg = $kgAll / $csAll
            $newCs = [Math]::Floor($newKg / $caseKg)
            # 2026-10-19 玉井さん 10/18『担当者がOKした数を作り直しで変えない』（18代目ボス①・★10/11）：担当者が確認した催事（確認の段階＝済・OK／修正あり）は、本文も品目も書き換えない。確保ぶんと違う時は⚠に出すだけ
            if ($fx -and [string]$fx.確認の段階 -eq '済' -and [string]$fx.候補の答え -in @('OK', '修正あり')) {
                if ($newCs -eq [Math]::Floor($csAll) -and [Math]::Abs($newCs * $caseKg - $kgAll) -lt 0.001) { continue }   # 確保ぶんに合わせても同じ数＝何もしない
                $genteiDone += ([string]$i.Name + '：確認済みの ' + $csAll + 'c/s（' + $kgAll + 'kg）はそのまま。今季の確保ぶんは ' + $newKg + 'kg（' + $newCs + 'c/s）＝人が見る')
                $i | Add-Member -NotePropertyName 注意 -NotePropertyValue ((@([string]$i.注意, ('⚠ 今季の確保ぶん（' + $newKg + 'kg・' + $newCs + 'c/s）と違うが、担当者が確認した数（' + $csAll + 'c/s・' + $kgAll + 'kg）はそのまま')) | Where-Object { $_ }) -join '／') -Force
                continue
            }
            $hits = @()
            foreach ($x in $mails) {
                if ($x.Kind -in @('電話メモ', '倉庫出し') -or -not $x.Body) { continue }
                $ls = @($x.Body -split "`r?`n")
                for ($n = 0; $n -lt $ls.Count; $n++) { if ($ls[$n].Trim().StartsWith('・') -and $ls[$n].Contains([string]$i.Name) -and $ls[$n] -match '(\d+(?:\.\d+)?)\s*c/s') { $hits += [pscustomobject]@{ M = $x; N = $n } } }
            }
            if ($hits.Count -eq 1) {
                $h = $hits[0]; $ls = @(([string]$h.M.Body) -split "`r?`n"); $line = $ls[$h.N]
                if ($newCs -le 0) { $ls = @($ls | Where-Object { $_ -ne $line }) } else { $ls[$h.N] = ($line -replace '(\d+(?:\.\d+)?)(\s*c/s)', ([string]$newCs + '$2')) }
                $h.M.Body = ($ls -join "`r`n")
                if (-not @($h.M.Body -split "`r?`n" | Where-Object { $_.Trim().StartsWith('・') }).Count) { $h.M.Send = '送らない' }
            }
            $oldPay = [double](([string]$i.Pay) -replace '[^\d\.]', ''); $comma = ([string]$i.Pay).Contains(',')
            $newPay = $(if ($kgAll -gt 0) { [Math]::Round($oldPay / $kgAll * ($newCs * $caseKg)) } else { 0 })
            $genteiDone += ([string]$i.Name + '：' + $csAll + 'c/s（' + $kgAll + 'kg）→ ' + $newCs + 'c/s（' + ($newCs * $caseKg) + 'kg）' + $(if ($newCs -le 0) { '＝今季の確保ぶんが尽きた' } else { '' }))
            $i.Kg = [string]($newCs * $caseKg); $i.Cs = [string]$newCs; $i.Pay = $(if ($comma) { $newPay.ToString('#,0') } else { [string]$newPay })
            $i | Add-Member -NotePropertyName 注意 -NotePropertyValue $(if ($newCs -le 0) { '今季の確保ぶんが尽きた（割り振り0・行は残す）' } else { '今季の確保に合わせて ' + ($newCs * $caseKg) + 'kg に減らした' }) -Force
        }
    }
}

# 1a'''''') 仕入先が手配できなくなった品（仕入先未定.json・2026-10-07 阿川食品の干貝柱）。
#   本文の「・品名 Nc/s」の行を抜いて発注しない。品目は量0にして注意を残す（黙って落とさない＝ボードが「仕入先未定」と出す）
$mitei = $null; $miteiP = Join-Path $PSScriptRoot '仕入先未定.json'
if (Test-Path $miteiP) { try { $mitei = Get-Content $miteiP -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $mitei = $null } }
foreach ($pp in @($mitei.品目.PSObject.Properties)) {
    if ($CaseId -and @($pp.Value.除く案件ID) -contains $CaseId) { continue }   # 下書き済で人が手で直して送る最中の案件（作り直しで候補に戻さない）
    foreach ($i in $items) {
        $c = [string]$i.Code; if ($c.Length -ge 4) { $c = $c.Substring(0, 4) }
        if ($c -ne [string]$pp.Name) { continue }
        if ($i.直し -eq $true) { $i | Add-Member -NotePropertyName 注意 -NotePropertyValue ((@([string]$i.注意, ('仕入先未定の決まり（' + [string]$pp.Value.理由 + '）より、鍵を持つ人の予定の直しを先にした')) | Where-Object { $_ }) -join '／') -Force; continue }   # 2026-10-07 予定の直しで人が入れた品は、仕入先未定で黙って0に戻さない
        $csAll = [double](([string]$i.Cs) -replace '[^\d\.]', ''); $kgAll = [double](([string]$i.Kg) -replace '[^\d\.]', '')
        if ($csAll -le 0) { continue }
        foreach ($x in $mails) {
            if ($x.Kind -in @('電話メモ', '倉庫出し') -or -not $x.Body) { continue }
            $ls = @($x.Body -split "`r?`n")
            $keep = @($ls | Where-Object { -not ($_.Trim().StartsWith('・') -and $_.Contains([string]$i.Name) -and $_ -match '\d+(?:\.\d+)?\s*c/s') })
            if ($keep.Count -ne $ls.Count) {
                $x.Body = ($keep -join "`r`n")
                if (-not @($keep | Where-Object { $_.Trim().StartsWith('・') }).Count) { $x.Send = '送らない' }
            }
        }
        $i | Add-Member -NotePropertyName 注意 -NotePropertyValue ('仕入先未定：' + [string]$pp.Value.理由 + '。元の量 ' + $csAll + 'c/s（' + $kgAll + 'kg）＝どこから頼むか決まるまで発注しない') -Force
        $i.Kg = '0'; $i.Cs = '0'; $i.Pay = '0'
    }
}

# 1a') ロットで仕入れて倉庫に置く品（倉庫ストック品.json：しそひじき・羅臼昆布のり）は、仕入先に頼まず倉庫から出す（2026-09-22 玉井さん）
#   本文の「・品名 Nc/s」の行を仕入先の下書きから抜き、「倉庫出し」の候補1つにまとめる。抜いた結果、行が0になった相手は「送らない」
# 2026-10-16 倉庫出しの行がもう「倉庫から出した」の催事は、倉庫の今（出した後の数）で引き当てを計算し直さない。
#   由来＝在庫が倉庫の7品を実数0にした後の作り直し（10/16 16:50）で、阪神1週目（10/14 に倉庫から出した）の焼貝ひも2c/s・燻製3c/s が
#   倉庫出しから消えて阿川食品へ戻った（二重発注の一歩手前）。出した量（前の台帳の引き当て）をそのまま「使える量」にする＝
#   同じ品が同じ量だけ仕入先の本文から引かれる。ほかの催事の押さえ・倉庫から出さない.json は見ない（もう出してある）。欄「追加の持ち出し」（2回目〜）は数えない
$dashitaOn = [bool]$DashitaJson; $dashita = @()
if ($dashitaOn) { try { $dj = $DashitaJson | ConvertFrom-Json; $dashita = @(@($dj.引き当て) | Where-Object { $_ -and [string]$_.品目コード }) } catch { throw ('倉庫から出した行の引き当てが読めません：' + $_) } }
function Is-Lot($hk) { return (@($hk.元) -join '') -match 'ロット品' }
$dsLotNote = @()
$pull = @(); $sousai = @()   # 2026-09-30 「倉庫出し」の行と相殺の記録は、ロットの品と催事の残りで共通にする（下の2つの塊が足す）
$lotHiki = @()   # 2026-10-06 ロット品を倉庫から出した分も「引き当て」に入れる（入れていなかった＝阪神1週目の羅臼16kgが引き当てから抜けていた）
$stockPath = Join-Path $PSScriptRoot '倉庫ストック品.json'
# 2026-10-06 ロット品は袋（1kg）で出す（玉井さん「1kg入り×16袋で1ケース。小分けで出してよい」）。字は「品名 Nkg（1kg×N袋）」。
#   古い字「Nc/s」は N × 1ケースkg で読む（最小単位kg は1になったので、c/s に掛けると16分の1になる）
function Lot-Kg([string]$t, $sp) {
    if ($t -match '(\d+(?:\.\d+)?)\s*kg（1kg') { return [double]$Matches[1] }
    if ($t -match '(\d+(?:\.\d+)?)\s*c/s') { $ck = [double]$sp.'1ケースkg'; if ($ck -le 0) { $ck = [double]$sp.最小単位kg }; return [double]$Matches[1] * $ck }
    return 0
}
if ((Test-Path $stockPath) -and -not $Taishougai) {
    $stock = Get-Content $stockPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $alias = @{}
    foreach ($p in $stock.品目.PSObject.Properties) { $alias[[string]$p.Value.品名] = $p.Name; foreach ($a in @($p.Value.別名)) { if ($a) { $alias[[string]$a] = $p.Name } } }
    $alias['しそ味ひじき'] = 'K015'
    # 使える在庫＝起点＋動き−（この催事より前に始まる催事の、まだ倉庫から出していない倉庫出し）。足りない分は仕入先の注文に残す（2026-09-22 玉井さん「相殺していくら発注になったかを報告」）
    $avail = @{}
    # 2026-10-09 在庫の会話の依頼（設計 柱4-1）：倉庫の数は倉庫在庫.json の「今」（〈コード〉-01）。自分の会期の出庫は足し戻す（今までの「自分の会期の出庫は引かない」と同じ）
    $zLot = $null; try { $zLot = Get-Content (Join-Path (Split-Path $PSScriptRoot -Parent) '倉庫在庫.json') -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $zLot = $null }
    foreach ($p in $stock.品目.PSObject.Properties) {
        $zi = $(if ($zLot -and $zLot.品目) { $zLot.品目.($p.Name + '-01') } else { $null })
        if ($zi -and $zi.引当に使える -eq $false) { $v = 0 }   # 2026-10-19 在庫の依頼（追09）：引当に使える=false は今を0と見る
        elseif ($zi -and $null -ne $zi.今) { $v = [double]$zi.今; foreach ($h in @($zi.履歴)) { if ($h -and [string]$h.種類 -eq '出庫' -and [string]$h.案件ID -eq $CaseId) { $v += [double]$h.kg } } }
        else { $v = [double]$stock.起点.在庫kg.($p.Name); foreach ($mv in @($stock.動き)) { if ($mv -and $mv.品目コード -eq $p.Name -and $mv.案件ID -ne $CaseId) { $v += [double]$mv.kg } } }   # 読めない時だけ古い起点＋動き
        $avail[$p.Name] = $v
    }   # 2026-09-22 点検役⛔①：自分の会期の出庫は引かない（引くと［倉庫から出した］の後の作り直しで倉庫出しが消え、同じ量を仕入先にも頼む）
    $myStart = $(if ($CaseId -match '^(\d{8})') { $Matches[1] } else { '99999999' })
    foreach ($lf in (Get-ChildItem (Join-Path (Split-Path $PSScriptRoot -Parent) '発注案') -Filter *.json -ErrorAction SilentlyContinue)) {
        if ($CaseId -and [string]::CompareOrdinal([string]$lf.BaseName, [string]$CaseId) -ge 0) { continue }   # 2026-10-19 16代目の手3 P4：同じ日に始まる催事は案件IDの字の順で先の方が先に取り置く（前は同じ日どうしが互いに押さえず二重に当たった）。案件IDが空なら前と同じ＝全部数える
        try { $ld = Get-Content $lf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
        if ($ld.対象外 -eq $true) { continue }   # 2026-09-30 仕組みの対象外の催事は倉庫を押さえない（ボードの［倉庫から出した］が押されず、在庫が永久に凍るため）
        foreach ($cc in @($ld.候補)) {
            if ($cc.方法 -ne '倉庫出し' -or $cc.状態 -in @('倉庫から出した', '不要') -or $cc.候補外 -eq $true) { continue }   # 2026-09-30 候補外になった行は押さえない
            # 2026-10-06「中身」は画面用で途中が「…」で切れる＝中身全文を読む。量は kg の字か c/s×1ケースkg
            $zen = $(if ([string]$cc.中身全文) { [string]$cc.中身全文 } else { [string]$cc.中身 })
            foreach ($part in ($zen -split '／')) { foreach ($k in $alias.Keys) { if ($part.Contains($k)) { $code = $alias[$k]; $q = Lot-Kg $part $stock.品目.$code; if ($q -gt 0) { $avail[$code] -= $q }; break } } }
        }
    }
    if ($dashitaOn) {   # 2026-10-16 もう倉庫から出した催事＝使える量は出したロット品の量だけ（倉庫の今・ほかの催事の押さえは見ない）
        foreach ($k in @($avail.Keys)) { $avail[$k] = 0 }
        foreach ($hk in $dashita) { if (Is-Lot $hk) { $cd = [string]$hk.品目コード; $avail[$cd] = $(if ($avail.ContainsKey($cd)) { $avail[$cd] } else { 0 }) + [double]$hk.kg } }
    }
    foreach ($x in $mails) {
        if ($x.Kind -in @('電話メモ', '倉庫出し') -or -not $x.Body) { continue }
        $keep = @(); $took = $false
        foreach ($ln in ($x.Body -split "`r?`n")) {
            $hit = $null
            if ($ln.Trim().StartsWith('・')) { foreach ($k in $alias.Keys) { if ($ln.Contains($k)) { $hit = $k; break } } }
            $ok = $false; $pullLine = ''
            if ($hit -and $ln -match '(\d+(?:\.\d+)?)\s*c/s') {
                $code = $alias[$hit]; $sp = $stock.品目.$code
                # 2026-10-06 要る量は品目の発注量kg（担当者の修正が入っていればその量＝井上の羅臼10kg）。取れなければ c/s×1ケースkg
                $itm = @($items | Where-Object { [string]$_.Code -eq $code }) | Select-Object -First 1
                $itKg = $(if ($itm) { [double](([string]$itm.Kg) -replace '[^\d\.]', '') } else { 0 })
                $need = $(if ($itKg -gt 0) { $itKg } else { Lot-Kg $ln $sp })
                $ok = ($need -gt 0 -and $avail[$code] -ge $need)
                # 2026-10-16 点検役⛔2：もう倉庫から出した催事でロット品の量が出した量より増えた＝ロットの行は丸ごと仕入先に残る（出した分と二重）。黙らず画面へ出す
                if (-not $ok -and $dashitaOn -and $avail[$code] -gt 0) { $dsLotNote += ([string]$sp.品名 + '：もう倉庫から ' + $avail[$code] + 'kg 出したのに、要る量が ' + $need + 'kg に増えた＝仕入先の行は全量のまま。出した分と二重にならないよう人が仕入先の数を直す') }
                $sousai += [ordered]@{ 品目 = $hit; 相手 = $x.Name; 注文 = $ln.Trim().TrimStart('・'); 必要kg = $need; 使える在庫kg = $avail[$code]; 結果 = $(if ($ok) { '倉庫から出す（仕入先には頼まない）' } else { '在庫が足りない＝仕入先に頼む' }) }
                if ($ok) {
                    $avail[$code] -= $need
                    $bags = [Math]::Ceiling($need / [Math]::Max(0.001, [double]$sp.最小単位kg))
                    $pullLine = '・' + [string]$sp.品名 + ' ' + $need + 'kg（1kg×' + $bags + '袋）'
                    $lotHiki += [ordered]@{ 品目コード = $code; 品名 = [string]$sp.品名; kg = $need; 袋 = $bags; ケース = $null; 元 = @('倉庫ストック品（ロット品）') }
                }
            }
            if ($ok) { $pull += $pullLine; $took = $true } else { $keep += $ln }   # 2026-09-30 「（〜から倉庫へ）」は後で必ず消していた＝品名に（）がある品（【青山】燻製ホタテヒモ（辛口））で消しすぎて数量まで落ちた。最初から付けない
        }
        if ($took) {
            $x.Body = ($keep -join "`r`n")
            if (-not @($keep | Where-Object { $_.Trim().StartsWith('・') }).Count) { $x.Send = '送らない' }
        }
    }
}

# 1a'''') 催事の最終日の残り（倉庫在庫.json）を、次の催事の発注から引く＝引当（2026-09-30 統合設計・ゴールG1「10/7 引当が効く」）
#   倉庫在庫.json は在庫スワイプ棚卸しの持ち場＝**ここでは読むだけ**。1ケースに満たない残りは当てない（半端は倉庫に残す）。
#   ほかの発注案が先に押さえている分（まだ「倉庫から出した」になっていない倉庫出し）は引いてから数える＝同じ在庫を二重に当てない。
#   本文の行が見つからない・2つ以上あるときは当てない（fail-closed）。
$zaikoPath = Join-Path (Split-Path $PSScriptRoot -Parent) '倉庫在庫.json'
$zHiki = @($lotHiki); $zNashi = @($dsLotNote)   # 2026-10-06 ロット品の分を先に入れておく／$zNashi＝倉庫に在庫があるのに当てなかった理由（発注ボードが画面に出す）
if ((Test-Path $zaikoPath) -and -not $Taishougai) {
    $z = $null; try { $z = Get-Content $zaikoPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $z = $null }
    if ($z -and $z.品目) {
        $zAvail = @{}; $zMoto = @{}
        $zAvailNi = @{}   # 2026-10-12 荷姿の番号ごとの残り（K054-01 など）。学問の大袋・小袋は同じ品目コード＝4字で足すと混ざる（12代目ボス裁定）
        # 2026-10-07 荷姿ごとの「倉庫から出さない」（倉庫から出さない.json の 品目の決まり・全案件）。
        #   玉井さん「倉庫のダルマは予備として取っておく、と何度も伝えている」＝13kgの箱（K017-01）は数えない。1kg袋（K017-02）は数える。
        #   それまでは案件ごとにしか書いておらず、合計kgで数えていたので近鉄和歌山に13kgの箱65kgが当たっていた
        $dasanaiNi = @{}
        try { $dnAll = Get-Content (Join-Path $PSScriptRoot '倉庫から出さない.json') -Raw -Encoding UTF8 | ConvertFrom-Json; foreach ($pp in @($dnAll.品目の決まり.PSObject.Properties)) { if ([string]$pp.Name -match '^K\d{3}-\d{2}$') { $dasanaiNi[[string]$pp.Name] = [string]$pp.Value.理由 } } } catch {}
        foreach ($p in $z.品目.PSObject.Properties) {
            if ($dasanaiNi.ContainsKey([string]$p.Name)) { continue }
            if ($p.Value.引当に使える -eq $false) { continue }   # 2026-10-19 在庫の依頼（10/16・追09）＋16代目の手3 P0：数えて45日/90日を過ぎた・量の分からない持ち出しがある・今がマイナス＝取り置きに使わない（今を0と見て仕入先へ）
            $cd = ([string]$p.Name -split '-')[0]
            # 2026-09-30 23:10 「引当済み」は引かない。在庫スワイプ棚卸しが、この発注案の引き当てを倉庫在庫.json に書き戻すようになったため、
            #   ここで引くと自分の引き当てを自分で引く＝毎回減っていく（実際に井上の鮭燻製ソフト8kgが1回で消えた）。押さえの判定は下の発注案の走査に一本化する。
            $nokori = [double]$p.Value.今
            if ($nokori -le 0) { continue }   # マイナスは「入庫の記録が無い」印＝0として扱う（2026-09-28 玉井さん）
            $zAvail[$cd] = $(if ($zAvail.ContainsKey($cd)) { $zAvail[$cd] } else { 0 }) + $nokori
            if ([string]$p.Name -match '^K\d{3}-\d{2}$') { $zAvailNi[[string]$p.Name] = $nokori }
            foreach ($h in @($p.Value.履歴)) { if ([string]$h.種類 -eq '入庫' -and $h.案件ID) { $zMoto[$cd] = @(@($zMoto[$cd]) + [string]$h.案件ID | Where-Object { $_ } | Select-Object -Unique) } }
        }
        # 2026-10-01 人が数えた実数があれば、その品だけ**置き換える**（足さない）。
        #   由来＝倉庫在庫.json の履歴は「催事の最終日の残り」と「出庫」しか持たず、**仕入先から宝塚倉庫へ届いた分を記録する経路が無い**。
        #   そのため9月に届いたダルマ・ホタテ焼貝ひも・わさび昆布・海藻サラダが「無い」と見え、同じ量を仕入先に頼む側へ乗った（阪神1週目・438,800円）。
        #   数えていない品はそのまま（範囲はクシロー分。載っていない小袋が0かどうかは確かめていない）。
        #   倉庫在庫.json は在庫スワイプ棚卸しの持ち場なので**書かない**。ここは読んで引当に使うだけ。
        $jitsuDir = Join-Path (Split-Path $PSScriptRoot -Parent) '在庫の材料'
        # 2026-10-06 実数のファイルを**古い順に全部**読み、品ごとに新しい日の数で置き換える（前は最新の1ファイルだけ）。
        #   由来＝10/3 11:45 玉井さんの「倉庫総在庫（引当前）」で燻製ホタテヒモが30kg（10/1の40kgから岡山へ10kg）。燻製だけの追記ファイルを置けるように
        #   さらに、全部を数えた日のファイル（範囲に「全部」と書いたもの＝10/1）に載っていない品は、倉庫在庫.json の残りを使わず0扱い
        #   （10/1 玉井さん「まだ報告していない在庫を当てにしない」・10/6 ボス異論なし。丸かじり氷下魚14.4kgを当てていた）
        $jf = @(Get-ChildItem $jitsuDir -Filter '*_倉庫の実数_*.json' -ErrorAction SilentlyContinue | Sort-Object Name)
        if ($jf.Count) {
            $jMap = @{}; $jWhen = @{}; $zenbu = $false
            foreach ($jfile in $jf) {
                $jj = $null; try { $jj = Get-Content $jfile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $jj = $null }
                if (-not $jj -or -not $jj.読み取り) { continue }
                if ([string]$jj.全部を数えた -eq 'true' -or $jj.全部を数えた -eq $true) { $zenbu = $true }
                $fMap = @{}; $fUchi = @{}; $fNi = @{}
                # 荷姿ごとの内訳も持っておく（$jUchi は外側で作ってある）。合計kgだけだと「13kgの箱」と「1kgの袋22」が区別できず、
                # 画面に「ダルマ（13㎏）1c/s」と出て、熊田さんが**無い13kgの箱を探す**ことになる（発注ボードの指摘 10/1）。
                foreach ($r in @($jj.読み取り)) {
                    $ate = [string]$r.'当てはめ（AIかおりの推定）'; if (-not $ate) { $ate = [string]$r.当てはめ }
                    if ($ate -notmatch '^(K\d{3})') { continue }   # 品目コードで始まらない行は当てない（ザンギ用・学問のするめ用・珍味の冷凍など）
                    $c4 = $Matches[1]; $kg = [double]$r.kg
                    if ($ate -match '^(K\d{3}-\d{2})' -and $dasanaiNi.ContainsKey($Matches[1])) { if ($kg -gt 0) { $zNashi += ([string]$r.'原文の品名' + ' ' + [string]$r.'原文の数' + '：' + $dasanaiNi[$Matches[1]]) }; continue }   # 2026-10-07 予備の荷姿は数えない
                    if ($kg -lt 0) { continue }
                    $niCode = $(if ($ate -match '^(K\d{3}-\d{2})') { $Matches[1] } else { '' })   # 2026-10-08 荷姿コード（1kgの袋か13kgの箱か）
                    # 0 も意味のある数＝「数えたら無かった」。読み飛ばすと台帳の古い数が生き残り、現物の無い引当が付いたままになる
                    # （10/1 鮭燻製ソフト＝倉庫に0なのに12kg引き当てていた。田中さんが高槻へ持ち込んだ22kgが出庫に記録されていないため）
                    $fMap[$c4] = $(if ($fMap.ContainsKey($c4)) { $fMap[$c4] } else { 0 }) + $kg
                    if ($kg -gt 0) { $fUchi[$c4] = @(@($fUchi[$c4]) + ([string]$r.'原文の品名' + ' ' + [string]$r.'原文の数') | Where-Object { $_ }) }
                    # 2026-10-08 1個の重さは**実数の原文の数**（「13kg×5」「1kg×22」「10kg×4ケース」）から読む。荷姿の表（品目.json）には箱の行が無い品がある（燻製ホタテヒモ・焼貝ひもは 1kg の行しか無い）ので、表の1個kgで判定すると箱を端数と誤る。「30kg」のように×が無い行は単位が分からない＝0
                    $unitKg = $(if ([string]$r.'原文の数' -match '(\d+(?:\.\d+)?)\s*kg\s*[×xX]') { [double]$Matches[1] } else { 0 })
                    if ($kg -gt 0) { $fNi[$c4] = @(@($fNi[$c4]) + [pscustomobject]@{ 荷姿 = $niCode; 単位kg = $unitKg; 品名 = [string]$r.'原文の品名'; kg = $kg; 区分 = [string]$(if ($niCode -and $nisugata.ContainsKey($niCode)) { $nisugata[$niCode].区分 } else { '' }) } | Where-Object { $_ }) }
                }
                foreach ($c4 in @($fMap.Keys)) { $jMap[$c4] = $fMap[$c4]; $jWhen[$c4] = ([string]$jj.数えた日時 + '（' + [string]$jj.数えた人 + '）'); $jUchi[$c4] = @($fUchi[$c4]); $jNi[$c4] = @($fNi[$c4]) }
            }
            # 2026-10-08 18:15 置き換えをやめた（ボスの依頼 18:03・在庫の [返事] 18:10）。倉庫在庫.json の「今」が「実数＋実数の日より後の入庫−実数の日以後の出庫」になった＝
            #   ここで実数ファイルの数に置き換えると、数えた後に出した分を引かない＝同じ在庫を2つの催事に当てる。数は上の「今」だけを使う。
            #   実数ファイルは荷姿の内訳（$jUchi・$jNi＝倉庫出しの字）と、どこから来た数かの印にだけ使う。「全部を数えた日に無い＝0」も倉庫在庫.json 側で入っている。
            #   切り替えの日に旧と新を14品で比べて全部同じ（燻製ホタテヒモ30・ダルマ22 ほか）。退避＝退避\make_order_drafts_20261008_1815_jitsu_okikae_mae.ps1
            foreach ($c4 in @($jMap.Keys)) {
                if ($zAvail.ContainsKey($c4)) { $zMoto[$c4] = @('倉庫在庫.json の今（人が数えた実数 ' + $jWhen[$c4] + '＋その後の出入り）') }
            }
        }
        $myStart2 = $(if ($CaseId -match '^(\d{8})') { $Matches[1] } else { '99999999' })
        foreach ($lf in (Get-ChildItem (Join-Path (Split-Path $PSScriptRoot -Parent) '発注案') -Filter *.json -ErrorAction SilentlyContinue)) {
            if ($CaseId -and [string]::CompareOrdinal([string]$lf.BaseName, [string]$CaseId) -ge 0) { continue }   # 2026-10-19 手3 P4（上と同じ）
            try { $ld = Get-Content $lf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
            if ($ld.対象外 -eq $true) { continue }   # 仕組みの対象外の催事は倉庫を押さえない（この仕組みの外で頼むため、ボードの［倉庫から出した］が押されない＝在庫が永久に凍る）
            foreach ($cc in @($ld.候補)) {
                if ($cc.方法 -ne '倉庫出し' -or $cc.状態 -in @('倉庫から出した', '不要') -or $cc.候補外 -eq $true) { continue }   # 2026-09-30 候補外になった行は押さえない
                foreach ($hk in @($cc.引き当て)) {
                    $cd = [string]$hk.品目コード
                    # 2026-10-12 袋物の引き当ては荷姿の番号（K054-01）で持つ＝荷姿の残りと品目の残りの両方から引く
                    if ($cd -match '^K\d{3}-\d{2}$') { if ($zAvailNi.ContainsKey($cd)) { $zAvailNi[$cd] -= [double]$hk.kg }; $cd = $cd.Substring(0, 4) }
                    if ($cd -and $zAvail.ContainsKey($cd)) { $zAvail[$cd] -= [double]$hk.kg }
                }
            }
        }
        # 2026-10-01 玉井さんの決定＝この催事のこの品は倉庫から出さない（倉庫から出さない.json）。
        #   「青山ダルマは、今回はメーカーに発注します」「メーカーから直送した方が送料に無駄がない。予備の意味もある」。
        #   上限kg＝0 ならぜんぶ仕入先。数が入っていれば、そこまでは倉庫から出してよい。
        if ($dashitaOn) {   # 2026-10-16 もう倉庫から出した催事＝使える量は出した量だけ（ロット品は上で出した＝ここでは数えない）。元の字も出した時のまま
            $zAvail = @{}; $zAvailNi = @{}
            foreach ($hk in $dashita) {
                if (Is-Lot $hk) { continue }
                $cd = [string]$hk.品目コード; $kg = [double]$hk.kg
                if ($cd -match '^K\d{3}-\d{2}$') { $zAvailNi[$cd] = $(if ($zAvailNi.ContainsKey($cd)) { $zAvailNi[$cd] } else { 0 }) + $kg; $cd = $cd.Substring(0, 4) }
                $zAvail[$cd] = $(if ($zAvail.ContainsKey($cd)) { $zAvail[$cd] } else { 0 }) + $kg
                if (@($hk.元).Count) { $zMoto[$cd] = @($hk.元) }
            }
        }
        $dasanaiP = Join-Path $PSScriptRoot '倉庫から出さない.json'
        if ((Test-Path $dasanaiP) -and -not $dashitaOn) {
            try {
                $dn = Get-Content $dasanaiP -Raw -Encoding UTF8 | ConvertFrom-Json
                $mine = $dn.案件.$CaseId
                if ($mine) {
                    foreach ($pp in @($mine.PSObject.Properties)) {
                        $c4 = [string]$pp.Name; $lim = [double]$pp.Value.上限kg
                        if (-not $zAvail.ContainsKey($c4)) { continue }
                        if ($lim -le 0) { $zAvail.Remove($c4); $zNashi += ([string]$pp.Value.理由) }
                        elseif ($zAvail[$c4] -gt $lim) { $zAvail[$c4] = $lim }
                    }
                }
            } catch { $zNashi += '倉庫から出さない.json が読めません（人が中身を見てください）' }
        }
        foreach ($i in $items) {
            $kgAll = [double](([string]$i.Kg) -replace '[^\d\.]', ''); $csAll = [double](([string]$i.Cs) -replace '[^\d\.]', '')
            if ($kgAll -le 0 -or $csAll -le 0) { continue }
            $cd = [string]$i.Code; if ($cd.Length -ge 4) { $cd = $cd.Substring(0, 4) }
            if (-not $zAvail.ContainsKey($cd)) { continue }
            # 2026-10-12 学問の袋物（大袋／小袋）＝★10/8「余りは次の発注で相殺」。12代目ボスの裁定：
            #   ①引く在庫は荷姿の番号（Excel X列＝$i.Nisugata）だけ ②本文の行は Pack-Name（「品名 荷姿（N袋入）」）で探す
            #   ③確認済みの催事（担当者が OK／修正ありで答えた）は変えない（★10/11） ④1箱に満たない手持ちも**袋の数で引いてから箱に切り上げる**
            #   新しい箱数＝ceil(max(0, 必要袋−倉庫の袋)/入数)・倉庫から出す袋＝必要袋−新しい箱数×入数。箱が減らない時は本文を触らない
            $bNi = [string]$i.Nisugata; $bIri = [double](([string]$i.Iri) -replace '[^\d\.]', '')
            if ((Fix-Suffix ([string]$i.Name)) -and $bNi -and $nisugata.ContainsKey($bNi) -and [double]$nisugata[$bNi].'1個kg' -gt 0 -and $bIri -gt 0) {
                if ($fx -and [string]$fx.確認の段階 -eq '済' -and [string]$fx.候補の答え -in @('OK', '修正あり')) { continue }
                $bKg = [double]$nisugata[$bNi].'1個kg'
                $bAv = $(if ($zAvailNi.ContainsKey($bNi)) { [double]$zAvailNi[$bNi] } else { 0 })
                if ($zAvail[$cd] -lt $bAv) { $bAv = [Math]::Max(0, [double]$zAvail[$cd]) }   # 倉庫から出さない.json の上限・他の催事の押さえ（4字）を超えない
                $bZai = [Math]::Floor([Math]::Round($bAv / $bKg, 6))   # 浮動小数点で1袋落とさない（記憶 float-floor-no-wana）
                if ($bZai -lt 1) { continue }
                $bPn = Pack-Name $i
                if (-not $bPn) { continue }
                $hits = @()
                foreach ($x in $mails) {
                    if ($x.Kind -eq '倉庫出し' -or -not $x.Body) { continue }
                    $ls = @($x.Body -split "`r?`n")
                    for ($n = 0; $n -lt $ls.Count; $n++) { if ($ls[$n].Trim().StartsWith('・') -and (Kana-Same $ls[$n] $bPn) -and $ls[$n] -match '(\d+(?:\.\d+)?)\s*c/s') { $hits += [pscustomobject]@{ M = $x; N = $n; Cs = [double]$Matches[1]; Nm = $bPn } } }
                }
                if ($hits.Count -ne 1) { $zNashi += ([string]$i.Name + '：本文の行（' + $bPn + '）が' + $hits.Count + '件あって、どれか決められません'); continue }
                $h = $hits[0]; $isFax = ($h.M.Kind -eq 'FAX')
                $fl = @(); $fi = -1
                if ($isFax) {
                    $fl = @(([string]$h.M.FaxQty) -split "`r?`n"); $fa = @()
                    foreach ($fn in 0..($fl.Count - 1)) { if ($ngLines.ContainsKey($fl[$fn])) { continue }
                                                         if ((Kana-Same $fl[$fn] $bPn) -and $fl[$fn] -match '(\d+(?:\.\d+)?)\s*c/s') { $fa += $fn } }
                    if ($fa.Count -ne 1) { $zNashi += ([string]$i.Name + '：FAXの差し込みに同じ品の行が' + $fa.Count + '件。倉庫から出さずに仕入先へ頼みます'); continue }
                    $fi = $fa[0]
                }
                $hCs = $h.Cs
                $bNeed = $hCs * $bIri
                $bNew = [Math]::Ceiling([Math]::Max(0, $bNeed - $bZai) / $bIri)
                $sentTxt = $(if ($sentMap.ContainsKey([string]$h.M.Name)) { [string]$sentMap[[string]$h.M.Name] } else { $null })
                if ($null -ne $sentTxt) {
                    $sentCs = 0.0
                    foreach ($seg in @($sentTxt -split '／')) { if ((Kana-Same $seg $bPn) -and $seg -match '(\d+(?:\.\d+)?)\s*c/s') { $sentCs += [double]$Matches[1] } }
                    if ($sentCs -gt 0) { $bNew = [Math]::Max($bNew, $sentCs) }   # 送った数より下へは削らない
                }
                if ($bNew -ge $hCs) { $zNashi += ([string]$i.Name + '：倉庫の ' + $bZai + '袋では箱を減らせません（1箱 ' + $bIri + '袋・必要 ' + $bNeed + '袋）'); continue }
                $bPull = $bNeed - $bNew * $bIri
                $bPullKg = [Math]::Round($bPull * $bKg, 3)
                $ls = @(([string]$h.M.Body) -split "`r?`n"); $line = $ls[$h.N]
                if ($bNew -le 0) { $ls = @($ls | Where-Object { $_ -ne $line }) } else { $ls[$h.N] = ($line -replace '(\d+(?:\.\d+)?)(\s*c/s)', ([string]$bNew + '$2')) }
                $h.M.Body = ($ls -join "`r`n")
                if ($isFax) {
                    if ($bNew -le 0) { $fl = @($fl | Where-Object { $_ -ne $fl[$fi] }) } else { $fl[$fi] = ($fl[$fi] -replace '(\d+(?:\.\d+)?)(\s*c/s)', ([string]$bNew + '$2')) }
                    $h.M.FaxQty = ($fl -join "`r`n")
                }
                $karappo = $(if ($h.M.Kind -eq 'FAX') { -not ([string]$h.M.FaxQty).Trim() } else { -not @($h.M.Body -split "`r?`n" | Where-Object { $_.Trim().StartsWith('・') }).Count })
                if ($karappo) { $h.M.Send = '送らない' }
                # 倉庫出しの字は kg 入り（出荷の板・［倉庫から出した］が読める形）＝「・オクトパス（いか） 90g 3.87kg（90g×43袋）」
                $bHin = (([string]$i.Name) -replace '\s*(大袋|小袋)\s*$', '')
                $bNs = [string]$nisugata[$bNi].荷姿
                $pull += ('・' + $bHin + ' ' + $bNs + ' ' + $bPullKg + 'kg（' + $bNs + '×' + $bPull + '袋）')
                $zAvailNi[$bNi] = [double]$zAvailNi[$bNi] - $bPullKg
                $zAvail[$cd] -= $bPullKg
                $zHiki += [ordered]@{ 品目コード = $bNi; 品名 = [string]$i.Name; kg = $bPullKg; ケース = 0; 袋 = $bPull; 元 = @($zMoto[$cd]) }
                $sousai += [ordered]@{ 品目 = [string]$i.Name; 相手 = [string]$h.M.Name; 注文 = $line.Trim().TrimStart('・'); 必要kg = [Math]::Round($bNeed * $bKg, 3); 使える在庫kg = [Math]::Round($bAv, 3)
                    結果 = ('倉庫から ' + $bPull + '袋（' + $bPullKg + 'kg）を出す＝仕入先には ' + $hCs + 'c/s → ' + $bNew + 'c/s'); 元 = ((@($zMoto[$cd]) -join '・')); 出どころ = '倉庫在庫.json（荷姿 ' + $bNi + '）'
                    倉庫の中身 = @($jUchi[$cd]) }
                continue
            }   # 倉庫にその品が1kgも無い＝理由も書かない（全品が並ぶと読めなくなる）
            $caseKg = $kgAll / $csAll
            # 2026-09-30 発注ボードの依頼：倉庫に在庫があるのに当てなかったときは、その理由を台帳に書く
            if ($zAvail[$cd] -le 0) { $zNashi += ([string]$i.Name + '：先に始まる催事が倉庫の分を使います'); continue }
            $take = [Math]::Floor([Math]::Round($zAvail[$cd] / $caseKg, 6))   # 2026-10-16 浮動小数点で1ケース落とさない（出した量ちょうどを当て直すため・記憶 float-floor-no-wana）
            # 半ケース未満のかけら（0.1kg など）は書かない＝13行並んで読めなくなる。「あと少しで1ケース」だけ人に見せる
            if ($take -lt 1) { if ($zAvail[$cd] -ge ($caseKg / 2)) { $zNashi += ([string]$i.Name + '：倉庫の残り ' + $zAvail[$cd] + 'kg は1ケース（' + $caseKg + 'kg）に足りません') }; continue }
            # 2026-10-01 引当の照合も **品名 → 本文名** の順で、ひらがな・カタカナを同じものとして見る（数量を直す側と同じ型）。
            #   ここだけ素の Contains のままだったので、本文が「ダルマ（13㎏）」で品名が「手焼きさきいか（ダルマA）」の品に当たらず、
            #   倉庫に65kgあるダルマを**仕入先に頼む側に乗せていた**（316,550円。海藻サラダ・ソフト帆立・羅臼昆布のりも同じ）。
            $hits = @()
            foreach ($nm in @([string]$i.Name, (Hon-Name $i.Code))) {
                if (-not $nm -or $hits.Count) { continue }
                foreach ($x in $mails) {
                    # 2026-10-01 電話メモも引当の相手に入れる。玉井さんの決定＝「**海藻サラダは倉庫の15kgを使う。山市には頼まない**」（10/1・ほかの6品と同じ扱い）。
                    #   それまでは電話メモを外していたので、倉庫に15kgあっても山市へ電話する形のままだった。
                    #   電話メモの行は「・」で始まらないことがあるので、電話メモのときは頭の記号を見ない。
                    if ($x.Kind -eq '倉庫出し' -or -not $x.Body) { continue }
                    $denwa = ($x.Kind -eq '電話メモ')
                    $ls = @($x.Body -split "`r?`n")
                    for ($n = 0; $n -lt $ls.Count; $n++) { if (($denwa -or $ls[$n].Trim().StartsWith('・')) -and (Kana-Same $ls[$n] $nm) -and $ls[$n] -match '(\d+(?:\.\d+)?)\s*c/s') { $hits += [pscustomobject]@{ M = $x; N = $n; Cs = [double]$Matches[1]; Nm = $nm } } }
                }
            }
            if ($hits.Count -ne 1) { $zNashi += ([string]$i.Name + '：本文の行が' + $hits.Count + '件あって、どれか決められません'); continue }
            $h = $hits[0]
            # 2026-10-01 FAXの相手は**差し込み（FaxQty）が正**。本文の数は修正のときに書き換えていないので古いまま残る。
            #   本文の数を信じると、ヒロツクのわさび昆布（差し込み2c/s＝24kg・本文1c/s）を「1c/s しか頼んでいない」と読み、
            #   倉庫から1c/s 取った時点で本文が空になり、**ヒロツクごと候補から落ちて12kgが誰にも頼まれなくなった**（阪神1週目・2週目）。
            $isFax = ($h.M.Kind -eq 'FAX')
            # 差し込みが「数字ひとつ」の相手（ヒロツク）と、「一覧」の相手（セニヤ）で扱いが違う
            $faxHitotsu = ($isFax -and ([string]$h.M.FaxQty).Trim() -match '^\d+(\.\d+)?$')
            $hCs = $h.Cs
            if ($faxHitotsu) { $hCs = [double](([string]$h.M.FaxQty).Trim()) }
            $take = [Math]::Min($take, $hCs)
            # 2026-10-08 もう送った相手の行は、送った数より下へは削らない（倉庫へ回すのは送った数を超えた分だけ）。
            #   由来＝倉庫在庫.json が増えた後の作り直しで、10/3 に送った阪神1週目のセニヤ（いわし 2c/s）を倉庫出しへ移し、⚠送った後に変わった＋倉庫からも出す＝二重になった。
            #   送った中身に無い品（井上の阿川のソフト貝柱）は今までどおり全部倉庫へ回せる。送った中身＝process_budget_files が台帳の「送った時の中身」から渡す
            $sentTxt = $(if ($sentMap.ContainsKey([string]$h.M.Name)) { [string]$sentMap[[string]$h.M.Name] } else { $null })
            if ($null -ne $sentTxt) {
                $sentCs = 0.0
                foreach ($seg in @($sentTxt -split '／')) { if ((Kana-Same $seg $h.Nm) -and $seg -match '(\d+(?:\.\d+)?)\s*c/s') { $sentCs += [double]$Matches[1] } }
                if ($sentCs -gt 0) { $take = [Math]::Min($take, [Math]::Max(0, $hCs - $sentCs)) }
            }
            if ($take -lt 1) { continue }
            $nokoriCs = $hCs - $take; $takeKg = $take * $caseKg
            # 差し込みが一覧のFAXは、**書き換える前に**直す行を見つけておく。見つからなければ本文も触らずに次へ
            #   （先に本文だけ削ってから諦めると、本文と差し込みが食い違ったまま残る）
            $fl = @(); $fi = -1
            if ($isFax -and -not $faxHitotsu) {
                $fl = @(([string]$h.M.FaxQty) -split "`r?`n"); $fa = @()
                foreach ($fn in 0..($fl.Count - 1)) { if ($ngLines.ContainsKey($fl[$fn])) { continue }
                                                     if ((Kana-Same $fl[$fn] ([string]$h.Nm)) -and $fl[$fn] -match '(\d+(?:\.\d+)?)\s*c/s') { $fa += $fn } }
                if ($fa.Count -ne 1) { $zNashi += ([string]$i.Name + '：FAXの差し込みに同じ品の行が' + $fa.Count + '件。倉庫から出さずに仕入先へ頼みます'); continue }
                $fi = $fa[0]
            }
            $ls = @(([string]$h.M.Body) -split "`r?`n"); $line = $ls[$h.N]
            if ($nokoriCs -le 0) { $ls = @($ls | Where-Object { $_ -ne $line }) } else { $ls[$h.N] = ($line -replace '(\d+(?:\.\d+)?)(\s*c/s)', ([string]$nokoriCs + '$2')) }
            $h.M.Body = ($ls -join "`r`n")
            # 2026-10-01 FAXの相手は**差し込み（FaxQty）が本体**。本文だけ削ると、差し込みは元の数のまま残り、
            #   しかも本文から「・」の行が消えて「送らない」になり、**相手ごと候補から落ちる**。
            #   実際に起きた＝阪神1週目・2週目のヒロツク。わさび昆布は各週24kgの指定なのに、倉庫から12kg出す形になり、
            #   残り12kgがどこにも頼まれないまま、ヒロツクの行が候補外に落ちていた（発注ボードの指摘 10/1）。
            if ($faxHitotsu) {
                # 差し込みが数字ひとつだけの相手（ヒロツク）は丸ごと書き換える
                $h.M.FaxQty = $(if ($nokoriCs -le 0) { '' } else { [string]$nokoriCs })
            } elseif ($isFax) {
                # 差し込みが一覧の相手（セニヤ）は**その1行だけ**を直す。丸ごと数字にすると注文が1文字に潰れる（10/1 井上のセニヤを実際に壊した）
                if ($nokoriCs -le 0) { $fl = @($fl | Where-Object { $_ -ne $fl[$fi] }) } else { $fl[$fi] = ($fl[$fi] -replace '(\d+(?:\.\d+)?)(\s*c/s)', ([string]$nokoriCs + '$2')) }
                $h.M.FaxQty = ($fl -join "`r`n")
            }
            $karappo = $(if ($h.M.Kind -eq 'FAX') { -not ([string]$h.M.FaxQty).Trim() } else { -not @($h.M.Body -split "`r?`n" | Where-Object { $_.Trim().StartsWith('・') }).Count })
            if ($karappo) { $h.M.Send = '送らない' }
            # 2026-10-08 倉庫の現物が仕入先の荷姿（13kgの箱）と違う形（1kgの袋）なら、倉庫出しの字を現物の形で書く＝「青山だるま 13kg（1kg×13袋）」。
            #   「ダルマ（13㎏）1c/s」のまま知らせに出ると、熊田さんが無い13kgの箱を探す（6代目ボス 10/8・期限10/13。13kgの箱は出さない決まり＝倉庫から出さない.json K017-01）。
            #   字の形はロット品と同じ「品名 Nkg（1kg×N袋）」（10/6 玉井さん）＝ボードの［倉庫から出した］と出荷の板がそのまま読める。
            #   現物に仕入先と同じ荷姿（13kg）があるときは今までどおり c/s のまま
            $pullLine = ($line.Trim() -replace '(\d+(?:\.\d+)?)(\s*c/s)', ([string]$take + '$2'))
            $ni = @($jNi[$cd] | Where-Object { $_ -and $_.単位kg -gt 0 })
            $sameBox = @($ni | Where-Object { [Math]::Abs($_.単位kg - $caseKg) -lt 0.001 }).Count
            $hasuu = @($ni | Where-Object { $_.単位kg -lt $caseKg -and [string]$_.区分 -match '量り売り' })
            # 2026-10-08 7代目ボス（玉井さん）：実数の「1kg×N」は端数Nkg＝1kgの袋は実在しない。仕入先の箱が倉庫に1つも無く、量り売りの端数だけのときに限り「箱ではなく端数から」と書く。
            #   最終の字（1箱に足す端数の上限）は玉井さんの答え待ち＝答えが出たらここを直す。箱がある品（燻製ホタテヒモ 10kg×4ケース 等）は今までどおり c/s
            if ($ni.Count -and -not $sameBox -and $hasuu.Count -and $hasuu.Count -eq $ni.Count) {
                $small = @($hasuu | Sort-Object 単位kg)[0]
                $kashira = $(if ($line.Trim() -match '^[・･]') { '・' } else { '' })
                $pullLine = ($kashira + $small.品名 + ' ' + $takeKg + 'kg（箱ではなく端数から）')
                # 2026-10-08 玉井さん「1」（3問目・8代目ボス経由・運転の決まり★）：**だるま**の倉庫出し＝端数が13kg以上あれば端数の13kgで1ケース分にする。
                #   残りの端数が13kg未満なら全部を最初の箱に足す（1箱は最大26kg弱）。記録は「13kg×箱の数＋端数kg」。
                #   例＝倉庫の端数22kg → 13kg×1＋端数9kg＝22kg を出す。ほかの品は玉井さんの決まりが出るまで上の字のまま
                if ($cd -eq 'K017') {
                    $amari = [Math]::Round($zAvail[$cd] - $takeKg, 2)
                    if ($amari -gt 0 -and $amari -lt $caseKg) { $takeKg = $takeKg + $amari } else { $amari = 0 }
                    $pullLine = ($kashira + $small.品名 + ' ' + $takeKg + 'kg（' + $caseKg + 'kg×' + $take + $(if ($amari -gt 0) { '＋端数' + $amari + 'kg' } else { '' }) + '）')
                }
            }
            $pull += $pullLine
            $zAvail[$cd] -= $takeKg
            $zHiki += [ordered]@{ 品目コード = $cd; 品名 = [string]$i.Name; kg = $takeKg; ケース = $take; 元 = @($zMoto[$cd]) }
            $sousai += [ordered]@{ 品目 = [string]$i.Name; 相手 = [string]$h.M.Name; 注文 = $line.Trim().TrimStart('・'); 必要kg = ($h.Cs * $caseKg); 使える在庫kg = ($zAvail[$cd] + $takeKg)
                結果 = ('倉庫から出す ' + $take + 'c/s（' + $takeKg + 'kg）＝仕入先には頼まない'); 元 = ((@($zMoto[$cd]) -join '・')); 出どころ = '倉庫在庫.json（催事の最終日の残り）'
                # 2026-10-01 倉庫に実際に何がどの荷姿で置いてあるか。注文の字は**仕入先の荷姿**で書かれているので、
                #   倉庫の現物と形が違うことがある（例＝注文「ダルマ（13㎏）1c/s」／倉庫にあるのは1kgの袋22）。熊田さんが取り違えないように添える。
                倉庫の中身 = @($jUchi[$cd]) }
        }
    }
}
if ($handSouko.Count) { $pull += $handSouko }   # 2026-10-06 人が読む行で頼む先＝倉庫出しのもの（引き当ての記録には入らない＝倉庫の数は人が見る）
if ($pull.Count) {
    $mails += [pscustomobject]@{ Name = '倉庫出し'; To = ''; CC = ''; Body = ($pull -join "`r`n"); Send = '送る'; Subject = '倉庫から出す（ロットの品・催事の残り）'; Kind = '倉庫出し'; Att = ''; FaxQty = '' }
}

# 1b) 中身の要約（ボードの1行に出す）＝本文の「・」で始まる行を「／」でつなぐ。FAXは差し込みの内容
function Get-Summary($x, [bool]$Full = $false) {   # $Full＝切らずに全文を返す（2026-09-27 発注ボードの会話の依頼・画面で品目が切れていた）
    if ($x.Kind -eq 'FAX' -and $x.Att -eq 'ヒロツク') { return 'わさび昆布 ' + $x.FaxQty + 'c/s（発注書PDF）' }
    if ($x.Kind -eq 'FAX' -and $x.FaxQty) { return (($x.FaxQty -split "`r?`n" | Where-Object { $_.Trim() } | ForEach-Object { $_ -replace '\|', ' ' }) -join '／') }
    $lines = @($x.Body -split "`r?`n" | Where-Object { $_.Trim().StartsWith('・') } | ForEach-Object { ($_.Trim().TrimStart('・') -replace '\s+', ' ') })
    if (-not $lines.Count) { return '' }
    $t = $lines -join '／'
    if ($Full) { return $t }
    if ($t.Length -gt 90) { $t = $t.Substring(0, 90) + '…' }
    return $t
}
# 1b2) 2026-10-03 FAXの件名と本文（玉井さん 10/2 夜の決定・熊田さんが 10/2 に直した形に合わせる）
#   ①FAXの件名は「発注書」だけ（ひな形の「発注書 リベルテ本帆様（会場・着日）」は仕入先に長い）
#   ②注文の中身は本文に書き、PDFを付けない。例外＝ヒロツクのように相手のFAX用紙がある相手（Att=ヒロツク）
#   ③PDFを付けない相手は、書き出し「発注書をお送りします（1枚）」を「下記のとおり発注いたします」に言い換える
#   ひな形（商品マスター_クシロー.xlsx の「発注メールの下書き」）は触らない＝ここで決まりとして揃える。汎用PDFを作る関数は消さずに残す
#   【発注ボードとの約束】board_action の verifycopy は本文の「納品希望日：yyyy/m/d」の行と、会場の先頭15字で「送った」を当てる。この2行を本文から消す・書き方を変えるときは発注ボードへ一声
foreach ($x in $mails) {
    if ($x.Kind -ne 'FAX') { continue }
    $x.Subject = '発注書'
    if ($x.Att -ne 'ヒロツク') {
        $x.Att = ''
        $x.Body = $x.Body -replace '発注書をお送りします（1枚）。', '下記のとおり発注いたします。'
    }
}

# 1a''''''''') 頼み直し（2026-10-12 11代目ボスの裁定・マニュアル係 続き6）
#   もう送った相手（全部取り消した相手を含む）に、あらためて頼む品。送った便の本文は直さない（送った事実を書き換えない・取消の記録も残す）。
#   同じ相手の**新しい便**「〈相手〉〈頼み直し〉」を作る。宛先・方法・件名は元の便と同じ。本文は Excel から出たままの元の便の本文から品の行を外し、
#   頼む品の行だけを入れる。品の行の字は元の本文の同じ品の行を借りて数だけ変える（無ければ品目.json の本文の組み立て）。
#   本文の頭に「頼み直し」の一文＝相手に別の注文だと分かる・board_action の verifycopy が元の1通と取り違えない印（この字を消すときは verifycopy も直す）。
#   2026-10-23 24代目ボスの裁定（18:4x）：頭の一文は、その相手に取消の記録（予定の直し＝種別「頼んだ分を減らした」か「これから頼む・ケース0」・取り消した直しは数えない）がある時だけ「（頼み直し）」。
#   取消の記録が無い追加は「（追加）」。verifycopy（board_action.ps1）は「頼み直し」「（追加）」の両方を目印に読む（どちらかの字を変える時は verifycopy も直す）
#   ここ（反映・引当・供給上限の後）で作る＝ほかの段がこの便の数を書き換えない＝確認・窓で決めた数のまま
$yariMarkTorikeshi = '※先日の取消とは別に、あらためて下記をご注文いたします（頼み直し）。'
$yariMarkTsuika = '※先日のご注文に加えて、下記を追加でご注文いたします（追加）。'
foreach ($yg in @($naoshiYari | Group-Object { [string]$_.頼む先 })) {
    $yName = [string]$yg.Name; $base = $yName -replace '〈頼み直し〉$', ''
    $yTorikeshi = @($naoshiLive | Where-Object { $_.行 -and [string]$_.行.頼む先 -eq $base -and ([string]$_.種別 -eq '頼んだ分を減らした' -or ([string]$_.種別 -eq 'これから頼む' -and ([string]$_.行.ケース -match '^\s*0+(\.0+)?\s*$'))) })   # 2026-10-23 その相手の取消の記録
    $yariMark = $(if ($yTorikeshi.Count) { $yariMarkTorikeshi } else { $yariMarkTsuika }); $yariKind = $(if ($yTorikeshi.Count) { '頼み直し' } else { '追加' })
    $bm = @($mails | Where-Object { [string]$_.Name -eq $base }) | Select-Object -First 1
    if (-not $bm -or -not $mailsMoto.ContainsKey($base)) { $naoshiNote += ('頼み直しの元の相手「' + $base + '」が、この催事の発注の相手に無い'); continue }
    if ($bm.Kind -eq 'FAX' -and $bm.Att -eq 'ヒロツク') { $naoshiNote += ('頼み直し：ヒロツクはFAX用紙の数字だけなので、新しい便を組めない＝人が書く（' + $yName + '）'); continue }
    $moto = $mailsMoto[$base]
    $mkLines = {
        param([string]$txt)
        $ls = @($txt -split "`r?`n"); $kashira = ''
        foreach ($l0 in $ls) { if ($l0 -match '(\d+(?:\.\d+)?)\s*c/s' -and $l0 -match '^(\s*[・･\*\-]\s*)') { $kashira = $Matches[1]; break } }
        $out = @(); $ng = @()
        foreach ($p in @($yg.Group)) {
            if ($p.人が読む -eq $true) { if ([string]$p.本文の字) { $out += ($kashira + '※' + [string]$p.本文の字) } else { $ng += '人が読む行に本文の字が無い' }; continue }
            $cd = [string]$p.品目コード; $cs = [string]$p.ケース; $csd = 0.0
            if (-not [double]::TryParse($cs, [ref]$csd) -or $csd -le 0) { continue }
            $it = @(@($items) | Where-Object { (Fix-Key ([string]$_.Code) ([string]$_.Name)) -eq (Fix-Key $cd ([string]$p.商品)) }) | Select-Object -First 1
            if (-not $it) { $it = @(@($items) | Where-Object { [string]$_.Code -eq $cd }) | Select-Object -First 1 }
            $line = ''
            foreach ($nm in @($(if ($it) { Pack-Name $it } else { '' }), $(if ($it) { [string]$it.Name } else { '' }), (Hon-Name $cd), [string]$p.商品)) {
                if (-not $nm -or $line) { continue }
                $h = @($ls | Where-Object { (Kana-Same $_ $nm) -and $_ -match '(\d+(?:\.\d+)?)\s*c/s' })
                if ($h.Count -eq 1) { $line = ($h[0] -replace '(\d+(?:\.\d+)?)(\s*c/s)', ($cs + '$2')) }
            }
            if (-not $line) {
                $ng0 = $nisugata[$cd]
                if ($ng0 -and $ng0.品名 -and $ng0.荷姿 -and [string]$ng0.'1箱の入数') { $line = $kashira + [string]$ng0.品名 + ' ' + [string]$ng0.荷姿 + '（' + [string]$ng0.'1箱の入数' + '袋入） ' + $cs + 'c/s' }
                elseif (Hon-Name $cd) { $line = $kashira + (Hon-Name $cd) + ' ' + $cs + 'c/s' }
            }
            if ($line) { $out += $line } else { $ng += ('本文の行を組めない：' + $cd + ' ' + [string]$p.商品) }
        }
        return @{ Ls = $ls; Out = $out; Ng = $ng }
    }
    $rb = & $mkLines ([string]$moto.Body)
    if ($rb.Ng.Count) { $naoshiNote += @($rb.Ng | ForEach-Object { '頼み直し（' + $yName + '）：' + $_ }); continue }
    if (-not $rb.Out.Count) { $naoshiNote += ('頼み直し（' + $yName + '）：頼む品が1つも無い（ケースが0）'); continue }
    # 本文：品の行（Nc/s の行と ・※ の行）を外し、最初の品の行の所に 頼み直しの一文＋頼む品 を入れる
    $nb = @(); $ireta = $false
    foreach ($l0 in $rb.Ls) {
        $hin = ($l0 -match '(\d+(?:\.\d+)?)\s*c/s') -or ($l0.Trim() -match '^[・･]\s*※')
        if ($hin) { if (-not $ireta) { $nb += $yariMark; $nb += $rb.Out; $ireta = $true }; continue }
        $nb += $l0
    }
    if (-not $ireta) { $nb = @($yariMark) + $rb.Out + $nb }
    $ym = $bm | Select-Object *
    $ym.Name = $yName; $ym.Send = '送る'
    $ym.Body = ($nb -join "`r`n")
    if ($ym.Kind -eq 'FAX') {
        $ym.Body = $ym.Body -replace '発注書をお送りします（1枚）。', '下記のとおり発注いたします。'
        $rf = & $mkLines ([string]$moto.FaxQty)
        $ym.FaxQty = $(if ($rf.Out.Count -and -not $rf.Ng.Count) { ($rf.Out -join "`r`n") } else { ($rb.Out -join "`r`n") })
    }
    $mails += $ym
    foreach ($p in @($yg.Group)) {
        $cd = [string]$p.品目コード; $c4 = $(if ($cd.Length -ge 4) { $cd.Substring(0, 4) } else { $cd })
        $kg = 0.0; [void][double]::TryParse(([string]$p.発注量kg -replace '[^\d\.]', ''), [ref]$kg)
        $it2 = @(@($items) | Where-Object { (Fix-Key ([string]$_.Code) ([string]$_.Name)) -eq (Fix-Key $cd ([string]$p.商品)) }) | Select-Object -First 1   # 学問の大袋/小袋は荷姿（X列）の原価kg
        $nsc = $(if ($nisugata[$cd]) { $cd } elseif ($it2 -and [string]$it2.Nisugata -and $nisugata[[string]$it2.Nisugata]) { [string]$it2.Nisugata } else { '' })
        $tan = 0.0; if ($nsc -and $nisugata[$nsc].原価kg) { $tan = [double]$nisugata[$nsc].原価kg } elseif ($c4 -and $hinMeta.ContainsKey($c4)) { try { $tan = [double]([string]$hinMeta[$c4].原価kg) } catch {} }
        if ($p.人が読む -eq $true -or $kg -le 0) { continue }
        $items += [pscustomobject]@{ Code = $cd; Name = ([string]$p.商品 + '〈頼み直し〉'); Kg = [string]$kg; Cs = [string]$p.ケース; Pay = ([Math]::Round($kg * $tan)).ToString('#,0'); 注意 = ('頼み直し：' + $yName); 直し = $true }
    }
    $naoshiDone += ('頼み直し：' + $yName + ' の新しい便を作った（' + (($rb.Out | ForEach-Object { ([string]$_).Trim() }) -join '／') + '）・頭の文＝' + $yariKind + $(if ($yTorikeshi.Count) { '（取消の記録 ' + [string]$yTorikeshi.Count + '件）' } else { '（取消の記録なし）' }))
}

# 1a'''''''') 予定の直し・種別「もう頼んである（記録だけ）」。下書きは触らない。台帳の品目の量に**足す**（供給上限の合計・画面の品目に効く）。
#   足し算にする理由＝井上の削りたこカマ：倉庫から10kg＋阿川に別で10kg＝20kg（玉井さん 10/7「3」）。仕入先未定で0になった干貝柱は 0＋10＝10kg。
#   ここ（倉庫の引当の後）に置く理由＝足した量で倉庫を余計に引き当てないため
foreach ($kr in @($naoshiKiroku)) {
    $p = $kr.行; $cd = [string]$p.品目コード; $c4 = $(if ($cd.Length -ge 4) { $cd.Substring(0, 4) } else { $cd })
    # 2026-10-08 仕組みの穴23（ボス 18:02）：送った後に熊田さんが相手へ「減らす・外す」を伝えた分は、種別「頼んだ分を減らした」で台帳の量から**引く**（0より下にしない）
    $herasu = ([string]$kr.種別 -eq '頼んだ分を減らした')
    $kg = 0.0; try { $kg = [double](([string]$p.発注量kg) -replace '[^\d\.]', '') } catch {}
    $cs = 0.0; try { $cs = [double](([string]$p.ケース) -replace '[^\d\.]', '') } catch {}
    $dare = (([string]$kr.誰が + ' ' + [string]$kr.いつ).Trim())
    $chu = $(if ($herasu) { '頼んだ分を減らした：' } else { 'もう頼んである：' }) + [string]$p.頼む先 + ' ' + $(if ($p.人が読む -eq $true -and [string]$p.本文の字) { [string]$p.本文の字 } else { [string]$kg + 'kg（' + [string]$cs + 'c/s）' }) + '（' + $dare + '・' + [string]$kr.何をもとに + '）'
    $tan = 0.0; if ($c4 -and $hinMeta.ContainsKey($c4)) { try { $tan = [double]([string]$hinMeta[$c4].原価kg) } catch {} }
    $pay = $(if ($p.支払額) { [double]$p.支払額 } else { [Math]::Round($kg * $tan) })
    $hit = $null
    foreach ($i in $items) { $ic = [string]$i.Code; if ($ic.Length -ge 4) { $ic = $ic.Substring(0, 4) }; if ($c4 -and $ic -eq $c4) { $hit = $i; break } }
    if ($herasu) {
        if (-not $hit) { $naoshiNote += ('減らす品が台帳に無い：' + $cd + '（' + [string]$kr.ファイル + '）'); continue }
        $kg = -$kg; $cs = -$cs; $pay = -$pay
    }
    if ($hit) {
        $oldKg = [double](([string]$hit.Kg) -replace '[^\d\.]', ''); $oldCs = [double](([string]$hit.Cs) -replace '[^\d\.]', ''); $oldPay = [double](([string]$hit.Pay) -replace '[^\d\.]', ''); $comma = ([string]$hit.Pay).Contains(',')
        $hit.Kg = [string][Math]::Max(0.0, $oldKg + $kg); $hit.Cs = [string][Math]::Max(0.0, $oldCs + $cs); $hit.Pay = ([Math]::Max(0.0, $oldPay + $pay)).ToString('#,0')
        $hit | Add-Member -NotePropertyName 注意 -NotePropertyValue ((@([string]$hit.注意, $chu) | Where-Object { $_ }) -join '／') -Force
        $hit | Add-Member -NotePropertyName 直し -NotePropertyValue $true -Force
        $naoshiDone += ($c4 + ' ' + [string]$hit.Name + '：' + $oldKg + 'kg → ' + [Math]::Max(0.0, $oldKg + $kg) + 'kg（' + $chu + '）')
    } else {
        $nm = $(if ([string]$p.商品) { [string]$p.商品 } elseif ($c4 -and $hinMeta.ContainsKey($c4)) { [string]$hinMeta[$c4].品名 } else { $cd })
        $items += [pscustomobject]@{ Code = $cd; Name = $nm; Kg = [string]$kg; Cs = [string]$cs; Pay = $pay.ToString('#,0'); 注意 = $chu; 直し = $true }
        $naoshiDone += ($cd + ' ' + $nm + '：台帳に足した（' + $chu + '）')
    }
}
$naoshiState = $(if ($naoshiNote.Count) { '反映できない' } elseif (@($naoshiLive).Count) { '反映した' } else { '無し' })
$naoshiOut = [ordered]@{ 状態 = $naoshiState; 直した = @($naoshiDone); できない理由 = @($naoshiNote); 取り消した = @($naoshiCancelled)
    一覧 = @($naoshiLive | ForEach-Object { [ordered]@{ ファイル = [string]$_.ファイル; 種別 = [string]$_.種別; 行 = $_.行; 何をもとに = [string]$_.何をもとに; メモ = [string]$_.メモ; 誰が = [string]$_.誰が; PC = [string]$_.PC; いつ = [string]$_.いつ } }) }

# 1c) 送信候補の群を JSON に書く（台帳の元）
if ($CandidatesPath) {
    $cands = @()
    foreach ($x in $mails) {
        # 2026-09-30 発注ボードの指摘：空の $( if ) は JSON で {} になり、受け取り側で「空の辞書1個」の配列になる。変数に入れてから渡す
        $hikiate = @(); if ($x.Kind -eq '倉庫出し') { $hikiate = @($zHiki | Where-Object { $_ -and $_.品目コード }) }
        $cands += [ordered]@{
            相手 = $x.Name; 方法 = $x.Kind; 送るか = $x.Send; 中身 = (Get-Summary $x); 中身全文 = (Get-Summary $x $true)   # 2026-09-27 画面で品目が切れていた（91文字で「…」）。切る前の全文も渡す（発注ボードの会話の依頼）
            宛先 = $(if ($x.Kind -eq '電話メモ') { $Account } else { $x.To }); CC = $x.CC; 件名 = $x.Subject; 本文 = $x.Body; 添付の型 = $x.Att; FAXの内容 = $x.FaxQty
            引き当て = $hikiate   # 2026-09-30 催事の残りから当てた分（ほかの発注案が二重に当てないための印）
            箱の注 = @(@($x.箱の注) | Where-Object { $_ })   # 2026-10-23 r9：箱で割り切れない袋数の注（PBF が送る前に確認にする）
        }
    }
    # 2026-10-08 品目.json の「地域別原価kg」（北冷蔵のダルマ K017＝北海道4,800・関西4,870・それ以外4,900）。届け先の住所で単価を選び、支払額を kg×単価 で出し直す。
    #   値は商品マスターの持ち場（こちらは読むだけ）。住所で地域が分からないときは「それ以外」（高い方）。予定の直しで足した量も含めて最後に1回だけ掛ける
    #   見るのは住所の都道府県だけ（会場名は見ない＝「阪神の北海道展」「冬の大北海道展」を北海道と読み違えた・10/8 作り直しで発見）
    #   2026-10-08 23:36 商品マスターが11地域に（北冷蔵の見積もり表）＝住所の頭の都道府県を「都道府県→地域」で地域に直してから単価を引く。
    #   都道府県の無い住所（「大阪市福島区…」）は政令市の名前から都道府県を補う。どれにも当たらなければ「それ以外」（高い方）
    $ken = ([string]$Address -replace '^\s*〒?\s*[\d\-－‐]+\s*', '').Trim()
    $pref = ''
    if ($ken -match '^(北海道|東京都|京都府|大阪府|.{2,3}県)') { $pref = $Matches[1] }
    else {
        $shi = [ordered]@{ '札幌市' = '北海道'; '仙台市' = '宮城県'; 'さいたま市' = '埼玉県'; '千葉市' = '千葉県'; '横浜市' = '神奈川県'; '川崎市' = '神奈川県'; '相模原市' = '神奈川県'; '新潟市' = '新潟県'; '静岡市' = '静岡県'; '浜松市' = '静岡県'; '名古屋市' = '愛知県'; '京都市' = '京都府'; '大阪市' = '大阪府'; '堺市' = '大阪府'; '神戸市' = '兵庫県'; '岡山市' = '岡山県'; '広島市' = '広島県'; '北九州市' = '福岡県'; '福岡市' = '福岡県'; '熊本市' = '熊本県' }
        foreach ($k in $shi.Keys) { if ($ken.StartsWith($k)) { $pref = $shi[$k]; break } }
    }
    foreach ($i in $items) {
        $c4 = [string]$i.Code; if ($c4.Length -ge 4) { $c4 = $c4.Substring(0, 4) }
        if (-not $hinMeta.ContainsKey($c4) -or -not $hinMeta[$c4].地域別原価kg) { continue }
        $tbl = $hinMeta[$c4].地域別原価kg; $chiiki = 'それ以外'
        if ($pref -and $tbl.'都道府県→地域' -and $tbl.'都道府県→地域'.$pref) { $chiiki = [string]$tbl.'都道府県→地域'.$pref }
        elseif ($pref -eq '北海道') { $chiiki = '北海道' }
        $tanC = 0.0; try { $tanC = [double]([string]$tbl.$chiiki) } catch {}
        $kgC = 0.0; try { $kgC = [double](([string]$i.Kg) -replace '[^\d\.]', '') } catch {}
        if ($tanC -le 0 -or $kgC -le 0) { continue }
        $i.Pay = ([Math]::Round($kgC * $tanC)).ToString('#,0')
        $i | Add-Member -NotePropertyName 単価の地域 -NotePropertyValue ($chiiki + ' ' + $tanC.ToString('#,0') + '円/kg') -Force
    }
    $doc = [ordered]@{ 作成 = (Get-Date -Format 'yyyy-MM-dd HH:mm'); 倉庫の相殺 = @($sousai); 案件ID = $CaseId; 印 = $Label; 売上予算 = $Budget; 型 = $Type; 営業日数 = $Days
        納品希望日 = $DeliveryDate; 住所 = $Address; 会場 = $Venue; 宛名 = $Attn; TEL = $Tel
        マネキン人数 = $(if ($mq.Count) { [ordered]@{ 一日の売上 = $mq.Day; 一週目 = $mq.W1; 二週目 = $mq.W2 } } else { $null })
        # 2026-10-01 発注量0でも「注意」が付いた行は残す（割り振り0の品を黙って消さない・商品マスターの依頼）
        品目 = @($items | Where-Object { ($_.Kg -and $_.Kg -ne '0') -or $_.注意 } | ForEach-Object { [ordered]@{ 品目コード = $_.Code; 商品 = $_.Name; 発注量kg = $_.Kg; ケース = $_.Cs; 単位 = $(if ([string]$_.Tani -eq '袋') { '袋' } else { 'c/s' }); 支払額 = $_.Pay; 注意 = [string]$_.注意; 確認時のkg = [string]$_.確認時のkg } })   # 2026-10-19 確認時のkg＝18代目ボス②
        数量限定の反映 = @($genteiDone)
        掛け率 = @($kake)
        修正の反映 = [ordered]@{ 状態 = $fixState; 直した品目 = @($fixDone); できない理由 = @($fixNote); 文字の注文 = @($mojiChumon) }   # 2026-09-30 台帳の 下書き可 はこれを見る。2026-10-29 13枚目 文字の注文
        予定の直し = $naoshiOut   # 2026-10-07 鍵を持つ人が窓で直した分（台帳と画面が読む）
        引き当てなしの理由 = @($zNashi)   # 2026-09-30 発注ボードの依頼。倉庫に在庫があるのに当てなかった品だけ
        候補 = $cands }
    [IO.File]::WriteAllText($CandidatesPath, ($doc | ConvertTo-Json -Depth 6), $utf8bom)
    "候補: $CandidatesPath（$($cands.Count)件）"
}
# 担当者の修正を反映できていないのに下書きを作ろうとしたら、ここで止める（台帳の 下書き可＝false と二重の歯止め）
# 2026-10-31 草案 項目5：確かめ待ちも下書きを作らない
if (($fixState -eq '反映できない' -or $fixState -like '確かめ待ち*') -and -not $NoDrafts) { throw ('担当者の修正を反映できないので下書きは作りません：' + (($fixNote | Select-Object -First 3) -join '／')) }
if ($naoshiState -eq '反映できない' -and -not $NoDrafts) { throw ('予定の直しを反映できないので下書きは作りません：' + (($naoshiNote | Select-Object -First 3) -join '／')) }   # 2026-10-07

# 2) FAX の発注書 PDF（ヒロツク）
function New-HirotsukuPdf([string]$qty) {
    $src = Join-Path $PSScriptRoot '型\ヒロツク_発注書.xls'
    $x = Join-Path $env:TEMP ('hiro_' + $stamp + '.xls')
    # 2026-10-07 ヒロツクは本文を付けない（玉井さん）。送ったかの自動の確かめ（board_action verifycopy）は写しの「納品日＋会場」を探すので、
    #   ファイル名に入れて添付の名前で当たるようにする（日付は / が使えないので - ・会場は空白と使えない字を落として15字）
    $vfn = (([string]$Venue) -replace '[\s\\/:\*\?"<>\|]', ''); if ($vfn.Length -gt 15) { $vfn = $vfn.Substring(0, 15) }
    $dfn = ''; try { $dfn = ([datetime]$DeliveryDate).ToString('yyyy-MM-dd') } catch {}
    $pdf = Join-Path $env:TEMP ('発注書_ヒロツク_' + $dfn + '_' + $vfn + '_' + $stamp + '.pdf')
    Copy-Item $src $x -Force
    $e = New-Object -ComObject Excel.Application; $e.DisplayAlerts = $false
    try {
        $b = $e.Workbooks.Open($x); $w = $b.Worksheets.Item('合格様')
        $w.Range('G1').NumberFormat = '@'; $w.Range('G1').Value2 = (Get-Date -Format 'yyyy年M月d日')
        # 熊田さんの型：納品先はB5の枠、納品希望日はG6の枠に書く（印刷範囲の外の枠は過去の控え＝触らない）
        $boxAddr = $null; $boxDate = $null
        foreach ($sh in $w.Shapes) {
            if ($sh.Type -ne 17) { continue }
            $cell = $sh.TopLeftCell.Address()
            if ($cell -eq '$B$5') { $boxAddr = $sh }
            if ($cell -eq '$G$6') { $boxDate = $sh }
        }
        if (-not $boxAddr -or -not $boxDate) { throw 'ヒロツクの型に納品先（B5）・納品希望日（G6）の枠が見つかりません' }
        $boxAddr.TextFrame2.TextRange.Text = $Address + "`r" + $Venue + "`r" + $Attn + "`r" + 'TEL:' + $Tel
        $boxDate.TextFrame2.TextRange.Text = '納品希望日　: ' + $DeliveryDate
        $w.Range('F11').Value2 = $qty + 'c/s'
        $w.Range('F13').Value2 = ''          # しそ味ひじきはユタカ食品で発注＝ここは空（二重発注防止）
        $w.ExportAsFixedFormat(0, $pdf)
        $b.Close($false)
    } finally { $e.Quit(); [void][Runtime.InteropServices.Marshal]::ReleaseComObject($e); Remove-Item $x -Force -ErrorAction SilentlyContinue }
    return $pdf
}

# 2b) 汎用の FAX 発注書 PDF（セニヤほか）。$list＝「品名|数量」を改行で並べたもの
function New-GenericFaxPdf([string]$name, [string]$atena, [string]$faxTo, [string]$list) {
    $src = Join-Path $PSScriptRoot '型\汎用_FAX発注書.xlsx'
    $x = Join-Path $env:TEMP ('fax_' + $stamp + '.xlsx')
    $pdf = Join-Path $env:TEMP ('発注書_' + $name + '_' + (Get-Date -Format 'yyyyMMdd') + '_' + $stamp + '.pdf')
    Copy-Item $src $x -Force
    $e = New-Object -ComObject Excel.Application; $e.DisplayAlerts = $false
    try {
        $b = $e.Workbooks.Open($x); $w = $b.Worksheets.Item(1)
        $w.Range('D1').NumberFormat = '@'; $w.Range('D1').Value2 = (Get-Date -Format 'yyyy年M月d日')
        $w.Range('B3').Value2 = $atena
        $num = ($faxTo -replace '@.*$', '') -replace '^81', '0'
        $w.Range('B4').NumberFormat = '@'; $w.Range('B4').Value2 = $num
        $w.Range('B9').Value2 = $Address; $w.Range('B10').Value2 = $Venue; $w.Range('B11').Value2 = $Attn; $w.Range('B12').Value2 = 'TEL ' + $Tel
        $w.Range('B13').NumberFormat = '@'; $w.Range('B13').Value2 = [string]$DeliveryDate
        $row = 16
        foreach ($ln in ($list -split "`r?`n")) {
            if (-not $ln.Trim()) { continue }
            $p = $ln.Split('|')
            $w.Cells.Item($row, 2).Value2 = $p[0]; $w.Cells.Item($row, 3).Value2 = $(if ($p.Count -gt 1) { $p[1] } else { '' })
            $row++
        }
        $w.PageSetup.Zoom = $false; $w.PageSetup.FitToPagesWide = 1; $w.PageSetup.FitToPagesTall = 1
        $w.ExportAsFixedFormat(0, $pdf)
        $b.Close($false)
    } finally { $e.Quit(); [void][Runtime.InteropServices.Marshal]::ReleaseComObject($e); Remove-Item $x -Force -ErrorAction SilentlyContinue }
    return $pdf
}

# 2c) 下書きの置き場＝「下書き」の中のサブフォルダ（無ければ作る）。既定の「下書き」には置かない
function Get-DraftBox($acct, [string]$sub) {
    $d = $acct.DeliveryStore.GetDefaultFolder(16)
    if (-not $sub) { return $d }
    foreach ($f in $d.Folders) { if ($f.Name -eq $sub) { return $f } }
    return $d.Folders.Add($sub)
}

# 3) Outlook の下書き
$made = @()
if (-not $NoDrafts) {
    $ol = New-Object -ComObject Outlook.Application
    $ns = $ol.GetNamespace('MAPI')
    $acct = $null
    foreach ($a in $ns.Accounts) { if ($a.SmtpAddress -eq $Account) { $acct = $a } }
    if (-not $acct) { throw "Outlook にアカウント $Account がありません" }
    $drafts = Get-DraftBox $acct $DraftFolder
    # FAX は eFax に登録された送信元（info@gokaku.company）の下書きに作る（熊田さん 9/18：kumada@ は未登録）
    $faxDrafts = $null; $faxWarn = ''; $faxAcct = $null
    foreach ($a in $ns.Accounts) { if ($a.SmtpAddress -eq $FaxAccount) { $faxAcct = $a; $faxDrafts = Get-DraftBox $a $DraftFolder } }
    # 2026-09-21 熊田さんのPCでは info@ の配信先ストアが kumada@ のストアなので、置き場だけでは送信元が kumada@ になる → 送信元アカウントを明示する
    if (-not $faxDrafts) { $faxDrafts = $drafts; $faxWarn = '【eFax送信元でない・info@から送る】' }
    $mark = $(if ($Label) { '[発注] ' + $Label + '｜' } else { '' })
    foreach ($x in $mails) {
        if ($Only -and $x.Name -ne $Only) { continue }
        if ($x.Send -ne '送る') { "スキップ（発注0）: $($x.Name)"; continue }
        $to = $x.To
        if ($x.Kind -eq '電話メモ') { $to = $Account }
        if (-not $to) { "スキップ（宛先なし）: $($x.Name)"; continue }
        $box = $(if ($x.Kind -eq 'FAX') { $faxDrafts } else { $drafts })
        $mail = $box.Items.Add(0)
        $mail.To = $to
        # 2026-10-03 玉井さん「必ず CC に info@ が入っている状況を作る」。送った確認（board_action -Action verifycopy）は、
        #   倉庫メインPCの info@ に届くこの写しで行う。ひな形の CC 欄に頼らず、メール・FAX・新木さんあては必ず足す（重なりは1つにする）
        $ccList = @(([string]$x.CC) -split '[;,]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        if ($x.Kind -in @('メール', 'FAX', '新木さん')) { $ccList = @($ccList | Where-Object { $_ -ine 'info@gokaku.company' }) + @('info@gokaku.company') }
        $ccSeen = @{}; $ccList = @($ccList | Where-Object { $k0 = $_.ToLower(); if ($ccSeen.ContainsKey($k0)) { $false } else { $ccSeen[$k0] = $true; $true } })
        if ($ccList.Count) { $mail.CC = ($ccList -join '; ') }
        # 送信元アカウント：FAX＝eFax登録の info@／それ以外＝熊田さん。PowerShell では「$mail.SendUsingAccount = …」が黙って無視されるので InvokeMember で設定する（2026-09-21 実測）
        $sendAs = $(if ($x.Kind -eq 'FAX' -and $faxAcct) { $faxAcct } else { $acct })
        [void]$mail.GetType().InvokeMember('SendUsingAccount', 'SetProperty', $null, $mail, @($sendAs))
        $mail.Subject =$(if ($Test) { '【試験】' } else { '' }) + $(if ($x.Kind -eq 'FAX') { $faxWarn } else { '' }) + $mark + $(if ($mark) { $x.Name + ' ' } else { '' }) + $x.Subject
        $bodyText = ($x.Body -replace "`r?`n", "`r`n")
        if ($x.Kind -in @('メール', '新木さん', 'FAX')) { $bodyText += ($sig -replace "`r?`n", "`r`n") }
        # 2026-10-07 玉井さん：ヒロツクは決まった様式（発注書PDF）で送るので、それだけでいい＝本文は付けない
        if ($x.Kind -eq 'FAX' -and $x.Att -eq 'ヒロツク') { $bodyText = '' }
        $mail.Body = $bodyText
        if ($x.Kind -eq 'FAX' -and $x.Att -eq 'ヒロツク') {
            $pdf = New-HirotsukuPdf $x.FaxQty
            [void]$mail.Attachments.Add($pdf)
        }
        if ($x.Kind -eq 'FAX' -and $x.Att -eq '汎用') {
            $atena = ($x.Body -split "`r?`n")[0]
            $pdf = New-GenericFaxPdf $x.Name $atena $to $x.FaxQty
            [void]$mail.Attachments.Add($pdf)
        }
        # 機械の照合用の印（件名は人が変えても、これは残る）
        if ($CaseId) {
            $p1 = $mail.UserProperties.Add('発注案件ID', 1); $p1.Value = $CaseId
            $p2 = $mail.UserProperties.Add('発注相手', 1); $p2.Value = $x.Name
        }
        $mail.Save()
        # Outlook の癖：新しいメールは Save() で必ず既定の「下書き」に入る → サブフォルダへ移す（EntryID が変わるので移した後のものを報告する）
        if ($box.EntryID -ne $box.Store.GetDefaultFolder(16).EntryID) { $mail = $mail.Move($box) }
        # 2026-09-27 「作りかけの印」（発注ボードの会話との取り決め）。Display() で時間切れになると、下書きは1通あるのに台帳は「まだ」＝もう一度押すと2通目。
        #   ここで印を1つ置き、board_action が draft の最初に見て「新しく作らず、その下書きを開くだけ」にする。台帳には触らない（台帳を書くのは board_action だけ）。
        if ($CaseId) {
            try {
                $wipDir = Join-Path (Split-Path $PSScriptRoot -Parent) '発注案\_作りかけ'
                New-Item -ItemType Directory -Force $wipDir | Out-Null
                $wipName = ($CaseId + '_' + $x.Name) -replace '[\\/:*?"<>|\s]', '_'
                $wipTmp = Join-Path $wipDir ($wipName + '.tmp')
                $wip = Join-Path $wipDir ($wipName + '.json')
                [IO.File]::WriteAllText($wipTmp, ([ordered]@{ 案件ID = $CaseId; 相手 = $x.Name; EntryID = $mail.EntryID; StoreID = $box.StoreID; 件名 = $mail.Subject; 作った日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') } | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding $true))
                Move-Item $wipTmp $wip -Force
            } catch {}
        }
        if ($Open) { $mail.Display() }
        $made += "$($x.Kind)：$($x.Name) → $to"
        "下書き作成: [$($x.Kind)] $($x.Name) | To $to | $($mail.Subject)"
        "DRAFT`t$($x.Name)`t$($mail.EntryID)`t$($box.StoreID)`t$($mail.Subject)"
    }
}

# 4) 発注案（現場ごとの記録・人が読む）
if ($PlanPath) {
    $L = @()
    $L += "発注案｜$Brand｜$Venue"
    $L += "作成：$(Get-Date -Format 'yyyy-MM-dd HH:mm')　売上予算：$('{0:N0}' -f $Budget)円　型：$Type　営業日数：$Days"
    $L += "納品希望日：$DeliveryDate（要確認）　納品先：$Address $Venue $Attn TEL $Tel"
    if ($mq.Count) { $L += "マネキン人数（2026-05-19 玉井さんの基準）：1日の売上 $($mq.Day)円 → 1週目 $($mq.W1)人／2週目 $($mq.W2)人" }
    $L += ''
    $L += "品目コード`t商品`t発注量(kg)`tケース`t支払額(税抜)"
    foreach ($i in $items) { if ($i.Kg -and $i.Kg -ne '0') { $L += "$($i.Code)`t$($i.Name)`t$($i.Kg)`t$($i.Cs)`t$($i.Pay)" } }
    $L += ''
    $L += '下書き：'
    if ($made.Count) { $L += $made } else { $L += '（この回では作っていない。送った／残りは発注ボードの台帳 ' + $CaseId + '.json を見る）' }
    $L += '※小島食品・山一食品・ティアイ商事（原料）はセニヤの在庫の補充なので、催事ごとの下書きは作らない。FAXの下書きは info@gokaku.company に作る。'
    [IO.File]::WriteAllLines($PlanPath, $L, $utf8bom)
    "発注案: $PlanPath"
}
