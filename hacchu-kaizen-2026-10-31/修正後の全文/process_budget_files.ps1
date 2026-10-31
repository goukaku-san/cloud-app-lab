# つなぎ：AIかおりが置く「予算と型」のファイル → 送信候補の群（台帳）＋ 発注案（現場ごとの記録）。下書きは作らない（発注ボードで押したとき1通だけ）。送信は絶対にしない。
# 第2版 2026-09-18 蔵人（統合設計の会話・倉庫メインPC）。熊田さんのPCで、毎朝 7:30 の書き出しの後、または発注ボードの［今すぐ更新］で動かす。
# 使い方：& '<このフォルダ>\process_budget_files.ps1'            … 新しい・変わったファイルだけ処理
#         -Test（台帳の指紋を更新しない・毎回処理） -InDir（読む場所を変える） -Account（電話メモの宛先＝熊田さんのアドレス） -All（全部作り直す）
# 台帳：…\発注\発注案\〈案件ID〉.json（状態の正本。書くのはこのファイルと board_action.ps1 だけ）
param(
    [string]$InDir = '',
    [string]$Account = 'kumada@gokaku.company',
    [switch]$All,
    [switch]$Test
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent                 # …\株式会社合格\発注
if (-not $InDir) { $InDir = Join-Path $root '予算と型' }
$planDir = Join-Path $root '発注案'
try { New-Item -ItemType Directory -Force $planDir | Out-Null } catch { throw ('発注案のフォルダが作れません（Gドライブが見えていない？）：' + $planDir) }
$utf8bom = New-Object Text.UTF8Encoding $true
$venues = (Get-Content (Join-Path $PSScriptRoot '納品先.json') -Raw -Encoding UTF8 | ConvertFrom-Json).納品先
function Norm([string]$s) { return ($s -replace '[\s　]', '' -replace '百貨店', '' -replace '髙', '高' -replace '（.*?）|\(.*?\)', '') }
function Find-Venue([string]$name) {
    $n = Norm $name
    foreach ($v in $venues) {
        $keys = @($v.納品先) + @($v.別名)
        foreach ($k in $keys) { $kn = Norm $k; if ($kn -and ($n.Contains($kn) -or $kn.Contains($n))) { return $v } }
    }
    return $null
}
function Short-Venue([string]$name) { return ((Norm $name) -replace '店$', '') }
$engine = Join-Path $PSScriptRoot 'make_order_drafts.ps1'
$staffTel = @{}
$sf = Join-Path $PSScriptRoot '担当者.json'
if (Test-Path $sf) { (Get-Content $sf -Raw -Encoding UTF8 | ConvertFrom-Json).担当者.PSObject.Properties | ForEach-Object { $staffTel[$_.Name] = $_.Value } }
$DONE = @('送った', '電話した', '不要', '倉庫から出した', '現場が発注済み')   # 2026-09-23 「現場が発注済み」＝担当者がLINEで直接頼み、熊田さんの「発注完了」が返っている分（二重発注を止める）
# 2026-09-23 現場の発注（発注案\_LINEで発注済み.json・発注ボードの会話の line_hacchu_import.py が書く）。
#   使うのは「発注が動いたかどうか」の判定だけ。数量は使わない（まとめ＝二次情報のため。数量はLINEの原文で確かめる）
$genba = @()
$genbaPath = Join-Path $planDir '_LINEで発注済み.json'
$naoshiDir = Join-Path $planDir '予定の直し'   # 2026-10-07 鍵を持つ人が窓で直した行（1直し＝1ファイル）。玉井さん「発注の予定＝鍵のかかった箱」
New-Item -ItemType Directory -Force $naoshiDir | Out-Null
# 2026-10-23 穴A（24代目ボスの裁定）：熊田さんが「確かめること」で押した［メールの数］［発注ボードの数］（board_action lineok・鍵「送った中身|〈案件ID〉|〈相手〉|メール／ボード」）を読む。書き手は board_action・読み手はここだけ
# 2026-10-31 草案（発注チェーンの点検・本番未投入） 項目3：入口のファイルが「無い」と「読めない」を分ける。0バイト・欄が無い・JSON が壊れている＝読めない。
#   読めない回は台帳を1つも書き換えない（下の $yosanFiles を空にする）。空として続けると、完了の戻し・「LINEで報告あり」の印の消え・指紋の変化による作り直しが全部の台帳に起きる
. (Join-Path $PSScriptRoot 'genba_hantei.ps1')
$nyuuguchiNG = @()
function Read-Nyuuguchi([string]$path, [string]$ran) {
    if (-not (Test-Path $path)) { return @{ ok = $true; aru = $false; v = @() } }
    try { $o = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return @{ ok = $false; aru = $true; v = @() } }
    if ($null -eq $o -or -not (@($o.PSObject.Properties.Name) -contains $ran)) { return @{ ok = $false; aru = $true; v = @() } }
    return @{ ok = $true; aru = $true; v = @($o.$ran) }
}
$lokP = Join-Path $planDir '_LINE依頼の確認済み.json'
$rk = Read-Nyuuguchi $lokP '確認済み'; if (-not $rk.ok) { $nyuuguchiNG += '_LINE依頼の確認済み.json' }
$lineOkKeysPBF = @($rk.v | Where-Object { $_ } | ForEach-Object { [string]$_.鍵 })
$rg = Read-Nyuuguchi $genbaPath '発注完了'; if (-not $rg.ok) { $nyuuguchiNG += '_LINEで発注済み.json' }
$genba = @($rg.v | Where-Object { $_ })
function Norm-Venue([string]$s) { return ([string]$s -replace '[\s　㈱株式会社（）\(\)]', '') }
# 2026-09-28 1タップ（本人が押した事実）。まとめ（推測）より優先する。ファイルが無ければ今までどおり推測だけで判定する
$ittap = @()
$ittapPath = Join-Path $planDir '_LINEで1タップ.json'
$ri = Read-Nyuuguchi $ittapPath '行'; if (-not $ri.ok) { $nyuuguchiNG += '_LINEで1タップ.json' }   # 2026-10-31 草案（発注チェーンの点検・本番未投入） 項目3
$ittap = @($ri.v | Where-Object { $_ })
function Ittap-Done([string]$id, [string]$venue, [string]$naka, [string]$aite = '') {
    $v = Norm-Venue $venue
    foreach ($t in $ittap) {
        if ([string]$t.種別 -ne '発注完了') { continue }
        # 2026-10-08 熊田さん専用メニューの［発注完了を付ける］（AIかおり fork 11）は相手ごとに押す＝相手の欄があれば、その相手の行にだけ当てる（同じ品名の別の相手に当てない）
        if ([string]$t.相手 -and $aite -and [string]$t.相手 -ne $aite) { continue }
        $same = $false
        if ($t.案件ID -and [string]$t.案件ID -eq $id) { $same = $true }
        # 2026-10-18 玉井さん「すすめて」（発注ボードの会話・追37）：催事番号のある1タップは、その催事にだけ当てる。会場名で当てるのは番号の無い1タップだけ
        #   （10/15 10:40 の阪神1週目の発注完了が、同じ会場の 12/9・2/4・2/16 の北冷蔵ダルマ15c/s×3行まで「現場が発注済み」にしていた）
        elseif (-not [string]$t.案件ID -and $t.会場) { $tv = Norm-Venue ([string]$t.会場); if ($tv -and ($v.Contains($tv) -or $tv.Contains($v))) { $same = $true } }
        if (-not $same) { continue }
        $body = ([string]$t.もとの発言 -replace '[【】（）\(\)○◎●・※\s　]', '')
        foreach ($part in ([string]$naka -split '／')) {
            $core = (([string]$part -replace '[【】（）\(\)○◎●・※\s　]', '') -split '[0-9０-９]')[0]
            if ($core.Length -ge 3 -and $body.Contains($core)) {
                # 2026-09-28 決め方で言葉を分ける。ボタン＝本人が押した事実／本文から読み取り＝押されていない（強い推測）
                $kime = [string]$(if ($t.決め方) { $t.決め方 } else { 'ボタン' })
                $atama = $(if ($kime -eq 'ボタン') { '現場が発注済み（本人が押しました ' } else { '現場が発注済み（本人の発言から読み取り・押されていません ' })
                return ($atama + [string]$t.日時 + '・' + [string]$t.だれが + '）')
            }
        }
    }
    return $null
}
# 2026-10-23 24代目ボスの裁定（井上アイシティ 10/23・14枚目 b6〈ハンコ済〉の型をそのまま当てる・新しい決まりは作らない）：
#   熊田さん（合格）が LINE に「アイシティ井上 本日発送します」等と書いた分（1タップの種別「倉庫から出した」・本文から読み取り）は、倉庫出しの行に「LINEで報告あり」の**印**として出すだけ。
#   機械は「倉庫から出した」にしない（出した事実の確定は熊田さんの［倉庫から出した］か熊田さんの答え＝10/15 裁定「持ち出しは持ち出した本人が確定・品×出来事ごと」。LINE の文に品名が無い）。
#   案件IDのある記録はその催事だけ・無い記録は会場名で（追37）。毎回の作り直しで作り直す＝1タップの記録が消えれば印も消える
function Ittap-SoukoHoukoku([string]$id, [string]$venue) {
    $v = Norm-Venue $venue; $o = @()
    foreach ($t in $ittap) {
        if ([string]$t.種別 -ne '倉庫から出した') { continue }
        $same = $false
        if ($t.案件ID -and [string]$t.案件ID -eq $id) { $same = $true }
        elseif (-not [string]$t.案件ID -and $t.会場) { $tv = Norm-Venue ([string]$t.会場); if ($tv -and $v -and ($v.Contains($tv) -or $tv.Contains($v))) { $same = $true } }
        if (-not $same) { continue }
        $kime = [string]$(if ($t.決め方) { $t.決め方 } else { 'ボタン' })
        $o += ([string]$t.日時 + ' ' + [string]$t.だれが + $(if ($kime -eq 'ボタン') { '（押した）' } else { '（本文から読み取り・押されていません）' }) + $(if ([string]$t.もとの発言) { '「' + ([string]$t.もとの発言).Trim() + '」' } else { '' }))
    }
    if ($o.Count) { return ($o -join '／') } else { return $null }
}
function Genba-Done([string]$venue, [string]$naka, [string]$id = '') {
    # 会場が一致する「発注完了」の本文に、この候補の品目名が出ていれば、現場で発注済みとみなす
    $v = Norm-Venue $venue
    if (-not $v) { return $null }
    foreach ($g in $genba) {
        # 2026-10-19 18代目ボス④（追37 と同じ型・玉井さん 10/18）：案件IDのある「発注完了」はその催事にだけ当てる。会場名で当てるのは番号の無い記録だけ
        if ([string]$g.案件ID) { if ([string]$g.案件ID -ne $id) { continue } }
        else {
            $gv = Norm-Venue ([string]$g.会場)
            if (-not $gv) { continue }
            if (-not ($v.Contains($gv) -or $gv.Contains($v))) { continue }
        }
        # 2026-09-24 熊田さんの「発注完了」は「@氷下魚 岡山高島屋 ／ 発注完了。」の形で品名が入らないのが普通。
        #   発注ボードの会話が、完了の本文＋直前の同じ会場の依頼（品名が並ぶ投稿）をつないだ「照合用」を足したので、あればそちらで見る（数量は使わない）
        $honbun = $(if ($g.照合用) { [string]$g.照合用 } else { [string]$g.本文 })
        # 2026-09-24 記号と空白を落とし、数字より前で切ってから比べる。【道南冷蔵】ホタテ焼貝ひも5kx2 と ○道南冷蔵ホタテ焼貝ひも10kx2 が当たるように（発注ボードの会話の検算）
        $bodyC = ([string]$honbun -replace '[【】（）\(\)○◎●・※\s　]', '')
        foreach ($part in ([string]$naka -split '／')) {
            $core = (([string]$part -replace '[【】（）\(\)○◎●・※\s　]', '') -split '[0-9０-９]')[0]
            if ($core.Length -ge 3 -and $bodyC.Contains($core)) { return ('現場が発注済み（LINE ' + [string]$g.日時 + '・' + [string]$g.だれが + '）') }
        }
    }
    return $null
}
# 送る日＝納品日−仕入先ごとの日数（送る日の日数.json・2026-09-21）
$lead = Get-Content (Join-Path $PSScriptRoot '送る日の日数.json') -Raw -Encoding UTF8 | ConvertFrom-Json
function Lead-Days([string]$aite) {
    foreach ($p in $lead.日数.PSObject.Properties) { if ($aite.StartsWith($p.Name)) { return [int]$p.Value } }
    return [int]$lead.記録なしの既定
}
# 2026-10-07 送る日が土日祝に落ちたら、その前の営業日に倒す（熊田さんがその日まで待つと遅れるため・統合設計5代目ボス）。
#   祝日は出荷の板と同じ表（shukka-todo\out\祝日.json）。表の最終年より後の日付は土日だけで倒し、報告に警告を出す。
#   これで 10/7 の仮の「送る日の上書き.json」（井上の阿川・丸水の2行）は要らなくなった＝退避へ移した
$shukujitsu = @{}; $shukuSaishu = 0
try { $sj = Get-Content 'C:\Users\info\OneDrive\projects\shukka-todo\out\祝日.json' -Raw -Encoding UTF8 | ConvertFrom-Json; foreach ($pp in $sj.祝日.PSObject.Properties) { $shukujitsu[$pp.Name] = $pp.Value }; $shukuSaishu = [int]$sj.最終年 } catch {}
$shukuKeikoku = @{}
function Mae-Eigyoubi([string]$s) {
    if (-not $s) { return $s }
    $d = [datetime]$s
    for ($i = 0; $i -lt 30; $i++) {
        $k = $d.ToString('yyyy-MM-dd')
        if ($shukuSaishu -eq 0 -or $d.Year -gt $shukuSaishu) { $shukuKeikoku[$k] = $true }
        if ($d.DayOfWeek -ne 'Saturday' -and $d.DayOfWeek -ne 'Sunday' -and -not $shukujitsu.ContainsKey($k)) { return $k }
        $d = $d.AddDays(-1)
    }
    return $s
}
# 倉庫出しの送る日＝出荷の板が出した「出す日」（県ごとの日数・便・余裕1営業日・ヤマトのクールの3日の決まり込み）。
#   出荷の板の出力に無い催事（候補外など）や、出力が3日より古いときは、納品日−3日を前の営業日に倒す
$soukoDasuHi = @{}
try {
    $sdj = Get-Content 'C:\Users\info\OneDrive\projects\shukka-todo\out\倉庫出しの知らせ.json' -Raw -Encoding UTF8 | ConvertFrom-Json
    if (([datetime]::UtcNow - ([datetime]$sdj.作成).ToUniversalTime()).TotalDays -le 3) { foreach ($s in @($sdj.知らせ) + @($sdj.過ぎた)) { if ($s.案件ID -and $s.出す日) { $soukoDasuHi[[string]$s.案件ID] = [string]$s.出す日 } } }
} catch {}
# 2026-10-23 出荷の板の鍵「出す日の一覧」（発注\記録\倉庫出荷の知らせ.json・板の本番の回 8:00/13:00 だけが書く・中身は上の out の知らせ＋過ぎた と同じ元）も読む。理由＝上の out は板の試し実行（--today 等）でも上書きされる（souko-dashi-notice.mjs:123）が、記録\ の方は試しでは書かれない（:128）＝汚れない方を後に読んで勝たせる。out が無いPCでも G: の方は読める
try {
    $sdj2 = Get-Content (Join-Path $PSScriptRoot '..\記録\倉庫出荷の知らせ.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if (([datetime]::UtcNow - ([datetime]$sdj2.作成).ToUniversalTime()).TotalDays -le 3) { foreach ($s in @($sdj2.出す日の一覧)) { if ($s.案件ID -and $s.出す日) { $soukoDasuHi[[string]$s.案件ID] = [string]$s.出す日 } } }
} catch {}
# 2026-09-28 仕組みの対象外（阪神＝週ごとにLINEで手配中など）。台帳に印を付け、発注ボードが灰色で出して「今日やること」から外す
$taigai = @{}
$taigaiPath = Join-Path $PSScriptRoot '仕組みの対象外.json'
if (Test-Path $taigaiPath) {
    try { $tj = Get-Content $taigaiPath -Raw -Encoding UTF8 | ConvertFrom-Json; foreach ($pp in $tj.案件.PSObject.Properties) { $taigai[$pp.Name] = $pp.Value } } catch {}
}
# 2026-09-28 上限のある品（供給上限.json）を先に読み、その品を含む候補に「送る前に確認が要る」の印を付ける（注意書きだけでは止まらないため）
$genteiHinmei = @{}
$kyPath0 = Join-Path $PSScriptRoot '供給上限.json'
if (Test-Path $kyPath0) {
    try { $ky0 = Get-Content $kyPath0 -Raw -Encoding UTF8 | ConvertFrom-Json
          foreach ($pp in $ky0.品目.PSObject.Properties) {
              if (-not $pp.Value.品名) { continue }
              # 2026-10-01 商品マスターが『割り振り』の形を変えた（案件IDをキーにした辞書 → 割り振り.内訳 の配列・割り振りkg/案kg）。
              #   古い形を読んでいたので、玉井さんが決めた配分が台帳に出ず「決まるまで一声かけて」のままになっていた。両方の形を読む。
              $wariMap = @{}
              if ($pp.Value.割り振り) {
                  if ($pp.Value.割り振り.内訳) {
                      foreach ($u in @($pp.Value.割り振り.内訳)) { if ($u.案件ID) { $wariMap[[string]$u.案件ID] = [ordered]@{ 配る量kg = $u.割り振りkg; 案の量kg = $u.案kg } } }
                  } else {
                      foreach ($qq in $pp.Value.割り振り.PSObject.Properties) { if ($null -ne $qq.Value.配る量kg) { $wariMap[[string]$qq.Name] = [ordered]@{ 配る量kg = $qq.Value.配る量kg; 案の量kg = $qq.Value.案の量kg } } }
                  }
              }
              $genteiHinmei[[string]$pp.Value.品名] = [ordered]@{ 品目コード = [string]$pp.Name; 上限kg = $pp.Value.上限kg; 状態 = [string]$pp.Value.状態; 割り振り = $wariMap
                  決め方 = [string]$(if ($pp.Value.割り振り.決め方) { $pp.Value.割り振り.決め方 } else { $pp.Value.割り振りの決め方 })
                  決めた人 = [string]$pp.Value.割り振り.決めた人; 決めた日 = [string]$pp.Value.割り振り.決めた日; 代わりの候補 = [string]$pp.Value.代わりの候補 }
          } } catch {}
}
$report = @()
# 2026-09-30 止め金の見張り（運転の決まり §10）。**止めたものは毎回の記録に出す。**
#   由来＝阪神を9/28に止めて9/30まで誰も見ず、初回納品10/12・455万円の会期が2日止まった（玉井さん叱責）。
#   見直す日が無い・過ぎている止め金は、毎回いちばん上に出す。
foreach ($k in $taigai.Keys) {
    $mi = [string]$taigai[$k].見直す日
    $ush = [string]$(if ($taigai[$k].'止めることで失うもの') { $taigai[$k].'止めることで失うもの' } else { '（失うものが書かれていません）' })
    if (-not $mi) { $report = @("⛔ 止め金に見直す日がありません：$k ／ 理由＝$([string]$taigai[$k].理由) ／ $ush") + $report }
    elseif ($mi -lt (Get-Date -Format 'yyyy-MM-dd')) { $report = @("⛔ 止め金の見直す日を過ぎています（$mi）：$k ／ 戻す条件＝$([string]$taigai[$k].戻す条件) ／ $ush") + $report }
    else { $report = @("・止めている：$k（見直す日 $mi）") + $report }
}
# 2026-09-30 会期が早い順に回す。倉庫の引当は「自分より前に始まる催事が押さえている分」を、ほかの台帳を読んで引く作りなので、
#   遅い催事を先に回すと、早い催事の**古い台帳**を見て多く取ってしまう（実際に和歌山が井上の8kgを見落として10kg取り、合計18kg＞在庫13.3kgになった）。
# 2026-10-31 草案（発注チェーンの点検・本番未投入） 項目3：入口が読めない回は保留＝どの台帳も書き換えない（指紋も変えない＝読めた次の回でまとめて作り直す）
$yosanFiles = @(Get-ChildItem $InDir -Filter *.json -ErrorAction SilentlyContinue | Sort-Object Name)
if ($nyuuguchiNG.Count) { $report += ('⛔ 入口のファイルが読めないので、今回は台帳を1つも書き換えません（保留）：' + ($nyuuguchiNG -join '・') + '。読めるようになった次の回でまとめて作り直します'); $yosanFiles = @() }
foreach ($f in $yosanFiles) {
    # 2026-10-09 調査（10代目ボス）：try が無く、壊れた予算ファイル1つで全体が止まり記録0行になっていた＝1ファイルずつ守る
    try {
    $j = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $id = [string]$j.案件ID
    if (-not $id) { continue }
    $ledgerPath = Join-Path $planDir ($id + '.json')
    $ledger = $null
    if (Test-Path $ledgerPath) { $ledger = Get-Content $ledgerPath -Raw -Encoding UTF8 | ConvertFrom-Json }
    $specPath = Join-Path $root ('納品指定\' + $id + '.json')
    $finger = "$($j.売上予算)|$($j.型)|$($j.仮置き)|$($j.会場)|$($j.会期開始)"
    if (Test-Path $specPath) { $finger += '|' + (Get-Item $specPath).LastWriteTime.ToString('s') }   # 納品指定を置いた・直したら作り直す
    # 2026-09-22 点検役の指摘①：担当者の答え（確認\〈案件ID〉.json）と倉庫の在庫（倉庫ストック品.json）も「変わったか」に入れる。入れないと OK が届いても台帳が作り直されず、永久に「OK待ち」のまま
    $kkF = Join-Path (Join-Path $root '確認') ($id + '.json'); if (Test-Path $kkF) { $finger += '|確認' + (Get-Item $kkF).LastWriteTime.ToString('s') }
    $stF = Join-Path $PSScriptRoot '倉庫ストック品.json'; if (Test-Path $stF) { $finger += '|倉庫' + (Get-Item $stF).LastWriteTime.ToString('s') }
    $dkF = Join-Path $PSScriptRoot '倉庫出しの出す人.json'; if (Test-Path $dkF) { $finger += '|出す人' + (Get-Item $dkF).LastWriteTime.ToString('s') }   # 2026-10-09 出す人を人が決めたら作り直す
    $naF = Join-Path $PSScriptRoot '確認に無い品は頼まない.json'; if (Test-Path $naF) { $finger += '|無い品' + (Get-Item $naF).LastWriteTime.ToString('s') }   # 2026-10-09 確認に無い品を0にする催事を決めたら作り直す
    # 2026-09-24 現場の発注（LINE）も「変わったか」に入れる。入れないと熊田さんの「発注完了」が届いても台帳が作り直されず、「現場が発注済み」が永久に付かない
    if (Test-Path $genbaPath) { $finger += '|現場' + (Get-Item $genbaPath).LastWriteTime.ToString('s') }
    # 2026-10-31 草案（発注チェーンの点検・本番未投入） 項目4：1タップの記録が変わった時も作り直す（今は「LINEで発注済み」が毎回書き直されるので隠れているだけ）。確認済みの鍵も同じ型
    if (Test-Path $ittapPath) { $finger += '|1タップ' + (Get-Item $ittapPath).LastWriteTime.ToString('s') }
    if (Test-Path $lokP) { $finger += '|確認済み' + (Get-Item $lokP).LastWriteTime.ToString('s') }
    # 2026-09-25 玉井さん：学問のするめも、クシローと同じように予算→候補→下書きまで通す。屋号ごとの商品マスターがあれば対象にする
    #   ファイルが無い屋号は今までどおり対象外＝作りかけの屋号で空の発注案ができないようにする
    $yagoBook = Join-Path $PSScriptRoot ('商品マスター_' + [string]$j.屋号 + '.xlsx')
    if (-not (Test-Path $yagoBook)) { $report += "対象外（屋号 $($j.屋号)・商品マスターがまだありません）：$id"; continue }
    $finger += '|' + (Get-Item $engine).LastWriteTime.ToString('s') + '|' + (Get-Item $yagoBook).LastWriteTime.ToString('s')
    # 2026-09-30 倉庫在庫が動いたら作り直す。入れないと、倉庫の残りが変わっても指紋が同じで飛ばされ、
    #   前の催事だけ作り直されて**古い押さえの量**で引き当ててしまう（和歌山が井上の8kgを見落として10kg取った実例）
    $zaikoP = Join-Path $root '倉庫在庫.json'
    if (Test-Path $zaikoP) { $finger += '|倉庫' + (Get-Item $zaikoP).LastWriteTime.ToString('s') }
    # 2026-10-01 人が数えた実数（在庫の材料\*_倉庫の実数_*.json）も目印に入れる。
    #   入れていなかったので、玉井さんが追加で見つけた「くんあし5.4kg・焼き貝ひも5kg」を足しても**作り直しが起きず、引当に出なかった**。
    #   倉庫在庫.json と同じ扱いにする（在庫が動いたら作り直す）。
    foreach ($jp in @(Get-ChildItem (Join-Path $root '在庫の材料') -Filter '*_倉庫の実数_*.json' -ErrorAction SilentlyContinue | Sort-Object Name)) { $finger += '|実数' + $jp.LastWriteTime.ToString('s') }
    # 2026-10-07 予定の直し（発注案\予定の直し\〈案件ID〉_*.json）も目印に入れる。入れないと窓で直しても作り直しが起きない（仕組みの対象外.json と同じ型の事故・点検役(3)）
    foreach ($np in @(Get-ChildItem $naoshiDir -Filter ($id + '_*.json') -ErrorAction SilentlyContinue | Sort-Object Name)) { $finger += '|直し' + $np.Name + '@' + $np.LastWriteTime.ToString('s') }
    # 2026-10-09 仕組みの対象外.json から外しても作り直しが起きず「対象外」のまま残った（学問ひらかた）。対象外の印も目印に入れる
    if ($taigai.ContainsKey($id)) { $finger += '|対象外' }
    if (-not $Test -and -not $All -and $ledger -and $ledger.指紋 -eq $finger) { continue }   # 変わっていない
    $start = [datetime]$j.会期開始; $end = [datetime]$j.会期終了
    $days = ($end - $start).Days + 1
    # 【決まり・2026-09-18 玉井さん】納品日と納品先は、百貨店の出店リスト／開催要項に書かれたとおりにする。
    #   会場へ直接ではなく、先に別の場所の納品センター（例：阪神＝淀川LC経由・ヤマト本伝票）へ送る場合がある。
    #   → 発注ごとに 納品指定\〈案件ID〉.json（納品日・納品先・住所・TEL・宛名・注意・出どころ）を置く。無ければ候補は「要項待ち」で、下書きは作れない。
    $deliv = $start.AddDays(-1).ToString('yyyy/M/d')               # 発注案に載せる目安だけ（下書きには使わない）
    $v = Find-Venue ([string]$j.会場)
    $spec = $null
    if (Test-Path $specPath) { $spec = Get-Content $specPath -Raw -Encoding UTF8 | ConvertFrom-Json }
    $safe = ($id + '_' + $j.会場) -replace '[\\/:*?"<>|\s]', '_'
    $plan = Join-Path $planDir ($safe + '.txt')
    $label = ([string]$j.会場 -replace '[\s　]', '') + ' ' + $start.ToString('M/d')
    $prm = @{ Budget = [double]$j.売上予算; Type = [string]$j.型; DeliveryDate = $deliv; Days = $days; Brand = [string]$j.屋号; Workbook = $yagoBook; Account = $Account; PlanPath = $plan; NoDrafts = $true; CaseId = $id; Label = $label }
    # 2026-10-08 もう送った相手は、倉庫の引当で送った数より下へ本文を削らない（make_order_drafts -SentJson＝相手→送った時の中身）。倉庫在庫が増えた後に送った相手の中身が変わり⚠が出た
    $dsNote = ''
    if ($ledger) {
        $sj = [ordered]@{}
        foreach ($sc in @(@($ledger.候補) | Where-Object { $_ -and [string]$_.状態 -match '^(送った|電話した|現場が発注済み)' })) { $sj[[string]$sc.相手] = $(if ([string]$sc.送った時の中身) { [string]$sc.送った時の中身 } elseif ([string]$sc.中身全文) { [string]$sc.中身全文 } else { [string]$sc.中身 }) }
        if ($sj.Count) { $prm.SentJson = ($sj | ConvertTo-Json -Compress) }
        # 2026-10-16 倉庫出しの行がもう「倉庫から出した」なら、その引き当てを渡す＝倉庫の今（出した後の数）で計算し直さない（阪神1週目の焼貝ひも・燻製が阿川へ戻った誤り）
        #   点検役⛔1：引き当てが空の行（9/30 より前・候補外で空にされた行）を渡すと倉庫から何も当てない＝全量が仕入先へ戻る。渡さずに画面へ出す（人が台帳の引き当てを直す）
        $dsRow = @(@($ledger.候補) | Where-Object { $_ -and [string]$_.方法 -eq '倉庫出し' -and [string]$_.状態 -eq '倉庫から出した' -and $_.候補外 -ne $true }) | Select-Object -First 1
        if ($dsRow) {
            $dsHiki = @($dsRow.引き当て | Where-Object { $_ -and $_.品目コード })
            if ($dsHiki.Count) { $prm.DashitaJson = ([ordered]@{ 引き当て = $dsHiki } | ConvertTo-Json -Depth 6 -Compress) }
            else { $dsNote = '⚠ 倉庫出しの行は「倉庫から出した」なのに台帳の引き当てが空＝倉庫の今で計算し直した。出し終わった品が仕入先の行に戻っていないか人が確かめ、台帳の引き当てを出した量に直す'; $report += "  $dsNote：$id" }
        }
    }
    # 2026-10-15 週ごとの予算は make_order_drafts に渡さない（玉井さん「催事は週で分けない」・14代目ボス経由）
    if ($v) {
        $prm.Address = $v.住所; $prm.Venue = $v.会場; $prm.Tel = $v.TEL
    } else {
        $prm.Address = '【納品先が一覧に無い：' + $j.会場 + '】'; $prm.Venue = [string]$j.会場; $prm.Tel = ''
    }
    # 2026-09-25 宛名の頭は屋号で変わる（クシロー＝「和商市場内クシロー」）。屋号.json に無ければ屋号名をそのまま使う
    $atesaki = '「' + [string]$j.屋号 + '」'
    $yagoCfgPath = Join-Path $PSScriptRoot '屋号.json'
    if (Test-Path $yagoCfgPath) {
        try { $yagoCfg = Get-Content $yagoCfgPath -Raw -Encoding UTF8 | ConvertFrom-Json; if ($yagoCfg.($j.屋号) -and $yagoCfg.($j.屋号).宛名の頭) { $atesaki = [string]$yagoCfg.($j.屋号).宛名の頭 } } catch {}
        # 2026-10-06 学問の予算ファイルは型が null（AIかおりが型を聞かない屋号）。空のまま渡すと make_order_drafts の ValidateSet で止まる。
        #   型が空なら屋号.json の「既定の型」を使う（学問＝A・統合設計5代目ボス 10/6）。既定も無ければ今までどおり止まる
        if (-not $prm.Type -and $yagoCfg -and $yagoCfg.($j.屋号) -and [string]$yagoCfg.($j.屋号).既定の型) { $prm.Type = [string]$yagoCfg.($j.屋号).既定の型; $report += "  型が空のため屋号の既定の型 $($prm.Type) を使った：$id" }
    }
    $prm.Attn = $atesaki + $j.担当者 + '　宛'
    if ($staffTel.ContainsKey([string]$j.担当者)) { $prm.Tel = $staffTel[[string]$j.担当者] }   # 熊田さん9/18：TELは担当の携帯
    $notes = ''
    if ($spec) {                                                    # 出店リスト／要項の指定で上書き（センター送りもここで）
        $prm.DeliveryDate = [string]$spec.納品日
        if ($spec.住所) { $prm.Address = [string]$spec.住所 }
        if ($spec.納品先) { $prm.Venue = [string]$spec.納品先 }
        if ($spec.TEL) { $prm.Tel = [string]$spec.TEL }
        if ($spec.宛名) { $prm.Attn = [string]$spec.宛名 }
        $notes = [string]$spec.注意
    }
    # 2026-10-15 週ごとの持ち主（〇週目の予算待ち）は外した＝玉井さん「催事は週で分けない。1つの現場は基本1人の担当者。大きな催事は日程で担当者ごとに案件を分ける」（14代目ボス経由）。
    #   欄は読む側が落ちないように空のまま残す（下の $doc で null を書く）
    $weekOwners = $null
    # 担当者の確認（AIかおりが 発注\確認\〈案件ID〉.json に書く）。5/19の決まり＝本人のOKの後にだけ発注＝OKが無ければ下書きは作れない（2026-09-21 ズレ調査 A2）
    $kkPath = Join-Path $root ('確認\' + $id + '.json')   # 2026-09-21 「確認」と案件IDの間の \ が抜けていた（確認フォルダを見に行けず、OK待ちが永久に解けなかった）
    $kk = $null; if (Test-Path $kkPath) { try { $kk = Get-Content $kkPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {} }
    $kakunin = $(if (-not $kk) { 'まだ' } elseif ($kk.候補の答え -eq '修正あり') { '修正あり' } else { 'OK' })
    # 2026-10-14 AIかおり 19：「修正あり」でも確認の段階が「済」でない（マネキン・個人手配の段の途中）＝担当者の確定前＝答え待ちと同じ（設計図 ②発注の行の段「候補」）。止まり・困りごとにしない
    if ($kakunin -eq '修正あり' -and [string]$kk.確認の段階 -ne '済') { $kakunin = 'まだ' }
    $candPath = Join-Path $env:TEMP ('cand_' + ($id -replace '[^\w\-]', '_') + '.json')
    $prm.CandidatesPath = $candPath
    if ($kk) { $prm.FixPath = $kkPath }   # 2026-09-30 「修正あり」の中身を本文に反映させる（反映できなければ候補の側で止まる）
    # 2026-10-31 草案（発注チェーンの点検・本番未投入） 項目5：人が決めた修正の扱い（注文／報告）と、前の回の反映の状態を渡す（make_order_drafts が「確かめ待ち」を決める）
    if ($ledger -and $ledger.修正の扱い) { $prm.ShuseiAtsukai = [string]$ledger.修正の扱い.扱い; $prm.ShuseiKagi = [string]$ledger.修正の扱い.答えた日時 }
    if ($ledger -and $ledger.担当者の確認) { $prm.ShuseiZenkai = [string]$ledger.担当者の確認.反映; $prm.ShuseiZenkaiKagi = [string]$ledger.担当者の確認.答えた日時 }
    $prm.NaoshiDir = $naoshiDir   # 2026-10-07 予定の直し（担当者の修正の後・供給上限の前に、同じ反映で当てる）
    if ($taigai.ContainsKey($id)) { $prm.Taishougai = $true }   # 2026-09-30 仕組みの対象外＝倉庫を押さえない（ほかの催事が使える）
    & $engine @prm | ForEach-Object { $report += "  $_" }
    $c = Get-Content $candPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Remove-Item $candPath -Force -ErrorAction SilentlyContinue
    # 台帳に混ぜる：相手ごとの状態は残す。中身が変わった「下書き済」は候補に戻し、古い下書きを覚えておく（ボードが【旧】を付ける）
    # 2026-09-30 穴を塞ぐ：「修正あり」なのに下書き可＝true のままだった＝直す前の数量で下書きが作れた。
    #   候補の側（make_order_drafts）が修正を本文に反映できたときだけ先へ進む。できないものは理由を出して止める。
    $fixNG = ''
    if ($kakunin -eq '修正あり') {
        $fs = [string]$c.修正の反映.状態
        # 2026-10-31 草案 項目5：報告と人が確かめた時は数を変えずに先へ
        if ($fs -notin @('反映した', '反映しない（報告と確かめた）')) { $fixNG = '担当者の修正を反映できていない（' + $(if ($c.修正の反映.できない理由) { (@($c.修正の反映.できない理由) | Select-Object -First 2) -join '／' } else { $fs }) + '）' }
    } elseif ($kakunin -eq 'OK' -and [string]$c.修正の反映.状態 -eq '反映できない') {
        # 2026-10-12 ★10/11「確認後は数字を変えない」：OK でも確認の数を当てる（make_order_drafts）。当てられない時は下書きを作らない
        $fixNG = '担当者が確認した数を当てられない（' + ((@($c.修正の反映.できない理由) | Select-Object -First 2) -join '／') + '）'
    }
    # 2026-10-07 予定の直しを反映できない（本文に行が無い・2件ある等）ときも下書きを作らせない（担当者の修正と同じ歯止め）
    $naoshiNG = ''
    if ([string]$c.予定の直し.状態 -eq '反映できない') { $naoshiNG = '予定の直しを反映できていない（' + ((@($c.予定の直し.できない理由) | Select-Object -First 2) -join '／') + '）' }
    # 2026-10-09 納品指定（要項から書いた一次）に住所があれば、納品先.json に会場名が無くても止めない（学問ひらかた＝申込書の商品送付先から書いた）
    $why = $(if ($j.仮置き -eq $true) { '仮置き（玉井さん確認待ち）' } elseif (-not $v -and -not ($spec -and $spec.住所)) { '納品先が一覧に無い' } elseif (-not $spec) { '納品指定がまだ無い＝書くのは蔵人（要項が手元にあるなら今日書ける。無いなら探す。納品指定\' + $id + '.json を置くと候補が動く）' } elseif ($kakunin -eq 'まだ') { '担当者のOK待ち（AIかおりの確認がまだ）' } elseif ($fixNG) { $fixNG } elseif ($naoshiNG) { $naoshiNG } else { '' })
    $old = @{}
    if ($ledger -and $ledger.候補) { foreach ($o in $ledger.候補) { $old[[string]$o.相手] = $o } }
    $cands = @()
    foreach ($x in $c.候補) {
        if ($x.送るか -ne '送る') { continue }
        $o = $old[[string]$x.相手]
        $state = '候補'; $when = ''; $eid = ''; $sid = ''; $subj = ''; $olds = @()
        # 2026-09-23 board_action.ps1 だけが書く3項目。中身は見ずにそのまま写す（作り直しで消すと、差し替えの前書き・戻りメールの印・二重の判定が消える）
        $hitoOK = $null; $modori = $null; $tsuu1 = $null; $tsuu2 = $null; $kakuOK = $null
        if ($o) {
            $state = [string]$o.状態; $when = [string]$o.日時; $eid = [string]$o.EntryID; $sid = [string]$o.StoreID; $subj = [string]$o.件名; $olds = @($o.旧下書き)
            $hitoOK = $o.人が確かめた; $modori = $o.戻り; $tsuu1 = $o.確かめた通数; $tsuu2 = $o.見つけた通数
            $kakuOK = $o.確認しました   # 2026-09-28 board_action だけが書く。中身は見ずにそのまま写す（作り直しで消すと、数量限定の品の確認が毎朝消える）
            # 2026-10-08 ボスの依頼（鍵=仕組み/取消）①：「中身」は画面用に90字で切ってある＝91字目以降の品の数量変更を見逃していた。全文で比べる
            #   （古い台帳に全文が無いときだけ、切った中身どうしで比べる＝全文が無いだけで下書きを候補へ戻さない）
            $oZen = [string]$o.中身全文; $xZen = $(if ([string]$x.中身全文) { [string]$x.中身全文 } else { [string]$x.中身 })
            $kawatta = $(if ($oZen) { $oZen -ne $xZen } else { [string]$o.中身 -ne [string]$x.中身 })
            if ($state -eq '下書き済' -and $kawatta) {
                if ($eid) { $olds += [ordered]@{ EntryID = $eid; StoreID = $sid; 件名 = $subj; 理由 = '中身が変わった ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') } }
                $state = '候補'; $when = ''; $eid = ''; $sid = ''; $subj = ''
            }
        }
        $okuru = ''; try { $okuru = ([datetime]$prm.DeliveryDate).AddDays(-(Lead-Days ([string]$x.相手))).ToString('yyyy-MM-dd') } catch {}
        if ($x.方法 -eq '倉庫出し' -and $soukoDasuHi.ContainsKey($id)) { $okuru = $soukoDasuHi[$id] } else { $okuru = Mae-Eigyoubi $okuru }   # 2026-10-07 土日祝は前の営業日・倉庫出しは出荷の板の出す日
        # 現場が先に発注していたら、下書きを作らせない（二重発注を止める）。まだ「候補」の行だけが対象＝人が押した状態は上書きしない
        # 2026-10-31 草案（発注チェーンの点検・本番未投入） 項目1・2（第12版「品×出来事ごと」・決10「受付と成立を分ける」）：
        #   品ごとに当てる。全品が当たった時だけ「現場が発注済み」（数は未確認）。一部だけなら「一部は現場が発注済み」で止める＝下書きを作らない（済んだ品を二重に頼まない）。
        #   根拠が見えなくなっても完了は戻さない（期間経過・読み込み失敗・取り込み漏れ）。動くのは取消・訂正の記録と人の［戻す］だけ。照合は90字で切った中身でなく全文で
        $genbaNote = [string]$(if ($o) { $o.現場の記録 } else { '' })
        $genbaShougou = $(if ($o) { $o.現場の照合 } else { $null })
        if (($state -eq '候補' -or $state -eq '現場が発注済み' -or $GENBA_HOLD -contains $state) -and $x.方法 -ne '倉庫出し') {
            $xZenG = $(if ([string]$x.中身全文) { [string]$x.中身全文 } else { [string]$x.中身 })
            $hantei = Get-GenbaHantei -Id $id -Venue ([string]$j.会場) -Naka $xZenG -Aite ([string]$x.相手) -Ittap $ittap -Genba $genba
            $tori = Get-GenbaTorikeshi -Id $id -Aite ([string]$x.相手) -Ittap $ittap -Naoshi @($c.予定の直し.一覧) -Old $o
            $gr = Resolve-GenbaState -State $state -Old $o -Hantei $hantei -Torikeshi $tori -Naka $xZenG
            if ($gr.状態 -ne $state) { $when = (Get-Date -Format 'yyyy-MM-dd HH:mm') }
            $state = $gr.状態; $genbaNote = [string]$gr.現場の記録; $genbaShougou = $gr.現場の照合
        }
        $row = [ordered]@{ 相手 = $x.相手; 方法 = $x.方法; 中身 = $x.中身; 中身全文 = [string]$(if ($x.中身全文) { $x.中身全文 } else { $x.中身 }); 宛先 = $x.宛先; 送る日 = $okuru; 状態 = $state; 日時 = $when; 現場の記録 = $genbaNote; EntryID = $eid; StoreID = $sid; 件名 = $subj; 旧下書き = @($olds | Where-Object { $_ }); 引き当て = @($x.引き当て | Where-Object { $_ -and $_.品目コード }) }   # 2026-09-30 引き当て＝催事の残りから当てた分（空の辞書を入れない）
        if ($genbaShougou) { $row.現場の照合 = $genbaShougou }   # 2026-10-31 草案（発注チェーンの点検・本番未投入） 項目1：当たった品・当たらない品・数の確かめ
        if ($o -and $o.現場の判定を外した) { $row.現場の判定を外した = $o.現場の判定を外した }   # 2026-10-31 草案（発注チェーンの点検・本番未投入） 項目2：人が［戻す］で外した印（board_action だけが書く）
        # 2026-10-23 24代目ボスの裁定：倉庫出しの行がまだ「候補」で、LINE に熊田さんの「発送します」等（1タップ 倉庫から出した）があれば「LINEで報告あり」の印を出す（状態は変えない・毎回作り直す）
        if ($x.方法 -eq '倉庫出し' -and $state -eq '候補') { $hk = Ittap-SoukoHoukoku $id ([string]$j.会場); if ($hk) { $row.LINEで報告あり = $hk } }
        # 2026-10-16 もう倉庫から出した行は、中身・中身全文・引き当て・送る日を出した時のまま残す（出した事実は作り直しで変えない）。作り直しの結果と違えば知らせる
        if ($o -and $x.方法 -eq '倉庫出し' -and [string]$o.状態 -eq '倉庫から出した') {
            $nZen = [string]$row.中身全文
            $row.中身 = $o.中身; $row.中身全文 = [string]$(if ($o.中身全文) { $o.中身全文 } else { $o.中身 }); $row.送る日 = $o.送る日
            $row.引き当て = @($o.引き当て | Where-Object { $_ -and $_.品目コード })
            if ($nZen -ne $row.中身全文) {
                $dsNote = (@($dsNote, ('⚠ 倉庫から出した行は出した時の中身のまま残した（作り直しでは「' + $nZen + '」＝仕入先の行と二重になっていないか人が確かめる）')) | Where-Object { $_ }) -join '／'
                $report += "  ⚠ 倉庫から出した行は出した時の中身のまま残した（作り直しの結果と違う＝仕入先の本文を人が確かめる）：$id ／ 出した時＝$($row.中身全文) ／ 作り直し＝$nZen"
            }
        }
        # 数量限定の品が入っている候補は、送る前に確認が要る（割り振りが決まるまで熊田さんに送らせない）
        foreach ($hn in $genteiHinmei.Keys) {
            if ([string]$x.中身全文 -and ([string]$x.中身全文).Contains($hn) -or ([string]$x.中身).Contains($hn)) {
                $row.送る前に確認 = $true
                $wari = $null; try { $wari = $genteiHinmei[$hn].割り振り[$id] } catch {}
                if ($wari) {
                    $g = $genteiHinmei[$hn]
                    $row.確認の理由 = ($hn + '：この催事に配るのは ' + [string]$wari.配る量kg + 'kg です（案の量 ' + [string]$wari.案の量kg + 'kg・今季の確保は全部で ' + [string]$g.上限kg + 'kg・' + [string]$g.決め方 + '＝' + [string]$g.決めた人) + ' ' + [string]$g.決めた日 + '）。' + $(if ([double]$wari.配る量kg -le 0) { '**この催事には回りません（今季の確保ぶんが尽きた）。下書きの発注量は0にしてあります。代わりの品にするかは玉井さんの判断です＝' + [string]$g.代わりの候補 } elseif ([double]$wari.配る量kg -lt [double]$wari.案の量kg) { '**下書きの量は ' + [string]$wari.配る量kg + 'kg に直してあります。**' } else { 'この量のまま送って構いません。' })
                    $row.配る量kg = $wari.配る量kg
                } else {
                    $row.確認の理由 = ($hn + ' は今季の確保が ' + [string]$genteiHinmei[$hn].上限kg + 'kg しかありません（' + [string]$genteiHinmei[$hn].状態 + '）。どの催事に何kg回すかが決まるまで、送る前に玉井さんか蔵人に一声かけてください')
                }
                break
            }
        }
        # 2026-10-11 11代目ボス：納品指定の納品日が【推定】の催事は、熊田さんが送る前に目で確かめる（学問ひらかた＝申込書に商品の着日が無い）。
        #   仕入先へのメール本文には書かない（社内の注意）。既にある「送る前に確認」の印と理由を使う＝ボードの行に理由が出て、熊田さんが［確認しました］を押す
        if (-not $row.送る前に確認 -and $x.方法 -ne '倉庫出し' -and [string]$notes -match '【推定】納品日') {
            $row.送る前に確認 = $true
            $row.確認の理由 = ('納品日 ' + [string]$prm.DeliveryDate + ' は推定です（百貨店の書類に商品の着日が書かれていない）。送る前に、納品日がこれでよいかを目で確かめてください（' + [string]$spec.出どころ + '）')
        }
        # 2026-10-23 r9（★10/23 夕「ロットの近似値」・版6 r9 ハンコ）：箱で割り切れない袋数の注（make_order_drafts の 箱の注）＝送る前に確認にして、熊田さんの画面の確認の理由に足す（数は変えない）
        $hako9 = @(@($x.箱の注) | Where-Object { $_ })
        if ($hako9.Count -and $x.方法 -ne '倉庫出し') { $row.送る前に確認 = $true; $row.確認の理由 = ((@([string]$row.確認の理由, ($hako9 -join '／')) | Where-Object { $_ }) -join '／') }
        if ($null -ne $kakuOK) { $row.確認しました = $kakuOK }
        # 2026-10-09 倉庫出しの「出す人」（フルネーム）。既定＝担当者（★10/8 通える範囲は担当者が持っていく）。人が決めた分（仕組み\倉庫出しの出す人.json）が優先＝送る日もそれに置き換える
        #   読む側＝AIかおりの［倉庫から出庫］（担当者か出す人が本人の催事を出す・在庫の会話と 10/9 一声）・board_build
        if ($x.方法 -eq '倉庫出し') {
            $dk = $null; try { $dk = @((Get-Content (Join-Path $PSScriptRoot '倉庫出しの出す人.json') -Raw -Encoding UTF8 | ConvertFrom-Json).決め) | Where-Object { [string]$_.案件ID -eq $id } | Select-Object -Last 1 } catch {}
            $row.出す人 = $(if ($dk -and [string]$dk.出す人の名前) { [string]$dk.出す人の名前 } else { [string]$j.担当者 })
            if ($dk) { $row.出す人の説明 = [string]$dk.出す人; if ([string]$dk.送る日) { $row.送る日 = [string]$dk.送る日 } }
            else {
                # 2026-10-12 判定の順番（12代目ボスの裁定・★10/8 原文）：人の決め（上・本人の言葉もここに書く）→ ①拠点が遠い ②会期途中の追加（人の決め）③前の催事から移動日が無い
                #   → 宿泊手当の前例（★10/11）→ 担当者（既定）。①③は board_build の Dasu-Hito と同じ決め方（担当者.json の 遠い・同じ担当者の前の催事の会期）
                $kyRiyu = @()
                try {
                    if (-not $script:tanKyoten) { $script:tanKyoten = (Get-Content (Join-Path $PSScriptRoot '担当者.json') -Raw -Encoding UTF8 | ConvertFrom-Json).拠点 }
                    $ky0 = $script:tanKyoten.([string]$j.担当者); if ($ky0 -and $ky0.遠い -eq $true) { $kyRiyu += ('①担当者の拠点が遠い（' + [string]$ky0.拠点 + '）') }
                    if (-not $script:allKaiki) { $script:allKaiki = @(foreach ($lf in @(Get-ChildItem $planDir -Filter '20*.json' -ErrorAction SilentlyContinue)) { try { $lj = Get-Content $lf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json; [pscustomobject]@{ 案件ID = [string]$lj.案件ID; 担当者 = [string]$lj.担当者; 会場 = [string]$lj.会場; 開始 = [string]$lj.会期開始; 終了 = [string]$lj.会期終了 } } catch {} }) }
                    foreach ($o0 in $script:allKaiki) { if ($o0.案件ID -eq $id -or $o0.担当者 -ne [string]$j.担当者) { continue }; try { if (([datetime]$o0.終了) -ge $start.AddDays(-1) -and ([datetime]$o0.開始) -lt $start) { $kyRiyu += ('③前の催事（' + $o0.会場 + ' 〜' + $o0.終了 + '）から移動日が無い') } } catch {} }
                } catch {}
                # ここから下は ①③に当たらない時だけ＝★10/11「通ったか出張かは経費精算の前例から」（現場手当表）：
                #   前例（仕組み\通いか出張か.json・kayoi_shucchou.py が現場手当表から作る）：宿泊手当が付いた＝出張→倉庫から発送（出す人＝熊田かおり・★10/8 倉庫が発送）
                #   通い→担当者が持っていく（★10/8 の既定）。前例なし・混在→担当者のまま（既定）で、説明に「前例なし」を出す
                $kyMae = $null
                try {
                    if (-not $script:kyoRows) { $script:kyoRows = @((Get-Content (Join-Path $PSScriptRoot '通いか出張か.json') -Raw -Encoding UTF8 | ConvertFrom-Json).行) }
                    $tn0 = ([string]$j.担当者) -replace '[\s　]', ''; $vn0 = (Norm ([string]$j.会場)) -replace '(本店|店)$', ''
                    if ($vn0) {
                        $kyHits = @()
                        foreach ($kr0 in $script:kyoRows) {
                            if ([string]$kr0.担当者 -ne $tn0) { continue }
                            $gn = (Norm ([string]$kr0.現場名)) -replace '(本店|店)$', ''
                            if ($gn -and ($gn.Contains($vn0) -or $vn0.Contains($gn))) { $kyHits += $kr0 }
                        }
                        $kyMae = @($kyHits | Sort-Object 最後の日 -Descending) | Select-Object -First 1
                    }
                } catch {}
                if ($kyRiyu.Count) { $row.出す人 = '熊田かおり'; $row.出す人の説明 = ('倉庫から発送（' + ($kyRiyu -join '／') + '）') }
                elseif ($kyMae -and [string]$kyMae.判定 -eq '出張') { $row.出す人 = '熊田かおり'; $row.出す人の説明 = ('倉庫から発送（前例＝出張：' + [string]$kyMae.現場名 + ' ' + [string]$kyMae.日数 + '日のうち宿泊 ' + [string]$kyMae.宿泊の日数 + '日・最後 ' + [string]$kyMae.最後の日 + '・現場手当表）') }
                elseif ($kyMae -and [string]$kyMae.判定 -eq '通い') { $row.出す人の説明 = ('担当者が持っていく（前例＝通い：' + [string]$kyMae.現場名 + ' ' + [string]$kyMae.日数 + '日・宿泊なし・現場手当表）') }
                else { $row.出す人の説明 = $(if ($kyMae) { '担当者（前例が混在：' + [string]$kyMae.現場名 + '）' } else { '担当者（前例なし＝現場手当表にこの会場が無い）' }) }
            }
            # 2026-10-12 12代目ボス：出す人が変わったら、熊田さんがボードを開いた時に分かるように残す（気づかないまま出荷が漏れないように）。前の台帳の出す人と違えば印・同じなら前の印を写す
            if ($o -and [string]$o.出す人 -and [string]$o.出す人 -ne [string]$row.出す人) { $row.出す人が変わった = ([string]$o.出す人 + ' → ' + [string]$row.出す人 + '（' + (Get-Date -Format 'M/d HH:mm') + '）') }
            elseif ($o -and [string]$o.出す人が変わった -and [string]$row.状態 -eq '候補') { $row.出す人が変わった = [string]$o.出す人が変わった }   # 出した（倉庫から出した）後は畳む
        }
        if ($o -and $o.押した人) { $row.押した人 = $o.押した人; $row.どこで = $o.どこで }
        if ($o -and $o.追加の持ち出し) { $row.追加の持ち出し = @($o.追加の持ち出し) }   # 2026-10-16 15代目ボス裁定：1回目の後に倉庫から出した分（2回目〜・足すだけ・発注ボードが書く）。作り直しで消さない
        if ($o -and [string]$o.作ったPC -and $eid) { $row.作ったPC = [string]$o.作ったPC }   # 2026-10-08 穴28：下書きが残っている間だけ写す（候補に戻れば消える）   # 2026-10-08 board_action だけが書く（ブラウザ版・出荷の板の条件）。そのまま写す
        if ($null -ne $hitoOK) { $row.人が確かめた = $hitoOK }
        if ($null -ne $modori) { $row.戻り = $modori }
        if ($null -ne $tsuu1) { $row.確かめた通数 = $tsuu1 }
        if ($null -ne $tsuu2) { $row.見つけた通数 = $tsuu2 }
        # 2026-10-08 ボスの依頼（鍵=仕組み/取消）②：「送った」「電話した」の行は、中身だけ新しい数量に書き換わり何も出なかった。
        #   送った時の中身（全文）を残し、今の中身と違えば「送った後に変わった」を立てる（ボードに⚠）。相手へ直すのは人＝ここは知らせるだけ。
        #   送った時の中身が無い古い行は、今回の前の全文を送った時の中身として置く（＝今日の時点を起点にする・遡って⚠は出さない）
        if ($o -and $state -match '^(送った|電話した)') {
            $okuttaNaka = $(if ([string]$o.送った時の中身) { [string]$o.送った時の中身 } elseif ([string]$o.中身全文) { [string]$o.中身全文 } else { [string]$o.中身 })
            $row.送った時の中身 = $okuttaNaka
            # 2026-10-23 穴A（24代目ボスの裁定 10/23）：送った時の中身は verifycopy が実物のメール本文から写す（出どころ＝実物のメール）。
            #   ⚠「送った後に変わった」は、送った時の台帳の中身（verifycopy が控える。無い古い行＝送った時の中身が台帳由来なのでそれ）と今の中身全文が違う時だけ。
            #   実物が台帳と違う行は「手で直して送った」（注・⚠ではない）。台帳の中身・中身全文は書き換えない（★10/11）
            $daichoSnap = $(if ([string]$o.送った時の台帳の中身) { [string]$o.送った時の台帳の中身 } else { $okuttaNaka })
            $row.送った時の台帳の中身 = $daichoSnap
            $dedokoro = [string]$o.送った時の中身の出どころ
            if ($dedokoro) { $row.送った時の中身の出どころ = $dedokoro }
            if ([string]$o.実際に送った日時) { $row.実際に送った日時 = [string]$o.実際に送った日時 }
            $row.手で直して送った = ($o.手で直して送った -eq $true)
            if ($daichoSnap -and $daichoSnap -ne [string]$row.中身全文) { $row.送った後に変わった = $true }
            # 読み手の規則（24代目ボス 10/23・群の報告〈AIかおり group_report〉と画面はこの欄を読む・規則はここ1か所）：
            #   送った後に熊田さんの公式の修正（予定の直し＝相手が同じ・送った後の物／LINEの取消・数量変更＝確認の答えた人が熊田さんで送った後）がある行→台帳の中身
            #   無い行→送った時の中身（実物）／実物≠台帳で修正の記録も無く台帳が送る前のまま→「確かめ待ち」（熊田さんが確かめることで［メールの数］［発注ボードの数］を押すまで、群の報告に出さない）
            $okuttaAt = $null; try { $okuttaAt = [datetime]$(if ([string]$o.実際に送った日時) { [string]$o.実際に送った日時 } else { [string]$o.日時 }) } catch {}
            $koushiki = $false
            foreach ($nr in @($c.予定の直し.一覧)) { if (-not $nr -or [string]$nr.行.頼む先 -ne [string]$x.相手) { continue }; $nt = $null; try { $nt = [datetime]([string]$nr.いつ) } catch {}; if (-not $okuttaAt -or ($nt -and $nt -gt $okuttaAt)) { $koushiki = $true; break } }
            if (-not $koushiki -and $kk -and ([string]$kk.答えた人) -match '熊田') { $kt = $null; try { $kt = [datetime]([string]$kk.答えた日時) } catch {}; if ($kt -and $okuttaAt -and $kt -gt $okuttaAt) { $koushiki = $true } }
            $kotae = ''
            foreach ($kg in @($lineOkKeysPBF)) { if ($kg -eq ('送った中身|' + $id + '|' + [string]$x.相手 + '|メール')) { $kotae = 'メール' }; if ($kg -eq ('送った中身|' + $id + '|' + [string]$x.相手 + '|ボード')) { $kotae = 'ボード' } }
            $yomi = ''; $chu = ''
            if ($kotae -eq 'メール') { $yomi = '実物'; $chu = '確かめ済み＝仕入先に届いているのは送ったメールの数' }
            elseif ($kotae -eq 'ボード') { $yomi = '台帳'; $chu = '確かめ済み＝仕入先に届いているのは発注ボードの数' }
            elseif ($dedokoro -ne '実物のメール') { $yomi = '台帳'; if ($dedokoro -like 'PDF*') { $chu = 'PDFで送った（中身は発注ボードの数）' } }
            elseif ($koushiki) { $yomi = '台帳'; if ($row.手で直して送った) { $chu = '送った後に熊田さんの修正あり（発注ボードの数が正）' } }
            elseif (-not $row.手で直して送った) { $yomi = '実物' }
            elseif (-not $row.送った後に変わった) { $yomi = '確かめ待ち'; $chu = '送ったメールの数と発注ボードの数が違う＝熊田さんの確かめ待ち' }
            else { $yomi = '実物'; $chu = '手で直して送った（送ったメールの数）' }
            if ($yomi -eq '実物' -and $row.手で直して送った -and -not $chu) { $chu = '手で直して送った（送ったメールの数）' }
            $row.送った中身の読み = $yomi
            $row.報告に出す中身 = $(if ($yomi -eq '台帳') { [string]$row.中身全文 } elseif ($yomi -eq '実物') { $okuttaNaka } else { '' })
            if ($chu) { $row.送った中身の注 = $chu }
        }
        $cands += $row
        $old.Remove([string]$x.相手) | Out-Null
    }
    # 2026-09-27 候補から外れた相手の行を消さずに残す（発注ボードの会話の依頼）。
    #   これまでは相手が候補から外れると「送った」も EntryID も消え、送った事実が台帳から落ちていた（＝二重に送っても気づけない）
    foreach ($k in @($old.Keys)) {
        $o = $old[$k]
        $r2 = [ordered]@{}
        foreach ($pp in $o.PSObject.Properties) { $r2[$pp.Name] = $pp.Value }
        # 2026-10-16 もう倉庫から出した行は、作り直しで倉庫出しが出なくても候補外にしない・引き当てを消さない（出した事実＝在庫の帳簿の出庫の元）
        if ([string]$o.方法 -eq '倉庫出し' -and [string]$o.状態 -eq '倉庫から出した') {
            $report += "  ⚠ 倉庫から出した行が作り直しで出なかった＝出した時のまま残した（仕入先の本文を人が確かめる）：$id"
            $dsNote = (@($dsNote, '⚠ 倉庫から出した行が作り直しでは出なかった（出した時のまま残した）＝仕入先の行と二重になっていないか人が確かめる') | Where-Object { $_ }) -join '／'
            $cands += [pscustomobject]$r2
            continue
        }
        $r2.候補外 = $true
        $r2['引き当て'] = @()   # 2026-09-30 候補から外れた行は倉庫を押さえない＝古い引き当てを残さない（画面にも出さない）
        $r2.候補外になった日 =[string]$(if ($o.候補外になった日) { $o.候補外になった日 } else { (Get-Date -Format 'yyyy-MM-dd HH:mm') })
        $cands += [pscustomobject]$r2
    }
    # 2026-10-09 マニュアル係⑩：全部取り消して相手ごと候補から消えると、その相手の古い下書きに【旧】が付かず、熊田さんが手で消すしかなかった。
    #   消えた相手の「下書き済」（と印の付いていない旧下書き）を台帳に覚え、その下書きを作ったPCで Outlook が開いている時だけ件名に【旧】を付ける。
    #   Outlook を起動はしない（9/15 熊田PCの事故）。付けられなければ次の作り直しでまた試す。消さない
    $kieta = @(); $nowAite = @{}; foreach ($cx in $cands) { $nowAite[[string]$cx.相手] = $true }
    if ($ledger) {
        foreach ($kx in @($ledger.消えた相手の下書き)) { if ($kx -and -not $kx.印済み -and -not $nowAite.ContainsKey([string]$kx.相手)) { $kieta += $kx } }
        foreach ($o in @($ledger.候補)) {
            if (-not $o -or $nowAite.ContainsKey([string]$o.相手)) { continue }
            if ([string]$o.状態 -eq '下書き済' -and [string]$o.EntryID) { $kieta += [pscustomobject][ordered]@{ 相手 = [string]$o.相手; EntryID = [string]$o.EntryID; StoreID = [string]$o.StoreID; 件名 = [string]$o.件名; 作ったPC = [string]$o.作ったPC; 消えた日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm'); 印済み = $false } }
            foreach ($od in @($o.旧下書き)) { if ($od -and -not $od.印済み -and [string]$od.EntryID) { $kieta += [pscustomobject][ordered]@{ 相手 = [string]$o.相手; EntryID = [string]$od.EntryID; StoreID = [string]$od.StoreID; 件名 = [string]$od.件名; 作ったPC = [string]$o.作ったPC; 消えた日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm'); 印済み = $false } } }
        }
    }
    if ($kieta.Count -and (Get-Process OUTLOOK -ErrorAction SilentlyContinue)) {
        foreach ($kx in $kieta) {
            if ([string]$kx.作ったPC -and [string]$kx.作ったPC -ne $env:COMPUTERNAME) { continue }
            try {
                $olK = New-Object -ComObject Outlook.Application; $nsK = $olK.GetNamespace('MAPI')
                $itK = $(if ([string]$kx.StoreID) { $nsK.GetItemFromID([string]$kx.EntryID, [string]$kx.StoreID) } else { $nsK.GetItemFromID([string]$kx.EntryID) })
                if ($itK.Sent) { $kx | Add-Member -NotePropertyName 印済み -NotePropertyValue $true -Force; $kx | Add-Member -NotePropertyName メモ -NotePropertyValue '送信済みだった＝印を付けない' -Force; continue }
                if (-not ([string]$itK.Subject).StartsWith('【旧】')) { $itK.Subject = '【旧】' + [string]$itK.Subject; $itK.Save() }
                $kx | Add-Member -NotePropertyName 印済み -NotePropertyValue $true -Force
                $report += ('  全部取り消した相手の古い下書きに【旧】を付けた：' + $id + ' ' + [string]$kx.相手)
            } catch {
                # 見つからない＝もう消してある（人が消した・送った）。それ以上試さない
                if ($_.Exception.Message -match 'not found|見つかりません|could not be found|0x8004010F') { $kx | Add-Member -NotePropertyName 印済み -NotePropertyValue $true -Force; $kx | Add-Member -NotePropertyName メモ -NotePropertyValue '下書きが見つからない（消してある）' -Force }
            }
        }
    }
    $left = @($cands | Where-Object { $DONE -notcontains $_.状態 -and $_.候補外 -ne $true }).Count   # 2026-09-27 候補外の行は「残り」に数えない
    $summary = $(if ($why) { $why } elseif (-not $cands.Count) { '候補なし' } elseif ($left -eq 0) { '完了' } else { "残り $left 件" })
    $doc = [ordered]@{
        schema = 1; 案件ID = $id; 印 = $label; 屋号 = $j.屋号; 会場 = $j.会場; 会期開始 = $j.会期開始; 会期終了 = $j.会期終了; 担当者 = $j.担当者
        売上予算 = $j.売上予算; 型 = $j.型; 仮置き = $j.仮置き; 週ごとの売上予算 = $null; 週ごとの持ち主 = $null;   <# 2026-10-15 週で分けない＝欄は空で残す（予算と型に古い週の値があっても写さない） #> 束の案件ID = @($j.束の案件ID)
        納品 = [ordered]@{ 納品希望日 = $prm.DeliveryDate; 住所 = $prm.Address; 会場 = $prm.Venue; 宛名 = $prm.Attn; TEL = $prm.Tel; 注意 = $notes; 要項の確認 = [bool]$spec; 営業日数 = $days }
        引き当てなしの理由 = @(@($c.引き当てなしの理由) + @($dsNote) | Where-Object { $_ })   # 2026-09-30 空を混ぜない（@($null) は「空1個」の配列になる） 倉庫に在庫があるのに当てなかった品と理由（発注ボードが画面に出す）
        いちばん早い送る日 =$(@($cands | ForEach-Object { $_.送る日 } | Where-Object { $_ } | Sort-Object) | Select-Object -First 1); 送る日は仮 = (-not $spec)
        状態 = $(if ($taigai.ContainsKey($id)) { '仕組みの対象外（' + [string]$taigai[$id].その間の経路 + '）' } else { $summary }); 対象外 = $taigai.ContainsKey($id); 対象外の理由 = [string]$(if ($taigai.ContainsKey($id)) { $taigai[$id].理由 } else { '' }); 下書き可 = $(if ($taigai.ContainsKey($id)) { $false } else { (-not $why) }); 候補 = $cands; 倉庫の相殺 = @($c.倉庫の相殺); マネキン人数 = $(if ($spec -and $spec.マネキン手配済み -eq $true) { '手配済み（玉井さん）＝人数を出さない・熊田さんへの手配依頼も無し' } else { $c.マネキン人数 }); 品目 = $c.品目
        担当者の確認 = [ordered]@{ 答え = $kakunin; 修正リスト = $(if ($kk) { [string]$kk.修正リスト原文 } else { '' }); 修正の写真 = $(if ($kk) { @($kk.修正の写真) } else { @() }); 答えた日時 = $(if ($kk) { [string]$kk.答えた日時 } else { '' })
            反映 = [string]$c.修正の反映.状態; 直した品目 = @($c.修正の反映.直した品目); 反映できない理由 = @($c.修正の反映.できない理由); 文字の注文 = @(@($c.修正の反映.文字の注文) | Where-Object { $_ }) }   # 2026-09-30。2026-10-29 13枚目 文字の注文（発注ボードが熊田さんの画面・朝の知らせ・3日前の困りごとに出す）
        予定の直し = $c.予定の直し   # 2026-10-07 鍵を持つ人が窓で直した分（状態・直した・できない理由・一覧・取り消した）。画面が出す
        指紋 = $(if ($Test) { $(if ($ledger) { $ledger.指紋 } else { '' }) } else { $finger }); 更新 = (Get-Date -Format 'yyyy-MM-dd HH:mm'); 発注案 = $plan
    }
    if ($kieta.Count) { $doc.消えた相手の下書き = @($kieta) }   # 2026-10-09 マニュアル係⑩（上）
    if ($ledger -and $ledger.修正の扱い) { $doc.修正の扱い = $ledger.修正の扱い }   # 2026-10-31 草案（発注チェーンの点検・本番未投入） 項目5：board_action だけが書く。作り直しで消さない
    [IO.File]::WriteAllText($ledgerPath, ($doc | ConvertTo-Json -Depth 8), $utf8bom)
    $report += "$summary：$id $($j.会場) $($j.会期開始)〜$($j.会期終了) 予算$($j.売上予算) 型$($j.型) 担当$($j.担当者)（候補$($cands.Count)件）→ $ledgerPath"
    if ($j.束の案件ID) { $report += "  束：$(@($j.束の案件ID) -join ', ')（同じ催事＝発注は1回）" }
    } catch { $report += ('⚠ この予算ファイルで止まりました（ほかの催事は続けます）：' + $f.Name + ' ／ ' + $_.Exception.Message); continue }
}
if ($shukuKeikoku.Count -gt 0) { $report += ('⚠ 祝日の表（shukka-todo\out\祝日.json・最終年 ' + $shukuSaishu + '）に無い年の送る日があります＝土日だけで倒しました：' + (@($shukuKeikoku.Keys | Sort-Object | Select-Object -First 3) -join '・')) }
if (-not $report) { $report = @('新しい予算と型のファイルはありません') }
# 棚卸（在庫スワイプ棚卸し第2版の JSON）を発注案に書き足す（持ち込み・戻り・使った量・使った量の原価）
if (-not $Test) { & (Join-Path $PSScriptRoot 'add_usage_to_plans.ps1') | ForEach-Object { $report += "棚卸：$_" } }
# 2026-09-28 供給上限（仕組み\供給上限.json・値の正＝商品マスターの会話）。全部の台帳の品目を足し、上限を超えた品の注意を1つのファイルに出す。
#   機械で按分しない（玉井さんの判断待ち）。発注ボードはこのファイルを読んで画面に出す
$kyPath = Join-Path $PSScriptRoot '供給上限.json'
if (Test-Path $kyPath) {
    try {
        $ky = Get-Content $kyPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $sumRows = @()
        $hinTan = @{}; try { foreach ($hp in @((Get-Content (Join-Path $PSScriptRoot '品目.json') -Raw -Encoding UTF8 | ConvertFrom-Json).品目.PSObject.Properties)) { $hinTan[[string]$hp.Name] = $hp.Value.発注単位kg } } catch {}
        foreach ($pp in $ky.品目.PSObject.Properties) {
            $code = $pp.Name; $lim = $pp.Value
            $total = 0.0; $uchiwake = @()
            foreach ($lf in (Get-ChildItem $planDir -Filter '2026*.json' -ErrorAction SilentlyContinue)) {
                try { $ld = Get-Content $lf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
                $kgCase = 0.0; $hit = $false
                foreach ($im in @($ld.品目)) {
                    $c = [string]$(if ($im.品目コード) { $im.品目コード } else { $im.品目 })
                    if ($c -and $c.StartsWith($code)) {
                        $kg = 0.0; try { $kg = [double]([string]$(if ($null -ne $im.発注量kg) { $im.発注量kg } else { $im.kg }) -replace ',', '') } catch {}
                        $kgCase += $kg; $hit = $true
                    }
                }
                # 2026-10-09 商品マスターの指摘（K024）：送った相手の本文に「※棹前早煮昆布 15kg」のように人が読む行で入った分は、品目の kg が0のまま＝内訳が全部0kg に見えた。
                #   送った／電話した／現場が発注済み の相手の本文から、その品の kg を読む（c/s なら 品目.json の発注単位kg を掛ける）。品目の kg より大きければそちらを使い「送り済み」と印
                $kgSent = 0.0; $nm = [string]$lim.品名
                foreach ($cc in @($ld.候補)) {
                    if (-not $cc -or $cc.候補外 -eq $true -or [string]$cc.状態 -notmatch '^(送った|電話した|現場が発注済み)') { continue }
                    foreach ($part in ([string]$(if ($cc.中身全文) { $cc.中身全文 } else { $cc.中身 }) -split '／')) {
                        if (-not $nm -or -not $part.Contains($nm)) { continue }
                        if ($part -match '(\d+(?:\.\d+)?)\s*(kg|ｋｇ|㎏)') { $kgSent += [double]$Matches[1] }
                        elseif ($part -match '(\d+(?:\.\d+)?)\s*c/s') { $u = 0.0; try { $u = [double]$hinTan[$code] } catch {}; $kgSent += [double]$Matches[1] * $u }
                    }
                }
                # 2026-10-09 10代目ボスの裁定：現場が直接頼んだ分（予定の直し「もう頼んである」＝現場が発注済み）も送り済みに数える（事実の置き場は発注ボードの記録1か所）
                foreach ($nr in @($ld.予定の直し.一覧)) {
                    if ($nr -and [string]$nr.種別 -eq 'もう頼んである' -and ([string]$nr.行.品目コード).StartsWith($code)) { $v = 0.0; try { $v = [double]([string]$nr.行.発注量kg) } catch {}; $kgSent += $v }
                }
                if ($hit -or $kgSent -gt 0) {
                    $okutta = ($kgSent -gt $kgCase)
                    $kgUse = [math]::Max($kgCase, $kgSent)
                    $total += $kgUse
                    $uchiwake += [ordered]@{ 会場 = [string]$ld.会場; 会期開始 = [string]$ld.会期開始; kg = $kgUse; 案件ID = [string]$ld.案件ID; 送り済み = ($okutta -or $kgSent -gt 0) }
                }
            }
            # 2026-10-09 10代目ボスの裁定（K024）：発注ボードの台帳が無い催事（岡山高島屋など板の外）で同じ確保量から使った分も数える。
            #   置き場＝発注案\_板の外の使用.json の 行[]（品目コード・会場・会期開始・kg・出どころ・札）。書くのは発注ボードの会話だけ
            try {
                $sotoPath = Join-Path $planDir '_板の外の使用.json'
                if (Test-Path $sotoPath) {
                    foreach ($so in @((Get-Content $sotoPath -Raw -Encoding UTF8 | ConvertFrom-Json).行)) {
                        if (-not $so -or -not ([string]$so.品目コード).StartsWith($code)) { continue }
                        $v = 0.0; try { $v = [double]([string]$so.kg) } catch {}
                        $total += $v
                        $uchiwake += [ordered]@{ 会場 = [string]$so.会場 + '（板の外）'; 会期開始 = [string]$so.会期開始; kg = $v; 案件ID = ''; 送り済み = $true; 出どころ = ([string]$so.札 + ' ' + [string]$so.出どころ).Trim() }
                    }
                }
            } catch {}
            $fusoku = [math]::Round($total - [double]$lim.上限kg, 1)
            $sentKg = 0.0; foreach ($u in $uchiwake) { if ($u.送り済み) { $sentKg += [double]$u.kg } }
            $sumRows += [ordered]@{ 品目コード = $code; 品名 = [string]$lim.品名; 状態 = [string]$lim.状態; 上限kg = $lim.上限kg
                発注案の合計kg = [math]::Round($total, 1); 送り済みkg = [math]::Round($sentKg, 1); 残りkg = [math]::Round([double]$lim.上限kg - $total, 1); 不足kg = $(if ($fusoku -gt 0) { $fusoku } else { 0 })
                足りているか = $(if ($fusoku -gt 0) { '⚠ 足りません' } else { '足りています' })
                内訳 = @($uchiwake | Sort-Object { $_.会期開始 }); 割り振り = $lim.割り振り; 代わりの候補 = [string]$lim.代わりの候補; 出どころ = [string]$lim.出どころ }
        }
        $kyOut = [ordered]@{ 説明 = '今季の確保量に対して、発注案の合計が足りているか。値の正＝仕組み\供給上限.json（商品マスターの会話）。按分は機械でしない（玉井さんの判断）'; 更新 = (Get-Date -Format 'yyyy-MM-dd HH:mm'); 品目 = $sumRows }
        [IO.File]::WriteAllText((Join-Path $planDir '_供給の注意.json'), ($kyOut | ConvertTo-Json -Depth 8), $utf8bom)
        foreach ($r in $sumRows) { if ($r.不足kg -gt 0) { $report += ('⚠ ' + $r.品名 + '：確保 ' + $r.上限kg + 'kg に対して発注案の合計 ' + $r.発注案の合計kg + 'kg＝' + $r.不足kg + 'kg 足りません') } }
    } catch { $report += ('供給上限が読めませんでした：' + $_.Exception.Message) }
}
$log = Join-Path $planDir ('実行記録_' + (Get-Date -Format 'yyyyMMdd') + '.txt')
Add-Content -Path $log -Value ("==== " + (Get-Date -Format 'yyyy-MM-dd HH:mm') + $(if ($Test) { ' 試験' } else { '' })) -Encoding UTF8
Add-Content -Path $log -Value $report -Encoding UTF8
$report
