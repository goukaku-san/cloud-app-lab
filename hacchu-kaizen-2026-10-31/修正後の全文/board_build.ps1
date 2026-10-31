# 発注ボード（.hta）を台帳から書き出す。2026-09-18 蔵人（統合設計の会話・倉庫メインPC）
# 【このファイルの持ち主】発注ボード専用の会話（倉庫メインPC）。2026-09-23 に統合設計の会話と取り決めた暫定の分担。
#   ここ（board_build.ps1・board_action.ps1・発注ボードの画面）を直すのは、この会話だけ。
#   統合設計が持つのは process_budget_files.ps1・make_order_drafts.ps1・台帳（発注案）・納品指定・倉庫在庫と引当。
#   画面に出したい物があるときは、直接触らず発注ボードの会話へ依頼する。最後に決めるのは玉井さん。
# 出力：…\発注\発注ボード.hta（熊田さんが開く画面）。ボタンは run_guard.ps1 経由で board_action.ps1 を呼ぶ（時間切れつき）
param([string]$Config = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$planDir = Join-Path $root '発注案'
# このPCの中だけの覚え書き（どのタブを見ていたか・どこまでスクロールしたか・選んでいた現場）。
#   Gドライブに置くと2台で取り合うので、必ずこのPCの中に置く（2026-09-26）
$seenDir = Join-Path $env:LOCALAPPDATA 'HacchuBoard'
if (-not (Test-Path $seenDir)) { try { New-Item -ItemType Directory -Path $seenDir -Force | Out-Null } catch {} }
$out = Join-Path $root '発注ボード.hta'
if (-not $Config) { $Config = Join-Path $PSScriptRoot 'board_config.json' }
$cfg = Get-Content $Config -Raw -Encoding UTF8 | ConvertFrom-Json
$DONE = @('送った', '電話した', '不要', '倉庫から出した', '現場が発注済み')
# 2026-09-23 点検役（Fable 5.1）⛔1：下の4つは「送ったかもしれない」状態。ここから下書きを作ると2通目を送る道になるので、ボタンを出さない
$STUCK = @('送ったか確かめて', '⚠二重に送っています', '送信トレイで止まっています', '⚠古い中身で送っています')
. (Join-Path $PSScriptRoot 'genba_hantei.ps1')   # 2026-10-31 草案（発注チェーンの点検・本番未投入）：$GENBA_HOLD・Test-KaikiOwatta
function Genba-Hold-Btn([string]$s0, [string]$cid0, [string]$aid0, $c) {
    $hinG = (@(@($c.現場の照合.当たった品) | ForEach-Object { Esc ([string]$_.品) }) -join '・')
    if ($s0 -eq '一部は現場が発注済み') {
        return "<span class='m'>⚠ LINE で現場が頼んだ品があります（" + $hinG + "）。この行は下書きを作れません。済んだ品を［予定を直す窓］で「もう頼んである」にすると、残りの品だけ下書きにできます。数は確かめていません。</span><br><button onclick=""act('mark','$cid0','$aid0','現場が発注済み')"">全部 現場で発注済み</button><button onclick=""if(confirm('LINE の発注は、この行の品ではないとして下書きに戻します。前に頼んだ品と二重に頼まないよう、確かめてから押してください。'))act('mark','$cid0','$aid0','候補')"">この行の品は頼まれていない</button>"
    }
    return "<span class='m'>⚠ 現場の発注に取消・訂正が届きました（" + (Esc ([string]$c.現場の記録)) + "）。下書きは作れません。</span><br><button onclick=""act('mark','$cid0','$aid0','現場が発注済み')"">現場で発注済みのまま</button><button onclick=""if(confirm('現場の発注は取り消されたとして、下書きに戻します。'))act('mark','$cid0','$aid0','候補')"">頼み直す（下書きに戻す）</button>"
}
# 2026-10-08 穴21：止まっている4つの状態は、どれも［送れていた］［送れていない（やり直す）］の同じ2つだった＝⚠二重・⚠古い中身では何をすればよいか分からない。
#   状態ごとに「次にすること」1行と、それに合うボタンを出す。下書きを作り直すボタンは出さない（2通目の道をふさぐ・点検役⛔1のまま）
function Stuck-Btn([string]$s, [string]$cid, [string]$aid) {
    if ($s -eq '⚠二重に送っています') {
        return "<span class='m'>同じ発注の写しが2通以上あります。相手に<b>「1通分だけお願いします」</b>と電話かメールで伝えてください。</span><br>" +
            "<button class='p' onclick=""if(confirm('相手に「1通分だけ」と伝えましたか？（別々の発注だった時も、こちらを押します）'))act('mark','$cid','$aid','送った')"">相手に伝えた（1通分でよい）</button>"
    }
    if ($s -eq '⚠古い中身で送っています') {
        return "<span class='m'>直す前の数で送っています。相手に<b>今の数</b>（下の中身）を電話かメールで伝えてください。</span><br>" +
            "<button class='p' onclick=""if(confirm('相手に今の数を伝えましたか？'))act('mark','$cid','$aid','送った')"">相手に今の数を伝えた</button>"
    }
    return "<button class='p' onclick=""act('mark','$cid','$aid','送った')"">送れていた</button><button onclick=""act('mark','$cid','$aid','候補')"">送れていない（やり直す）</button>"
}
# 2026-10-08 玉井さん（7代目ボス経由）：倉庫出しの「出す人」の既定＝担当者が自分で持っていく（通える範囲）。担当者に「寄れますか」とは聞かない。
#   倉庫（玉井さん・熊田さん）が発送するのは ①担当者の拠点が遠い（担当者.json の 拠点.遠い）②会期途中の追加 ③前の催事から移動日が無い、の3つだけ。
#   ②は台帳に印が無いので、AIかおりの答え（記録\倉庫出し_出す人.json・足すだけ・key ごとに最後の行が正）があればそれを優先する。ボードは読むだけ
$kyotenMap = @{}
try { $tj = Get-Content (Join-Path $PSScriptRoot '担当者.json') -Raw -Encoding UTF8 | ConvertFrom-Json; foreach ($pp in @($tj.拠点.PSObject.Properties)) { if ($pp.Value -is [string]) { continue }; $kyotenMap[[string]$pp.Name] = $pp.Value } } catch {}
$dasuAns = @{}
$dasuP = Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) '記録') '倉庫出し_出す人.json'
if (Test-Path $dasuP) {
    try {
        $dj = Get-Content $dasuP -Raw -Encoding UTF8 | ConvertFrom-Json
        $rows = @($(if ($dj -is [array]) { $dj } elseif ($dj.行) { $dj.行 } elseif ($dj.答え) { $dj.答え } else { @() }))
        foreach ($r in $rows) { $k = [string]$(if ($r.key) { $r.key } elseif ($r.鍵) { $r.鍵 } else { $r.案件ID }); if ($k) { $dasuAns[($k -split '\|')[0]] = $r } }   # 後の行が勝つ
    } catch {}
}
function Dasu-Hito($d, $all) {
    $tan = [string]$d.担当者; $id = [string]$d.案件ID
    if ($dasuKime -and $dasuKime.ContainsKey($id)) { $k = $dasuKime[$id]; return @{ 出す人 = [string]$k.出す人; 理由 = ([string]$k.理由 + '（' + [string]$k.決めた日時 + '）') } }
    if ($dasuAns.ContainsKey($id)) { $r = $dasuAns[$id]; $v = [string]$(if ($r.出す人) { $r.出す人 } elseif ($r.答え) { $r.答え } else { ($r | ConvertTo-Json -Compress) }); return @{ 出す人 = $v; 理由 = ('AIかおりの答え' + $(if ($r.日時) { '（' + [string]$r.日時 + '）' } else { '' })) } }
    $riyu = @()
    $ky = $kyotenMap[$tan]
    if ($ky -and $ky.遠い -eq $true) { $riyu += ('担当者の拠点が遠い（' + [string]$ky.拠点 + '）') }
    foreach ($o in @($all)) {
        if ([string]$o.案件ID -eq $id -or [string]$o.担当者 -ne $tan) { continue }
        try { if (([datetime]$o.会期終了) -ge ([datetime]$d.会期開始).AddDays(-1) -and ([datetime]$o.会期開始) -lt [datetime]$d.会期開始) { $riyu += ('前の催事（' + [string]$o.会場 + ' 〜' + [string]$o.会期終了 + '）から移動日が無い') } } catch {}
    }
    if ($riyu.Count) { return @{ 出す人 = '倉庫（玉井さん・熊田さん）が発送'; 理由 = ($riyu -join '／') } }
    # 2026-10-12 ①③に当たらない時は、台帳の出す人（process_budget_files が宿泊手当の前例で決めた＝★10/11）を使う。前例の説明はそのまま出す
    $sr = @($d.候補) | Where-Object { $_ -and $_.方法 -eq '倉庫出し' -and $_.候補外 -ne $true } | Select-Object -First 1
    if ($sr -and [string]$sr.出す人 -eq '熊田かおり' -and [string]$sr.出す人の説明) { return @{ 出す人 = '倉庫（玉井さん・熊田さん）が発送'; 理由 = [string]$sr.出す人の説明 } }
    if ($sr -and [string]$sr.出す人の説明 -like '*前例*') { return @{ 出す人 = ($tan + 'さんが自分で持っていく'); 理由 = [string]$sr.出す人の説明 } }
    return @{ 出す人 = ($tan + 'さんが自分で持っていく'); 理由 = ('既定＝通える範囲は担当者が自分で持っていく（玉井さん 10/8）' + $(if (-not $ky) { '。拠点が 担当者.json に無い＝遠いかどうかは未判定' } else { '' })) }
}
function Esc([string]$s) { return [Net.WebUtility]::HtmlEncode($s) }
$script:tgN = 0
function Tg([string]$label, [string]$inner, [bool]$open = $false) {
    $script:tgN++; $tid = 'tg' + $script:tgN
    return "<a href='#' class='tgl' onclick=""var e=document.getElementById('$tid');e.style.display=(e.style.display=='none')?'block':'none';return false;"">" + $label + "</a><div id='$tid' style='display:" + $(if ($open) { 'block' } else { 'none' }) + "'>" + $inner + "</div>"
}
# 2026-10-23 A群 F16（24代目ボス裁定 10/22「注記の内輪語を出さない」＝見せ方）：熊田さんの画面に出す文から、内輪の呼び名（○代目ボス・蔵人（会話名）・AIかおり 28・D1・機械の時刻・ファイルのパス）を平たくする。元の記録の文は変えない（★9/30 理由は言い換えない＝表示だけ）
function Hira([string]$s) {
    if (-not $s) { return '' }
    $s = [regex]::Replace($s, 'ボス（\d+代目[^（）]*）', '発注の仕組み')
    $s = [regex]::Replace($s, '(統合設計)?\d+代目ボス(の会話で直接|の会話|の裁定|の指示|経由)?', '発注の仕組み')
    $s = $s.Replace('玉井さんか蔵人に', '玉井さんに')
    $s = [regex]::Replace($s, '蔵人（[^（）]*）', '発注の仕組み')
    $s = $s.Replace('蔵人運用\', '').Replace('蔵人', '発注の仕組み')
    $s = [regex]::Replace($s, 'AIかおり\s*(fork\s*)?\d+(\s*続き)?', 'AIかおり')
    $s = [regex]::Replace($s, '(?<![A-Za-z])D1(?![A-Za-z0-9])', '記録')
    $s = [regex]::Replace($s, '(\d{4}-\d\d-\d\d)T(\d\d:\d\d)(:\d\d(\.\d+)?)?Z', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) try { ([datetime]::Parse($m.Groups[1].Value + 'T' + $m.Groups[2].Value + ':00Z', $null, [Globalization.DateTimeStyles]::AdjustToUniversal)).ToLocalTime().ToString('yyyy-MM-dd HH:mm') } catch { $m.Groups[1].Value + ' ' + $m.Groups[2].Value } })
    $s = [regex]::Replace($s, '(\d{4}-\d\d-\d\d)T(\d\d:\d\d)(:\d\d(\.\d+)?)?(\+09:00)?', '$1 $2')
    $s = [regex]::Replace($s, '[A-Za-z]:\\(?:[^\\\s、。（）「」／]+\\)*([^\\\s、。（）「」／]+)', '$1')
    return $s
}
# 2026-10-23 A群 F17：kg の丸め（26.999999999999996kg → 27kg）。数でない物はそのまま
function KgFmt($v) {
    $x = 0.0
    if ([double]::TryParse([string]$v, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$x)) { return [string]([math]::Round($x, 2)) }
    return [string]$v
}
# 2026-10-23 A群 F8（24代目ボス裁定「消さず言い換えず表示で畳む」）：行の止め金の札は短く、長い理由は［くわしく］の中へ。止め金.json の文は変えない
function Tome-Fuda($d, $c) {
    $t = $null
    if ($tomekin) { $t = @($tomekin.止め金) | Where-Object { $_ -and [string]$_.案件ID -eq [string]$d.案件ID -and [string]$_.相手 -eq [string]$c.相手 } | Select-Object -First 1 }
    if (-not $t) { return "<span class='pill ng'>" + (Esc ([string]$c.止め金)) + "</span>" }
    $itsu = $(if ([string]$t.期限) { '期限 ' + [string]$t.期限 } else { '見直す日 ' + [string]$t.見直す日 })
    $fuda = $(if (([string]$t.戻す条件).StartsWith('外さない')) { '玉井さんの決定で送りません' } else { '送らないでください' })
    return "<span class='pill ng'>" + (Esc ($fuda + '（' + $itsu + '）')) + "</span> " + (Tg '［くわしく］' ("<span class='m'>理由：" + (Esc (Hira ([string]$t.理由))) + "</span>"))
}
# 2026-10-23 A群 F8・F16：困りごとの中身の「・理由＝…」は［くわしく］に畳む（文は変えない）。内輪の呼び名は Hira で平たく
function Nakami-Html([string]$s) {
    $s = Hira $s
    $i = $s.IndexOf('・理由＝')
    if ($i -gt 0) { return (Esc $s.Substring(0, $i)) + ' ' + (Tg '［くわしく］' ("<span class='m'>" + (Esc $s.Substring($i + 1)) + "</span>")) }
    return (Esc $s)
}
# 2026-09-23 点検役：画面の言葉をやさしくする（中の名前は変えない。見せ方だけ）
#   「候補」＝まだ送っていない／「要項待ち（納品指定フォルダに…）」＝ファイル名は熊田さんには読めない
function Moto-Yomiyasuku {
    # 2026-09-30：引き当ての「元」は案件ID（20260916-田中-あべのハルカ）や『起点20260916福屋』。
    #   熊田さんが読める形にする。読めない形はそのまま出す（勝手に捨てない）
    param([string]$id)
    if (-not $id) { return '' }
    $m = [regex]::Match($id, '^(?<ki>起点)?(?<y>20[0-9]{2})(?<mo>[0-9]{2})(?<d>[0-9]{2})-?(?<nokori>.*)$')
    if (-not $m.Success) { return $id }
    $tuki = [int]$m.Groups['mo'].Value; $hi = [int]$m.Groups['d'].Value
    $nokori = [string]$m.Groups['nokori'].Value
    $tantou = ''
    $p = $nokori.Split('-')
    if ($p.Count -ge 2) { $tantou = $p[0] + 'さん'; $nokori = ($p[1..($p.Count-1)] -join '-') }
    $atama = $(if ($m.Groups['ki'].Success) { '起点' } else { '' })
    return ($atama + [string]$tuki + '/' + [string]$hi + ' ' + $nokori + $(if ($tantou) { '（' + $tantou + '）' } else { '' }))
}

function Kaijo-Onaji {
    # 2026-10-01：LINEの会場名と台帳の会場名は書き方が違う（『阪神梅田本店 北海道展』と『阪神百貨店梅田本店』）。
    #   『百貨店』『本店』『店』『空白』を落としてから、どちらかがどちらかを含むかで見る。
    #   ゆるめに合わせるのは「依頼の警告」だけ。『発注完了』の判定は厳しいままにする
    #   （間違って『もう送った』と見なすと、二重発注を見逃すため）
    param([string]$a, [string]$b)
    if (-not $a -or -not $b) { return $false }
    if ($a -eq $b) { return $true }
    $f = { param($x) ($x -replace '百貨店|本店|支店|店|　| ', '') }
    $x = & $f $a; $y = & $f $b
    if (-not $x -or -not $y) { return $false }
    return ($x.Contains($y) -or $y.Contains($x))
}

function Yasashiku([string]$t) {
    if (-not $t) { return '' }
    $t = [regex]::Replace($t, '（納品指定フォルダに[^）]*）', '')
    $t = $t.Replace('要項待ち', '納品先の決まり待ち')
    # 2026-09-26 Gemini：熊田かおりさんが読むと『AIかおりの確認がまだ』＝自分が責められていると感じる
    $t = $t.Replace('担当者のOK待ち（AIかおりの確認がまだ）', '担当者の返事待ち')
    $t = $t.Replace('（AIかおりの確認がまだ）', '（AIかおりからの質問がまだ出ていません）')
    $t = $t.Replace('担当者のOK待ち', '担当者の返事待ち')
    if ($t -eq '候補') { return 'まだ送っていません' }
    return $t
}
function Hex([string]$s) { return (([Text.Encoding]::UTF8.GetBytes($s)) | ForEach-Object { $_.ToString('x2') }) -join '' }
$cases = @()
foreach ($f in (Get-ChildItem $planDir -Filter *.json -ErrorAction SilentlyContinue | Where-Object { $_.BaseName -notlike '_*' })) {
    try { $d = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
    if (-not $d.案件ID) { continue }
    $cases += $d
}
# 2026-10-01 止め金（仕組み\止め金.json）：期限の内側だけ「送らないでください」を出し、下書きのボタンを消す。
#   台帳は書き換えない（画面の中だけ 下書き可＝false に見せる）。期限を過ぎたら何もしなくても元に戻る。理由は言い換えない
$tomekin = $null
try { $tomekin = Get-Content (Join-Path $PSScriptRoot '止め金.json') -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
if ($tomekin) {
    foreach ($t in @($tomekin.止め金)) {
        # 期限あり＝その時刻を過ぎたら自動で外れる／期限なし＝外すまで止めたまま（そのときは「見直す日」を必ず書いて画面に出す）
        $kigen = $null; try { if ([string]$t.期限) { $kigen = [datetime][string]$t.期限 } } catch {}
        if ($kigen -and (Get-Date) -ge $kigen) { continue }
        if (-not $kigen -and -not [string]$t.見直す日) { continue }
        $itsu = $(if ($kigen) { $kigen.ToString('M/d H:mm') + ' まで' } else { '見直す日 ' + [string]$t.見直す日 })
        $moji = '送らないでください：' + [string]$t.理由 + '（' + $itsu + '）'
        foreach ($d in @($cases | Where-Object { [string]$_.案件ID -eq [string]$t.案件ID })) {
            if ([string]$t.相手) {
                # 相手を1つだけ止める（ほかの相手は送れる）。行に印を付けるだけで、催事ぜんたいは止めない
                foreach ($c in @($d.候補 | Where-Object { [string]$_.相手 -eq [string]$t.相手 })) { $c | Add-Member -NotePropertyName 止め金 -NotePropertyValue $moji -Force }
            } else {
                $d.下書き可 = $false
                $d.状態 = $moji
            }
        }
    }
}
# 2026-10-09 調査（10代目ボス）：止め金の「見直す日」「戻す条件」を読む所が無かった＝外すまで永久。見直す日を過ぎた止め金を画面の上に出す（外すのは人＝発注ボードの会話へ）
$tomeLate = @(); if ($tomekin) { foreach ($t in @($tomekin.止め金)) { if (-not $t -or [string]$t.期限) { continue }; $mi0 = [string]$t.見直す日; if ($mi0 -and $mi0 -lt (Get-Date -Format 'yyyy-MM-dd')) { $tomeLate += ([string]$t.案件ID + $(if ([string]$t.相手) { '・' + [string]$t.相手 } else { '' }) + '：見直す日 ' + $mi0 + ' を過ぎています。戻す条件＝' + [string]$t.戻す条件 + '（理由：' + [string]$t.理由 + '）') } } }
# 2026-10-09 夜 11代目ボス：見直す日を過ぎた止め金は 発注案\_仕組みの困りごと.json の1か所にだけ書く（見える化 mieru_build もそちらを読む＝ページ版17）。_止め金の見直し.json は書かない
$cases = $cases | Sort-Object { [string]$_.会期開始 }
# 2026-10-09 人が決めた倉庫出しの出す人（仕組み\倉庫出しの出す人.json）：画面の上だけで送る日を置き換える（台帳は書き換えない）。例＝阪神1週目は尾崎さんが車で持ち込み（玉井さん 10/9 夜）
$dasuKime = @{}
try { foreach ($k in @((Get-Content (Join-Path $PSScriptRoot '倉庫出しの出す人.json') -Raw -Encoding UTF8 | ConvertFrom-Json).決め)) { if ($k -and $k.案件ID) { $dasuKime[[string]$k.案件ID] = $k } } } catch {}
foreach ($d in $cases) { $k = $dasuKime[[string]$d.案件ID]; if (-not $k -or -not [string]$k.送る日) { continue }; foreach ($c in @($d.候補)) { if ($c -and $c.方法 -eq '倉庫出し') { $c.送る日 = [string]$k.送る日 } } }
# 2026-09-22 玉井さん：ロットで仕入れる原料（セニヤに預けるバルク・倉庫に置く品）は発注点（ロットの1/3）で補充。補充は熊田さんの判断で出す
#   材料：セニヤ在庫表\原料在庫_推定.json（seniya_gyakusan.py が書く）／仕組み\セニヤ預けバルク.json／仕組み\倉庫ストック品.json
$hj = New-Object Text.StringBuilder
$hj2 = New-Object Text.StringBuilder   # 2026-10-20 くわしい表の中へ畳む物（補充・仕組みの困りごと・ボード外）
# 注意：関数名を「Rd」にすると PowerShell の既定の別名 rd（Remove-Item）が先に効き、読むはずのファイルを消す（2026-09-22 実際に3ファイル消えた）
function Read-JsonFile($p) { if (Test-Path $p) { try { return (Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json) } catch {} }; return $null }
$est = Read-JsonFile (Join-Path $root 'セニヤ在庫表\原料在庫_推定.json'); $bulk = Read-JsonFile (Join-Path $PSScriptRoot 'セニヤ預けバルク.json'); $stock = Read-JsonFile (Join-Path $PSScriptRoot '倉庫ストック品.json')
$zaikoLot = Read-JsonFile (Join-Path $root '倉庫在庫.json')
. (Join-Path $PSScriptRoot 'board_manq.ps1')   # 2026-10-09 マネキン（電話）の行（14-24）
$hrows = @()
if ($est -and $bulk) {
    foreach ($p in $est.品目.PSObject.Properties) {
        $v = $p.Value; $b = $bulk.品目.($p.Name)
        if (-not $b -or $b.発注点の対象 -eq $false -or $v.判定 -ne '発注の時期') { continue }
        $hrows += "<tr><td>セニヤに預けている原料</td><td><b>" + (Esc $p.Name) + "</b></td><td>" + (Esc ([string]$b.原料の仕入先)) + "</td><td>" + (Esc ([string]$b.ロットkg)) + "kg</td><td>" + (Esc ([string]$v.発注点kg)) + "kg</td><td>表 " + (Esc ([string]$v.表の当日残kg)) + "kg（" + (Esc ([string]$est.表の日付)) + "）→ 予定まで引くと " + $(if ([double]$v.予定まで引いた残りkg -lt 0) { "<b>足りません（" + [math]::Round([math]::Abs([double]$v.予定まで引いた残りkg), 1) + "kg 不足）</b>" } else { (Esc ([string]$v.予定まで引いた残りkg)) + "kg" }) + "</td><td>" + (Esc ([string]$b.ロットの注)) + "</td></tr>"
    }
}
if ($stock) {
    foreach ($p in $stock.品目.PSObject.Properties) {
        # 2026-10-09 在庫の会話の依頼（設計 柱4-1）：倉庫の数は倉庫在庫.json の「今」（〈コード〉-01＝1kg袋）を読む。倉庫ストック品.json は ロットkg・発注点・1ケースkg の決めだけ
        $b = $p.Value; $zi = $(if ($zaikoLot -and $zaikoLot.品目) { $zaikoLot.品目.($p.Name + '-01') } else { $null })
        if ($zi -and $zi.引当に使える -eq $false) { $now = 0 }   # 2026-10-19 在庫の依頼（追09）：引当に使える=false は今を0と見る
        elseif ($zi -and $null -ne $zi.今) { $now = [double]$zi.今 } else { $now = [double]$stock.起点.在庫kg.($p.Name); foreach ($m in @($stock.動き)) { if ($m.品目コード -eq $p.Name) { $now += [double]$m.kg } } }   # 読めない時だけ古い起点＋動き
        # まだ倉庫から出していない「倉庫出し」の候補＝予定として引く（2026-09-22）
        $names = @([string]$b.品名) + $(if ($p.Name -eq 'K015') { @('しそ味ひじき') } else { @() }); $yotei = 0.0
        # 2026-10-06 ロット品は袋（1kg）で出す＝字は「Nkg（1kg×N袋）」。古い「Nc/s」は N×1ケースkg。中身は「…」で切れるので中身全文を読む
        $ck = [double]$b.'1ケースkg'; if ($ck -le 0) { $ck = [double]$b.最小単位kg }
        foreach ($dd in $cases) { foreach ($cc in @($dd.候補)) { if ($cc.方法 -ne '倉庫出し' -or $DONE -contains [string]$cc.状態 -or $cc.候補外 -eq $true) { continue }; $zen = $(if ([string]$cc.中身全文) { [string]$cc.中身全文 } else { [string]$cc.中身 }); foreach ($part in ($zen -split '／')) { if (@($names | Where-Object { $part.Contains($_) }).Count) { if ($part -match '(\d+(?:\.\d+)?)\s*kg（1kg') { $yotei += [double]$Matches[1] } elseif ($part -match '(\d+(?:\.\d+)?)\s*c/s') { $yotei += [double]$Matches[1] * $ck } } } } }
        $after = $now - $yotei
        if ($after -gt [double]$b.発注点kg) { continue }
        $hrows += "<tr><td>倉庫に置く品</td><td><b>" + (Esc $b.品名) + "</b></td><td></td><td>" + (Esc ([string]$b.ロットkg)) + "kg</td><td>" + (Esc ([string]$b.発注点kg)) + "kg</td><td>倉庫 " + $now + "kg → 予定まで引くと " + $(if ($after -lt 0) { "<b>足りません（" + [math]::Round([math]::Abs($after), 1) + "kg 不足）</b>" } else { [string]$after + "kg" }) + "</td><td>" + (Esc ([string]$b.ロットの注)) + "</td></tr>"
    }
}
# 2026-09-26 点検役14：元の数字（セニヤの表）が古くても、そう見えない。7日より古ければそう書く
$estFurui = $false
if ($est -and $est.表の日付) { try { $estFurui = (((Get-Date) - [datetime]$est.表の日付).Days -ge 7) } catch {} }
[void]$hj2.Append("<div class='sec' style='margin-bottom:10px'><div class='head'><div class='v'>補充の時期の原料（残りがロットの1/3以下）</div><span class='pill " + $(if ($hrows.Count) { 'ng' } else { 'ok' }) + "'>" + $(if ($hrows.Count) { "$($hrows.Count)品" } else { 'なし' }) + "</span></div>")
if ($hrows.Count) { [void]$hj2.Append("<table><tr><th>種類</th><th>品目</th><th>仕入先</th><th>1回の量</th><th>発注点</th><th>残り</th><th>頼み方のメモ</th></tr>" + ($hrows -join '') + "</table><div class='m'>補充は熊田さんの判断で出してください（催事の担当者のOKは要りません）。「予定まで引くと」は、ボードに載っているこれからの催事の分まで引いた見込みです。</div>" + $(if ($estFurui) { "<div class='note'>⚠ セニヤの原料の表は <b>" + (Esc ([string]$est.表の日付)) + "</b> のものです（7日以上前）。<b>この数字はもう合っていない可能性があります。</b>頼む前にセニヤへ今の残りを聞いてください。</div>" } else { '' }) + "") }
[void]$hj2.Append("</div>")
# 2026-10-09 夜：見直す日を過ぎた止め金の帯は「仕組みの困りごと」の帯に入った（同じ物を2か所に出さない）
# 2026-10-09 マニュアル係④⑥⑦：仕組みが止まった所を1か所（発注案\_仕組みの困りごと.json）に集める。board_action.ps1 が押した時の止まりを書き、ここは
#   ①今の台帳から分かる止まり（見直す日を過ぎた止め金・担当者の直しを反映できない・予定の直しを反映できない）を足し ②直った物を「済」にし ③上に出す。
#   熊田さんには「すること」だけを出す（直すのは発注ボードの会話・玉井さんへの知らせはこの一覧を読む側＝AIかおり）
$kmPath = Join-Path (Split-Path $PSScriptRoot -Parent) '発注案\_仕組みの困りごと.json'
$kmRows = @(); try { if (Test-Path $kmPath) { $kmRows = @((Get-Content $kmPath -Raw -Encoding UTF8 | ConvertFrom-Json).行 | Where-Object { $_ }) } } catch { $kmRows = @() }
$kmNow = Get-Date -Format 'yyyy-MM-dd HH:mm'; $kmIma = [ordered]@{}
foreach ($t in @($tomekin.止め金)) { if (-not $t -or [string]$t.期限) { continue }; $mi0 = [string]$t.見直す日; if ($mi0 -and $mi0 -lt (Get-Date -Format 'yyyy-MM-dd')) { $kmIma[('止め金の見直す日を過ぎた|' + [string]$t.案件ID + '|' + [string]$t.相手)] = [ordered]@{ 何が = '止め金の見直す日を過ぎた'; 案件ID = [string]$t.案件ID; 相手 = [string]$t.相手; 中身 = ('見直す日 ' + $mi0 + '・戻す条件＝' + [string]$t.戻す条件 + '・理由＝' + [string]$t.理由) } } }
foreach ($dk in $cases) {
    # 2026-10-12 ★10/11「確認後は数字を変えない」：答えが OK でも確認の数を当てる（make_order_drafts）。当てられない時は「担当者が確認した数を当てられない」で載せる（マニュアル係 続き6）
    if ($dk.担当者の確認 -and [string]$dk.担当者の確認.反映 -eq '反映できない') { $kmNani = $(if ([string]$dk.担当者の確認.答え -eq 'OK') { '担当者が確認した数を当てられない' } else { '担当者の直しを反映できない' }); $kmIma[($kmNani + '|' + [string]$dk.案件ID + '|')] = [ordered]@{ 何が = $kmNani; 案件ID = [string]$dk.案件ID; 相手 = ''; 中身 = ((@($dk.担当者の確認.反映できない理由) | Select-Object -First 3) -join ' / ') } }
    if ($dk.予定の直し -and [string]$dk.予定の直し.状態 -eq '反映できない') { $kmIma[('予定の直しを反映できない|' + [string]$dk.案件ID + '|')] = [ordered]@{ 何が = '予定の直しを反映できない'; 案件ID = [string]$dk.案件ID; 相手 = ''; 中身 = ((@($dk.予定の直し.できない理由) | Select-Object -First 3) -join ' / ') } }
}
# 2026-10-16 14代目ボスの依頼（第12版 地図「止まった物」）：見張り（蔵人運用\genzaichi\mihari.py・ボス）の入口 記録\見張り_止まった物.json の「未」を取り込む。
#   鍵はそのまま・日時は見張りが最初に見た日時（LINE の知らせの鍵＝鍵|日時 が動かないように）・対象は案件IDの欄へ。見張りで「済」・行が消えた＝ここも「済」。入口が読めない時は見張りの行に触らない
$mhOk = $false; $mhPath = Join-Path (Split-Path $PSScriptRoot -Parent) '記録\見張り_止まった物.json'
try { if (Test-Path $mhPath) { $mhRows = @((Get-Content $mhPath -Raw -Encoding UTF8 | ConvertFrom-Json).行 | Where-Object { $_ }); $mhOk = $true } } catch { $mhOk = $false }
if ($mhOk) { foreach ($m in $mhRows) { if ([string]$m.状態 -ne '未' -or -not [string]$m.鍵) { continue }; $kmIma[[string]$m.鍵] = [ordered]@{ 何が = [string]$m.何が; 案件ID = [string]$m.対象; 相手 = ''; 中身 = [string]$m.中身; 出どころ = '見張り'; 日時 = [string]$m.日時; 直す人 = [string]$m.直す人 } } }
# 2026-10-17 16代目ボスの裁定（最短の手 手1②）：AIかおりの入口 発注案\_AIかおりの止まった物.json（kumada_sync.py・30分ごと・鍵の頭 AIかおり|）の「未」も見張りと同じ道で取り込む。鍵そのまま・日時は入口の日時・直す人 AIかおり・出どころ AIかおり。入口が無い・読めない間は触らない
$akOk = $false; $akPath = Join-Path (Split-Path $PSScriptRoot -Parent) '発注案\_AIかおりの止まった物.json'
try { if (Test-Path $akPath) { $akRows = @((Get-Content $akPath -Raw -Encoding UTF8 | ConvertFrom-Json).行 | Where-Object { $_ }); $akOk = $true } } catch { $akOk = $false }
if ($akOk) { foreach ($m in $akRows) { if ([string]$m.状態 -ne '未' -or -not [string]$m.鍵) { continue }; $kmIma[[string]$m.鍵] = [ordered]@{ 何が = [string]$m.何が; 案件ID = [string]$m.案件ID; 相手 = [string]$m.相手; 中身 = ([string]$m.中身 + $(if ([string]$m.直し方) { '／直し方：' + [string]$m.直し方 } else { '' })); 出どころ = 'AIかおり'; 日時 = [string]$m.日時; 直す人 = 'AIかおり' } } }
# 2026-10-23 b5・b8（玉井さんのハンコ・埋めた形の確認 https://claude.ai/artifact/D5Y9VGEFnJuN3B1su2h3Pw の b5 10/22 11:59・b8「1」10/22 03:43）：
#   送る日まで3日以内か過ぎたのに、まだ下書きが無い（状態＝候補）行のある催事を、催事ごとに1行。止め金の行・催事ごと止めた催事・対象外・候補外は出さない。
#   鍵に段（3日前／当日）を入れる＝玉井さんのLINE（kumada_sync→Worker は新しい鍵だけ1回）は同じ催事に2回だけ。画面の欄には条件が続く限り毎回出す（b8・機械は数を確定しない）。
#   AIかおりの期限超えの知らせ（orderConfirm.ts planDeadline＝会期の10日前と最初の送る日の前日の早い方・その翌朝9時に1回・担当者の答えが無い件だけ）が同じ朝に出る催事は、行に「LINEに出さない」（読むのは kumada_sync＝AIかおりの持ち場）
$b5Tdy = (Get-Date).Date
foreach ($dk in $cases) {
    if ($dk.対象外 -eq $true -or ([string]$dk.状態).StartsWith('送らないでください')) { continue }
    $b5Rows = @(); $b5Min = $null
    foreach ($c in @($dk.候補)) {
        if (-not $c -or $c.候補外 -eq $true -or $c.止め金 -or [string]$c.状態 -ne '候補') { continue }
        # 2026-10-24 25代目ボス（3体の点検）：倉庫出しの行はメールの下書きを作らない＝「下書きが無い」に数えない（出す日の知らせは出荷の板が出す・16代目の裁定 手1③と同じ考え）。数えると玉井さんの LINE へ3日前と当日に誤報
        if ([string]$c.方法 -eq '倉庫出し') { continue }
        $sd = $null; try { $sd = ([datetime][string]$c.送る日).Date } catch { continue }
        if (($sd - $b5Tdy).Days -gt 3) { continue }
        $b5Rows += $c; if ($null -eq $b5Min -or $sd -lt $b5Min) { $b5Min = $sd }
    }
    if (-not $b5Rows.Count) { continue }
    $b5n = ($b5Min - $b5Tdy).Days
    $b5Dan = $(if ($b5n -le 0) { '当日' } else { '3日前' })
    $b5When = $(if ($b5n -eq 0) { '今日' } elseif ($b5n -gt 0) { 'あと' + $b5n + '日' } else { [string](-$b5n) + '日過ぎ' })
    $b5k = $dk.担当者の確認; $b5Ans = ($b5k -and [string]$b5k.答え)
    $b5Kak = $(if ($b5Ans) { '担当者の答え＝' + [string]$b5k.答え + $(if (([string]$b5k.答えた日時).Length -ge 16) { '（' + ([string]$b5k.答えた日時).Substring(5, 11).Replace('T', ' ').Replace('-', '/') + '）' } else { '' }) } else { '担当者の答え待ち' })
    $b5Hou = @($b5Rows | Where-Object { [string]$_.LINEで報告あり }).Count
    $b5v = [ordered]@{ 何が = '送る日が近いのに下書きが無い'; 案件ID = [string]$dk.案件ID; 相手 = ''; 直す人 = '玉井さん'
        中身 = ('送る日 ' + $b5Min.ToString('M/d') + '（' + $b5When + '）／まだ下書きが無い ' + $b5Rows.Count + '行：' + ((@($b5Rows | ForEach-Object { [string]$_.相手 })) -join '・') + '／' + $b5Kak + $(if ($b5Hou) { '／LINEで報告あり ' + $b5Hou + '行（出したかの確かめ待ち）' } else { '' })) }
    if (-not $b5Ans) {
        try { $b5St = ([datetime][string]$dk.会期開始).Date.AddDays(-10); $b5Fs = $(if ([string]$dk.いちばん早い送る日) { ([datetime][string]$dk.いちばん早い送る日).Date.AddDays(-1) } else { $b5St }); $b5Dl = $(if ($b5Fs -lt $b5St) { $b5Fs } else { $b5St }); if ($b5Dl.AddDays(1) -eq $b5Tdy) { $b5v.LINEに出さない = '同じ朝に AIかおりの期限超えの知らせ' } } catch {}
    }
    $kmIma[('送る日が近いのに下書きが無い|' + [string]$dk.案件ID + '|' + $b5Dan)] = $b5v
}
# 2026-10-29 13枚目（玉井さん 21:35 ハンコ・確認画面 h13）：担当者が文字で書いた注文で下書きに入れられない行（と、文字や写真だけの答え）＝台帳 担当者の確認.文字の注文。
#   催事は止めない。熊田さんの画面（確かめること・催事の欄）と朝8時の知らせに1行。頼む先は熊田さんが決めて「予定を直す」窓で入れ、［決めた］で閉じる（lineok の鍵「文字の注文|〈案件ID〉|〈字の指紋〉」）。
#   ②決めないまま送る日（その催事のいちばん早い送る日）の3日前になったら、玉井さんの画面（困りごと）と LINE に1行（b5 と同じ道・鍵は1つ＝LINE は1回）
function Mj-Key($dk, $m) { $md5 = [Security.Cryptography.MD5]::Create(); $h = (($md5.ComputeHash([Text.Encoding]::UTF8.GetBytes([string]$m.字)) | Select-Object -First 6 | ForEach-Object { $_.ToString('x2') }) -join ''); return ('文字の注文|' + [string]$dk.案件ID + '|' + $h) }
$mjOK = @(); $mjOKf = Read-JsonFile (Join-Path $planDir '_LINE依頼の確認済み.json'); if ($mjOKf) { $mjOK = @(@($mjOKf.確認済み) | ForEach-Object { [string]$_.鍵 }) }
function Mj-Ji($m) { $s = ([string]$m.字 -replace '\s+', ' ').Trim(); if ($s.Length -gt 60) { $s = $s.Substring(0, 60) + '…（続きは台帳）' }; return $s }
function Mj-Dake($m) { return ([string]$m.理由).StartsWith('文字だけの答え') }
function Mj-Deru($dk) { return -not ($dk.対象外 -eq $true -or ([string]$dk.状態).StartsWith('送らないでください') -or $dk.下書き可 -ne $true) }   # 止め金・答え待ちなど下書き可でない催事は熊田さんの番ではない（朝の知らせ・b5 と同じ）
function Mj-Rows($dk) { if (-not $dk.担当者の確認) { return @() }; return @(@($dk.担当者の確認.文字の注文) | Where-Object { $_ -and ($mjOK -notcontains (Mj-Key $dk $_)) }) }
foreach ($dk in $cases) {
    if (-not (Mj-Deru $dk)) { continue }
    $mjR = @(Mj-Rows $dk); if (-not $mjR.Count) { continue }
    $mjSd = $null; try { $mjSd = ([datetime][string]$dk.いちばん早い送る日).Date } catch { continue }
    $mjN = ($mjSd - (Get-Date).Date).Days; if ($mjN -gt 3) { continue }
    $mjWhen = $(if ($mjN -eq 0) { '今日' } elseif ($mjN -gt 0) { 'あと' + $mjN + '日' } else { [string](-$mjN) + '日過ぎ' })
    $kmIma[('文字の注文の頼む先が決まっていない|' + [string]$dk.案件ID + '|')] = [ordered]@{ 何が = '文字の注文の頼む先が決まっていない'; 案件ID = [string]$dk.案件ID; 相手 = ''; 直す人 = '熊田さん'
        中身 = ('送る日 ' + $mjSd.ToString('M/d') + '（' + $mjWhen + '）／熊田さんがまだ決めていない文字の注文 ' + $mjR.Count + '行：' + ((@($mjR | ForEach-Object { '「' + (Mj-Ji $_) + '」（' + [string]$_.理由 + '）' })) -join '・') + '／他の相手の下書きは止めていない') }
}
# 2026-10-23 版7 12枚目（玉井さん 18:27・24代目ボス 18:32）：送った数の確かめ待ち（書き手 process_budget_files）が会期の3日前を過ぎても押されない行は、玉井さんの画面の困りごとに1行（§3 と同じ形・決めるのは熊田さん・機械は数を決めない）
foreach ($dk in $cases) {
    if ($dk.対象外 -eq $true) { continue }
    $tkK9 = $null; try { $tkK9 = ([datetime][string]$dk.会期開始).Date.AddDays(-3) } catch { continue }
    if ((Get-Date).Date -lt $tkK9) { continue }
    foreach ($c in @($dk.候補)) {
        if (-not $c -or $c.候補外 -eq $true -or [string]$c.送った中身の読み -ne '確かめ待ち') { continue }
        $kmIma[('送った数の確かめが期限を過ぎた|' + [string]$dk.案件ID + '|' + [string]$c.相手)] = [ordered]@{ 何が = '送った数の確かめが期限を過ぎた'; 案件ID = [string]$dk.案件ID; 相手 = [string]$c.相手; 直す人 = '熊田さん'
            中身 = ('期限 ' + $tkK9.ToString('M/d') + '（会期の3日前）／送った' + $(if ([string]$c.方法 -eq 'FAX') { 'FAX' } else { 'メール' }) + '「' + [string]$c.送った時の中身 + '」・発注ボード「' + $(if ([string]$c.中身全文) { [string]$c.中身全文 } else { [string]$c.中身 }) + '」／熊田さんの確かめ待ち（発注ボードの「確かめること」）・珍味グループの報告は両方の数') }
    }
}
foreach ($r in $kmRows) {
    if ([string]$r.状態 -ne '未') { continue }
    $kk0 = [string]$r.鍵; $sumi = $false
    if ($kmIma.Contains($kk0)) { $sumi = $false }
    elseif ([string]$r.出どころ -eq '見張り') { $sumi = $mhOk }
    elseif ([string]$r.出どころ -eq 'AIかおり') { $sumi = $akOk }   # 2026-10-17 手1②：入口から消えた・済になった＝ここも済（入口が読めない時は触らない）
    elseif ([string]$r.何が -in @('止め金の見直す日を過ぎた', '担当者の直しを反映できない', '担当者が確認した数を当てられない', '予定の直しを反映できない', '送る日が近いのに下書きが無い', '送った数の確かめが期限を過ぎた', '文字の注文の頼む先が決まっていない')) { $sumi = $true }
    elseif ([string]$r.何が -in @('下書きができない', '下書きが開けない')) {
        $dk = $cases | Where-Object { [string]$_.案件ID -eq [string]$r.案件ID } | Select-Object -First 1
        $ck = $(if ($dk) { $dk.候補 | Where-Object { [string]$_.相手 -eq [string]$r.相手 } | Select-Object -First 1 } else { $null })
        # 相手が無くなった・下書きができた・送った等に進んだ＝直った。「下書きが開けない」は人が［送った］か［戻す］を押せば進む
        $sumi = (-not $ck) -or ([string]$r.何が -eq '下書きができない' -and [string]$ck.状態 -ne '候補') -or ([string]$r.何が -eq '下書きが開けない' -and [string]$ck.状態 -notin @('下書き済', '送ったか確かめて'))
    }
    elseif ([string]$r.何が -eq '台帳が見つからない') { $sumi = (Test-Path ([string]$r.中身)) }
    elseif ([string]$r.何が -in @('別のPCの下書き', 'このPCでは下書きを開けない')) {
        # 2026-10-09 マニュアル係⑬：その相手の行が「下書き済」「候補」から先へ進んだ（送った・作り直した・不要）ら直った
        $dk = $cases | Where-Object { [string]$_.案件ID -eq [string]$r.案件ID } | Select-Object -First 1
        $ck = $(if ($dk) { $dk.候補 | Where-Object { [string]$_.相手 -eq [string]$r.相手 } | Select-Object -First 1 } else { $null })
        $sumi = (-not $ck) -or ([string]$r.何が -eq '別のPCの下書き' -and [string]$ck.状態 -ne '下書き済') -or ([string]$r.何が -eq 'このPCでは下書きを開けない' -and [string]$ck.状態 -ne '候補')
    }
    elseif ([string]$r.何が -eq '相手が台帳に無い') {
        # 作り直しの後に相手が戻った、または押した後に台帳が作り直された（画面が古かっただけ）＝直った
        $dk = $cases | Where-Object { [string]$_.案件ID -eq [string]$r.案件ID } | Select-Object -First 1
        $sumi = (-not $dk) -or [bool]($dk.候補 | Where-Object { [string]$_.相手 -eq [string]$r.相手 }) -or ([string]$dk.更新 -gt [string]$r.日時)
    }
    if ($sumi) { $r.状態 = '済'; $r.済んだ日時 = $kmNow }
}
foreach ($k in $kmIma.Keys) {
    $v = $kmIma[$k]; $hit = $kmRows | Where-Object { [string]$_.鍵 -eq $k -and [string]$_.状態 -eq '未' } | Select-Object -First 1
    if ($hit) { $hit.中身 = [string]$v.中身 } else { $kmNew = [ordered]@{ 鍵 = $k; 日時 = $(if ([string]$v.日時) { [string]$v.日時 } else { $kmNow }); 何が = $v.何が; 案件ID = $v.案件ID; 相手 = $v.相手; 中身 = $v.中身; 出どころ = $(if ([string]$v.出どころ) { [string]$v.出どころ } else { 'ボード' }); 状態 = '未'; 済んだ日時 = '' }; if ([string]$v.直す人) { $kmNew.直す人 = [string]$v.直す人 }; if ([string]$v.LINEに出さない) { $kmNew.LINEに出さない = [string]$v.LINEに出さない }; $kmRows += [pscustomobject]$kmNew }
}
# 済んで14日を過ぎた行は畳む（一覧が伸び続けないように・記録は 発注ボード_操作記録.txt に残る）
$kmRows = @($kmRows | Where-Object { [string]$_.状態 -eq '未' -or -not [string]$_.済んだ日時 -or ([datetime][string]$_.済んだ日時) -gt (Get-Date).AddDays(-14) })
try { $tmpK = $kmPath + '.tmp'; [IO.File]::WriteAllText($tmpK, ([ordered]@{ 説明 = '仕組みが止まった所の一覧（board_action.ps1・board_build.ps1 が書く。出どころ＝見張り の行は 記録\見張り_止まった物.json の「未」を board_build が取り込んだ物）。直ると board_build が「済」にする。直すのは発注ボードの会話。玉井さんへの知らせはこの一覧を読む'; 更新 = $kmNow; 行 = @($kmRows) } | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding $true)); Move-Item $tmpK $kmPath -Force } catch {}
$kmMi = @($kmRows | Where-Object { [string]$_.状態 -eq '未' })
if ($kmMi.Count) { [void]$hj2.Append("<div class='sec' style='margin-bottom:10px;border:2px solid #b01c1c'><div class='head'><div class='v'>仕組みの困りごと（" + $(if (@($kmMi | Where-Object { ([string]$_.直す人).StartsWith('熊田') }).Count) { '「直す人＝熊田さん」の行だけ熊田さんの番です。ほかの行は直す必要はありません' } else { '熊田さんが直す必要はありません' }) + "）</div><span class='pill ng'>$($kmMi.Count)件</span></div><div class='m'>仕組みの側で止まっている所です。直すのは発注の仕組み（AI）です。急ぐ発注で、その行に［送った］が出ていれば、手で送ってから押してください。［送った］が出ていない行は待つだけです。</div><div class='m'>" + (($kmMi | ForEach-Object { '・' + (Esc (Hira (([string]$_.日時) + '　' + [string]$_.何が + '：' + [string]$_.案件ID + $(if ([string]$_.相手) { '・' + [string]$_.相手 } else { '' }) + $(if ([string]$_.直す人) { '（直す人＝' + [string]$_.直す人 + '）' } else { '' })))) + "<br><span style='color:#666'>　" + (Nakami-Html ([string]$_.中身)) + '</span>' }) -join '<br>') + "</div></div>") }
# 2026-10-09 マネキン（電話）：頼む目安（日程一覧の d_mannequin）を過ぎて、まだ頼んでいない催事を上に出す（目安であって締め切りではない＝10/5 玉井さん）
$mqLate = @(); $mqOut = @()
foreach ($dq in $cases) { $mqq = Manq-Info $dq
    # D1 へ写す元（web_push.ps1 が読む・AIかおりが担当者へ知らせる材料）
    $mqOut += [pscustomobject][ordered]@{ 案件ID = [string]$dq.案件ID; 状態 = $(if ($mqq.手配済み -and $mqq.状態 -eq 'まだ') { '手配済み' } else { $mqq.状態 }); 目安 = $(if ($mqq.目安) { $mqq.目安.日.ToString('yyyy-MM-dd') } else { '' }); 過ぎた = [bool]$mqq.過ぎた
        中身 = $(if ($mqq.答え) { '人数 ' + ([string]$mqq.答え.答えの人数.'1週目') + '/' + ([string]$mqq.答え.答えの人数.'2週目') + $(if (@($mqq.答え.指名).Count) { '・指名 ' + (@($mqq.答え.指名) -join '／') } else { '' }) } else { '担当者の答え待ち' })
        頼んだ日時 = $(if ($mqq.記録 -and $mqq.記録.頼んだ) { [string]$mqq.記録.頼んだ.日時 } else { '' }); 頼んだ人 = $(if ($mqq.記録 -and $mqq.記録.頼んだ) { [string]$mqq.記録.頼んだ.誰が } else { '' }); 会社 = $(if ($mqq.記録 -and $mqq.記録.頼んだ) { [string]$mqq.記録.頼んだ.会社 } else { '' })
        返事 = @(@($(if ($mqq.記録) { $mqq.記録.返事 } else { @() })) | Where-Object { $_ }) }
    if ($mqq.過ぎた) { $mqLate += ([string]$dq.会場 + '（' + ([string]$dq.会期開始).Substring(5).Replace('-', '/') + '〜・目安 ' + $mqq.目安.日.ToString('M/d') + '）') } }
try { [IO.File]::WriteAllText((Join-Path $root 'web\_マネキン.json'), ((@{ 作った日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'); 催事 = @($mqOut) }) | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding $true)) } catch {}
[void]$hj.Append("<div class='sec' style='margin-bottom:10px'><div class='head'><div class='v'>マネキン（電話）：頼む目安を過ぎて、まだ頼んでいない催事</div><span class='pill " + $(if ($mqLate.Count) { 'ng' } else { 'ok' }) + "'>" + $(if ($mqLate.Count) { "$($mqLate.Count)件" } else { 'なし' }) + "</span></div>" + $(if ($mqLate.Count) { "<div class='m'>" + (($mqLate | ForEach-Object { '・' + (Esc $_) }) -join '<br>') + "<br>目安は締め切りではありません。過ぎても頼めます（早いほど取りやすい）。頼んだら、催事の画面の「マネキン（電話）」で［電話で頼んだ］を押してください。</div>" } else { '' }) + "</div>")
# 2026-09-23 点検役（Fable 5.1）の指摘：台帳の無い催事（予算待ち・開始21日以内・他の屋号）がどの画面にも出ていない＝誰も追えない。下段に出す
$gaibu = Read-JsonFile (Join-Path $planDir '_ボード外.json')
# 2026-09-23 点検役 H1・H2：担当者がLINEで熊田さんに直接頼んだ発注を、ボードが知らないまま二重に出していた。
#   倉庫メインPCの line_hacchu_import.py が書くファイルを読み、画面に出す
$lineDone = Read-JsonFile (Join-Path $planDir '_LINEで発注済み.json')
# 2026-09-26：台帳の作り直しで「送った」が消えることがある（相手が候補から外れた時）。
#   足すだけの記録を読んで、まだ送っていないはずの行に「送った記録があります」と出す＝二重発注を止める
# 2026-09-28：AIかおりで担当者が押した「発注完了」＝**事実**。まとめから拾った推測と分けて出す
$oneTap = Read-JsonFile (Join-Path $planDir '_LINEで1タップ.json')
# 2026-09-28：今季これだけしか仕入れられない品（統合設計が書く・こちらは読むだけ）
$kyokyu = Read-JsonFile (Join-Path $planDir '_供給の注意.json')
$kyokyuNG = @(@($kyokyu.品目) | Where-Object { $_ -and [double]$_.不足kg -gt 0 })
$okuttaLog = Read-JsonFile (Join-Path $planDir '_送った記録.json')
$okuttaMap = @{}
# 2026-09-29：数えるのは「本当に外へ出た／人が済ませた」ものだけ。『送る前の確認をした』『不要』は入れない
$OKURU = @('送った', '送った（確かめて）', '電話した', '倉庫から出した', '現場が発注済み')
foreach ($r9 in @($okuttaLog.行)) { if ($r9 -and $r9.案件ID -and $r9.相手 -and ($OKURU -contains [string]$r9.どうした)) { $okuttaMap[[string]$r9.案件ID + '|' + [string]$r9.相手] = [string]$r9.日時 } }
if ($gaibu -and @($gaibu.行).Count) {
    $gaibuRows = New-Object Text.StringBuilder
    $gaibuN = 0
    # 2026-09-26 点検役4/5：この欄は手書きなので腐る。①予算が届いた催事は自動で消す ②更新から3日たったら『古い情報です』
    $gaibuFurui = $false
    if ($gaibu.更新) { try { $gaibuFurui = (((Get-Date) - [datetime]$gaibu.更新).Days -ge 3) } catch {} }
    foreach ($g in @($gaibu.行)) {
        # 台帳ができた催事は、この欄に出す必要がない（下の現場ごとの表に出るので二重になる）。会場名で当てる
        #   会場名は書き方がゆれるので、記号と空白を落とし、先頭6文字が同じなら同じ催事とみなす
        $sumi = $false
        # 「阪神梅田本店 北海道展」と「阪神百貨店梅田本店」を同じ催事と見るため、百貨店・本店・店・記号を落としてから比べる
        $Norm = { param($x) (([string]$x) -replace '[\s　（）\(\)]', '' -replace '百貨店', '' -replace '本店', '') }
        $v2 = & $Norm $g.会場
        foreach ($dd2 in $cases) {
            $v1 = & $Norm $dd2.会場
            if (-not $v1 -or -not $v2) { continue }
            $n1 = [Math]::Min(6, [Math]::Min($v1.Length, $v2.Length))
            if ($v1.Contains($v2) -or $v2.Contains($v1) -or ($n1 -ge 4 -and $v1.Substring(0, $n1) -eq $v2.Substring(0, $n1))) { $sumi = $true; break }
        }
        if ($sumi) { continue }
        $cls2 = $(if ($gaibuFurui) { " class='m'" } else { "" })
        $gaibuN++
        [void]$gaibuRows.Append("<tr" + $cls2 + "><td>" + $(if ($g.急ぎ -eq $true -and -not $gaibuFurui) { "🔴 " } else { "" }) + (Esc ([string]$g.会場)) + "</td><td>" + (Esc ([string]$g.会期)) + "</td><td>" + (Esc ([string]$g.担当)) + "</td><td><b>" + (Esc ([string]$g.状態)) + "</b></td><td class='m'>" + (Esc ([string]$g.くわしく)) + "</td></tr>")
    }
    if ($gaibuFurui) { [void]$gaibuRows.Append("<tr><td colspan='5' class='m'>⚠ この欄は " + (Esc ([string]$gaibu.更新)) + " に手で書いたものです。<b>古い情報が混じっている可能性があります。</b></td></tr>") }
    # 消した行を数に入れないよう、組み立ててから件数を書く（2026-09-26）
    if ($gaibuN -gt 0) {
        [void]$hj2.Append("<div class='sec' style='margin-bottom:10px'><div class='head'><div class='v'>ボードに台帳が無い催事（追いかける先）</div><span class='pill ng'>" + $gaibuN + "件</span></div><table><tr><th>会場</th><th>会期</th><th>担当</th><th>状態</th><th>くわしく</th></tr>")
        [void]$hj2.Append($gaibuRows.ToString())
        [void]$hj2.Append("</table></div>")
    }
}
# 2026-10-09 10代目ボスの裁定：送る日の3日前になっても印の無い（まだ送っていない・下書きも無い）行を、熊田さんへの知らせの元として1ファイルに書く。
#   送るのは AIかおり（熊田さんの1対1 LINE・ボタンつき）。発注ボードは書くだけ。Slack・メールには置かない（熊田さんは Slack を読まない）
$shiraseRows = @(); $today3 = (Get-Date).Date
foreach ($d in $cases) {
    if ($d.対象外 -eq $true -or $d.下書き可 -ne $true) { continue }   # 止め金・答え待ちの催事は熊田さんの番ではない
    foreach ($c in @($d.候補)) {
        if (-not $c -or $c.候補外 -eq $true -or [string]$c.状態 -ne '候補' -or $c.止め金) { continue }
        # 2026-10-17 16代目ボスの裁定（手1③）：倉庫出しで出す人が熊田さんでない行は、熊田さんに手が無い＝知らせに載せない（10/12〜16 で 7/36通）
        if ([string]$c.方法 -eq '倉庫出し' -and [string]$c.出す人 -ne '熊田かおり') { continue }
        $sd = $null; try { $sd = ([datetime][string]$c.送る日).Date } catch { continue }
        $n = ($sd - $today3).Days
        if ($n -le 3) { $shiraseRows += [pscustomobject][ordered]@{ 案件ID = [string]$d.案件ID; 会場 = [string]$d.会場; 相手 = [string]$c.相手; 方法 = [string]$c.方法; 送る日 = $sd.ToString('yyyy-MM-dd'); あと日数 = $n; 今の状態 = [string]$c.状態; LINEで報告あり = [string]$c.LINEで報告あり } }   # 2026-10-23 LINEで報告あり＝足すだけの欄（倉庫出しの行に熊田さんの「発送します」等があれば中身・無ければ空）
    }
}
# 2026-10-29 13枚目：文字の注文（熊田さんがまだ［決めた］を押していない行）を朝の知らせに1行ずつ＝今の状態「文字の注文」・欄 文字・理由。送る日はその催事のいちばん早い送る日（無ければ今日）
foreach ($d in $cases) {
    if (-not (Mj-Deru $d)) { continue }
    foreach ($m in @(Mj-Rows $d)) {
        $sd = $null; try { $sd = ([datetime][string]$d.いちばん早い送る日).Date } catch { $sd = $today3 }
        $shiraseRows += [pscustomobject][ordered]@{ 案件ID = [string]$d.案件ID; 会場 = [string]$d.会場; 相手 = $(if ([string]$m.頼む先 -and [string]$m.頼む先 -notmatch '不明') { [string]$m.頼む先 } else { '' }); 方法 = ''; 送る日 = $sd.ToString('yyyy-MM-dd'); あと日数 = ($sd - $today3).Days; 今の状態 = '文字の注文'; 文字 = (Mj-Ji $m); 理由 = [string]$m.理由 }
    }
}
# 2026-10-16 15代目ボスの裁定（AIかおり 21 が読む側 29ce5ba を先に入れた）：送った後に数が増えた行も知らせに載せる＝今の状態「送った後に増えた」・欄「増えた数」（品ごと「品名 送った時→今」）。
#   ⚠「送った後に数が変わっています」（送った後に変わった=true）のうち、増えた品がある行だけ。熊田さんがボードで［相手に伝えた／問題なし］（henkook）を押すと印が消え、この行も消える
function Split-Qty([string]$s) { $h = [ordered]@{}; foreach ($pt in ($s -split '／')) { $t = $pt.Trim(); if ($t -match '^(.*\S)\s+(\d+(?:\.\d+)?)\s*c/s') { $h[$Matches[1]] = [double]$Matches[2] } }; return $h }
foreach ($d in $cases) {
    if ($d.対象外 -eq $true) { continue }
    foreach ($c in @($d.候補)) {
        if (-not $c -or $c.候補外 -eq $true -or $c.送った後に変わった -ne $true -or $c.止め金) { continue }
        $mae = Split-Qty $(if ([string]$c.送った時の台帳の中身) { [string]$c.送った時の台帳の中身 } elseif ([string]$c.送った時の中身全文) { [string]$c.送った時の中身全文 } else { [string]$c.送った時の中身 }); $ima = Split-Qty $(if ([string]$c.中身全文) { [string]$c.中身全文 } else { [string]$c.中身 })
        $fue = @(); foreach ($k in $ima.Keys) { $m0 = $(if ($mae.Contains($k)) { [double]$mae[$k] } else { 0 }); if ([double]$ima[$k] -gt $m0) { $fue += ($k + ' ' + $m0 + 'c/s→' + $ima[$k] + 'c/s') } }
        # 2026-10-31 確認画面 h18（1枚目(1)・玉井さん ハンコ 10/31 16:08）：セニヤの黒ごま炙りいわしだけ、荷姿（270g・90g の2つ・30g は入れない）を合わせたケースの数で比べる。
        #   送った物（実物のメール／FAX）の合計が今の合計と同じか多ければ「増えた」と言わない（近鉄和歌山＝実物 270g 4＋90g 3＝7・今 90g 7）。
        #   他の品・他の相手は今までどおり（荷姿違いの品で本当の不足を外さない＝点検の指摘）。実物が読めない時（送った中身の読み≠実物）も今までどおり。
        #   黒ごまの行が1つでも読めない時（全角・書き方の揺れ・切れた中身）も今までどおり出す＝読めた分だけ足して消す側に倒さない（点検役 10/31）
        if ($fue.Count -and ([string]$c.相手) -eq 'セニヤ' -and [string]$c.送った中身の読み -eq '実物' -and [string]$c.送った時の中身) {
            $kgSum = { param([string]$s) $n = 0.0; $hit = $false; foreach ($pt in ($s -split '／')) { $t0 = $pt.Trim(' 　・･※'); if ($t0 -notmatch '黒ごま炙りいわし' -or $t0 -match '^黒ごま炙りいわし\s*30g') { continue }; if ($t0 -match '^黒ごま炙りいわし\s*(270|90)g' -and $t0 -match '(\d+(?:\.\d+)?)\s*c/s\s*$') { $n += [double]$Matches[1]; $hit = $true } else { return $null } }; if ($hit) { return $n } else { return $null } }
            $kgM = & $kgSum ([string]$c.送った時の中身); $kgI = & $kgSum $(if ([string]$c.中身全文) { [string]$c.中身全文 } else { [string]$c.中身 })
            if ($null -ne $kgM -and $null -ne $kgI -and $kgI -le $kgM) { $fue = @($fue | Where-Object { -not (([string]$_) -match '^黒ごま炙りいわし\s*(270|90)g') }) }
        }
        if (-not $fue.Count) { continue }
        $sd = $null; try { $sd = ([datetime][string]$c.送る日).Date } catch { $sd = $today3 }
        $shiraseRows += [pscustomobject][ordered]@{ 案件ID = [string]$d.案件ID; 会場 = [string]$d.会場; 相手 = [string]$c.相手; 方法 = [string]$c.方法; 送る日 = $sd.ToString('yyyy-MM-dd'); あと日数 = ($sd - $today3).Days; 今の状態 = '送った後に増えた'; 増えた数 = @($fue) }
    }
}
try { [IO.File]::WriteAllText((Join-Path (Split-Path $PSScriptRoot -Parent) '発注案\_熊田さんへの知らせ.json'), ((@{ 説明 = '送る日の3日前を過ぎても印の無い行（状態＝候補・下書き無し）と、送った後に数が増えた行（今の状態＝送った後に増えた・欄 増えた数・ボードの［相手に伝えた／問題なし］で消える）と、下書きに入れられない担当者の文字の注文（今の状態＝文字の注文・欄 文字・理由・ボードの［決めた］で消える・2026-10-29 13枚目）。board_build.ps1 が毎回書き直す。AIかおりが熊田さんの1対1 LINE へボタンつきで知らせる（10/9 ボス裁定）。あと日数がマイナス＝送る日を過ぎた'; 作った日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm'); 行 = @($shiraseRows | Sort-Object 送る日, 会場) }) | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding $true)) } catch {}
# 2026-09-23 玉井さん「どの現場を優先して送ればいいか分からない」→ 全現場を送る日の順に横断する「今日やること」を一番上に置く
$today = (Get-Date).Date
$kyou = @()
foreach ($d in $cases) {
    if ($d.対象外 -eq $true) { continue }   # 2026-09-28 仕組みの対象外＝やることではない（LINEで手配）
    $cid0 = Hex ([string]$d.案件ID)
    foreach ($c in @($d.候補)) {
        $s0 = [string]$c.状態
        if ($DONE -contains $s0) { continue }
        if ($c.候補外 -eq $true) { continue }   # 今回の候補に入っていない行は、やることではない
        $sd = $null; try { $sd = [datetime]$c.送る日 } catch {}
        $nokori = $(if ($sd) { ($sd - $today).Days } else { 9999 })
        $aid0 = Hex ([string]$c.相手)
        $btn = ''
        if (Test-KaikiOwatta $d) {
            $btn = "<span class='m'>会期が終わった催事です（下書きは作れません）</span>"   # 2026-10-31 草案（発注チェーンの点検・本番未投入）
        } elseif ($GENBA_HOLD -contains $s0) {
            $btn = Genba-Hold-Btn $s0 $cid0 $aid0 $c   # 2026-10-31 草案（発注チェーンの点検・本番未投入） 項目1・2
        } elseif ($STUCK -contains $s0) {
            # 2026-09-23 点検役⛔1：止まっている行から下書きを開かせない（二重に送る道をふさぐ）
            $btn = Stuck-Btn $s0 $cid0 $aid0
        } elseif ($c.止め金) {
            $btn = Tome-Fuda $d $c
        } elseif ($d.下書き可 -eq $true -and $c.送る前に確認 -eq $true -and ([string]$c.確認しました.確かめた理由 -ne [string]$c.確認の理由)) {
            # 2026-10-07 玉井さん：上の表は［下書きを開く］だけを出し、押すと「［確認しました］を押して」と出るのに、そのボタンがどこにも無かった（下の表にしか無い）。
            #   下の表（$youkakunin）と同じ条件で、ここにも［確認しました］と確かめることの中身を出す
            $btn = "<button class='p' onclick=""if(askCheck())act('okcheck','$cid0','$aid0','')"">注意を確かめました</button><br><span class='m'>⚠ 送る前に確かめること：" + [regex]::Replace((Esc (Hira ([string]$c.確認の理由))), '\*\*(.+?)\*\*', '<b>$1</b>') + "</span>"
        } elseif ($d.下書き可 -eq $true) {
            # 2026-10-23 A群 F4（24代目ボスの裁定・冊B 7章「小窓が出る」）：上段の［倉庫から出した］にも確認の小窓（押し間違いで倉庫の数が減らないように）
            if ($c.方法 -eq '倉庫出し') { $btn ="<button onclick=""if(confirm('倉庫から出した、と記録します。倉庫の在庫が、この行の中身の分だけ減ります。この行の中身は全部出ましたか？'))act('mark','$cid0','$aid0','倉庫から出した')"">倉庫から出した</button>" + $(if ([string]$c.LINEで報告あり) { "<br><span class='pill wn'>LINEで報告あり</span><br><span class='m'>" + (Esc ([string]$c.LINEで報告あり)) + "<br>出したなら［倉庫から出した］を押してください。LINE の文に品名が無いので、この行の中身が全部出たかを確かめてから押します</span>" } else { '' }) }   # 2026-10-23 24代目ボスの裁定（井上 10/23・b6 の型）：印を出すだけ・機械は「出した」にしない
            elseif ($c.方法 -eq '電話メモ') { $btn = "<button class='p' onclick=""act('draft','$cid0','$aid0','')"">電話メモ</button><button onclick=""act('mark','$cid0','$aid0','電話した')"">電話した</button>" }
            else { $btn = "<button class='p' onclick=""act('" + $(if ($s0 -eq '下書き済') { 'open' } else { 'draft' }) + "','$cid0','$aid0','')"">" + $(if ($s0 -eq '下書き済') { '下書きを開く' } else { '下書きを作って開く' }) + "</button>" }
        } else { $btn = "<span class='pill wn'>" + (Esc (Yasashiku ([string]$d.状態))) + "</span>" }
        # 2026-09-23 点検役⛔3：担当者が答えていない（＝まだ聞けていない）のを「修正なし」と見せない
        $kak = $d.担当者の確認
        # 台帳の「答え」は『まだ』『OK』『修正あり』の3語（process_budget_files.ps1）。『まだ』を『なし』と見せない
        $shu = $(if ($kak.答え -eq '修正あり') { '🔺あり' } elseif ($kak.答え -eq 'OK') { 'なし' } else { '⏳まだ' })
        # 2026-10-01 玉井さん：同じ会場で担当者が週ごとに違うと（阪神＝1週目 新木さん・2週目 田中さん）、どの行が誰の発注か分からない → 行ごとに出す
        $tantou0 = $(if ([string]$d.担当者) { [string]$d.担当者 + 'さん' } else { '' })
        $ks0 = [string]$d.会期開始; $ke0 = [string]$d.会期終了
        $kaiki0 = $(if ($ks0.Length -ge 10 -and $ke0.Length -ge 10) { $ks0.Substring(5).Replace('-', '/') + '〜' + $ke0.Substring(5).Replace('-', '/') } else { '' })
        $kyou += [pscustomobject]@{ 止 = [bool]($c.止め金 -or ($STUCK -contains $s0) -or $d.下書き可 -ne $true); N = $nokori; D = $sd; 相手 = [string]$c.相手; 会場 = [string]$d.会場; 担当 = $tantou0; 納品 = $(if ($kaiki0) { '会期 ' + $kaiki0 + '　' } else { '' }) + '納品 ' + [string]$d.納品.納品希望日; 修正 = $shu; 中身 = $(if ($c.中身全文) { [string]$c.中身全文 } else { [string]$c.中身 }); 状態 = $s0; 仮 = ($d.送る日は仮 -eq $true); B = $btn; 戻り = $(if ($c.戻り) { "<br><span class='pill ng'>⚠戻ってきています</span>" } else { '' }) }
    }
}
# 2026-09-23 点検役⛔4：台帳の無い催事（_ボード外.json）の「急ぎ」も同じ並びに混ぜる。別の欄に置くと見落とす
$gai = @()
if ($gaibu) {
    foreach ($g in @($gaibu.行)) {
        if ($g.急ぎ -ne $true) { continue }
        # 2026-10-01：_ボード外.json は 9/23 に手で書いた一覧。その後に台帳ができた催事は、台帳の行が正＝ここには出さない
        if (@($cases | Where-Object { $_.対象外 -ne $true -and (Kaijo-Onaji ([string]$_.会場) ([string]$g.会場)) }).Count) { continue }
        $gd = $null; try { $gd = [datetime]$g.送る日の目安 } catch {}
        $gai += [pscustomobject]@{ N = $(if ($gd) { ($gd - $today).Days } else { 9999 }); D = $gd; 相手 = '（台帳がまだ無い）'; 会場 = [string]$g.会場; 担当 = [string]$g.担当; 納品 = '会期 ' + [string]$g.会期; 修正 = '—'; 中身 = [string]$g.くわしく; 状態 = [string]$g.状態; 仮 = $false; B = "<span class='pill ng'>ボードの外</span>"; 戻り = '' }
    }
}
$kyou = @(@($kyou) + @($gai) | Sort-Object N, 会場)
$isogi = @($kyou | Where-Object { $_.N -le 0 -and -not $_.止 }).Count   # 2026-10-30 穴-31：止めの行・下書きを作れない催事の行は「今日までに送る分」に数えない（押す物ではない）
$kb = New-Object Text.StringBuilder
if (@($kyokyuNG).Count) {
    [void]$kb.Append("<div class='note' style='border:2px solid #b01c1c'><b>⚠ 今季これだけしか仕入れられない品があります。足りません。</b>")
    foreach ($kk in $kyokyuNG) {
        [void]$kb.Append("<br><b>" + (Esc ([string]$kk.品名)) + "</b>：今季の確保 <b>" + (Esc ([string]$kk.上限kg)) + "kg</b>　／　発注案の合計 <b>" + (Esc ([string]$kk.発注案の合計kg)) + "kg</b>　→　<b>" + (Esc ([string]$kk.不足kg)) + "kg 足りません</b>")
        [void]$kb.Append("<br><span class='m'>内訳：" + ((@($kk.内訳) | ForEach-Object { (Esc ([string]$_.会場)) + ' ' + [string]$_.kg + 'kg' }) -join '／') + "</span>")
        # 2026-10-30 28代目ボス：割り振りが決まっている品に「まだ決まっていません（@{…内訳=System.Object[]…}）」と出ていた＝決めた人・決め方・配る量を字で出し、割り振りに無い催事だけ玉井さんに聞く
        if ($kk.割り振り -and [string]$kk.割り振り.決めた人) {
            $wari = @(@($kk.割り振り.内訳) | Where-Object { $_ }); $wariIds = @($wari | ForEach-Object { [string]$_.案件ID })
            [void]$kb.Append("<br><span class='m'>どこへ何kg回すかは<b>" + (Esc ([string]$kk.割り振り.決めた人)) + "が決めています</b>（" + (Esc ([string]$kk.割り振り.決めた日)) + "・" + (Esc ([string]$kk.割り振り.決め方)) + "）：" + (($wari | ForEach-Object { (Esc ([string]$_.会場)) + ' ' + [string]$_.割り振りkg + 'kg' }) -join '／') + "</span>")
            $wariNai = @(@($kk.内訳) | Where-Object { $_ -and [double]$_.kg -gt 0 -and [string]$_.案件ID -and -not $_.送り済み -and ($wariIds -notcontains [string]$_.案件ID) })
            if ($wariNai.Count) { [void]$kb.Append("<br><span class='m'><b>この割り振りに無い催事（" + (($wariNai | ForEach-Object { $wh = @(([string]$_.案件ID -split '-') | Select-Object -First 2) -join '-'; $wo = @($wari | Where-Object { ([string]$_.案件ID).StartsWith($wh + '-') } | Select-Object -First 1); (Esc ([string]$_.会場)) + ' ' + [string]$_.kg + 'kg' + $(if ($wo.Count) { '【割り振りの「' + (Esc ([string]$wo[0].会場)) + '」と同じ催事かは未判定】' } else { '' }) }) -join '／') + "）は、送る前に玉井さんに「何kg配るか」を聞いてください。</b></span>") }
        } else {
            [void]$kb.Append("<br><span class='m'>どこへ何kg回すかは<b>まだ決まっていません</b>（" + (Esc ([string]$kk.割り振り)) + "）。<b>この品が入っている発注は、送る前に玉井さんに「どこへ何kg配るか」を聞いてください。</b></span>")   # 2026-10-19 玉井さん承認（問い3）：熊田さんが蔵人に聞く道は無い＝玉井さんに（10/18 の小窓の文と同じ向き）
        }
        [void]$kb.Append("<br><span class='m'>出どころ：" + (Esc ([string]$kk.出どころ)) + "</span>")
    }
    [void]$kb.Append("</div>")
}
[void]$kb.Append("<div class='sec' style='margin-bottom:10px'><div class='head'><div class='v'>今日やること（全現場・送る日の順）</div><span class='pill " + $(if ($isogi) { 'ng' } else { 'ok' }) + "'>" + $(if ($isogi) { "今日までに送る分 " + $isogi + "件" } else { "今日までに送る分はありません" }) + "</span></div>")
# 前に［送ったか確かめる］を押した結果を1行だけ出す（board_action -Action verify が書く）
$vtxt = Join-Path $planDir '_確かめた結果.txt'
$vMin = 999999
if (Test-Path $vtxt) {
    $vf = Get-Item $vtxt
    $vl = @(Get-Content $vtxt -Encoding UTF8 | Where-Object { $_.Trim() -ne '' })
    # 2026-09-23 点検役 2-⑥：Outlook が開いていなくて確かめられなかった回は、時計を戻さない（確かめていないのに帯が消えるのを防ぐ）
    if (@($vl | Where-Object { $_ -like '*確かめられませんでした*' }).Count -eq 0) { $vMin = [int]((Get-Date) - $vf.LastWriteTime).TotalMinutes }
    [void]$kb.Append("<div class='m'>前に確かめた結果（" + $vf.LastWriteTime.ToString('M/d HH:mm') + "）：" + (Esc $(if ($vl.Count) { [string]$vl[-1] } else { '変わりなし' })) + "</div>")
}
# 2026-09-23：長いあいだ確かめていないと、二重・送信トレイ・戻りに気づけない。画面のいちばん上で促す
#   （自動では動かさない。Outlook をつかんで画面が止まるのを避けるため＝9/15 の事故の型）
# 2026-09-26 点検役13：3時間ごとに出すと毎日黄色になり、慣れて本物の赤も読まれなくなる → 1日に1回だけ
if ($vMin -gt 1440) {
    $vTxt2 = $(if ($vMin -ge 999999) { 'まだ一度も確かめていません' } elseif ($vMin -ge 1440) { '前に確かめたのは ' + [int]($vMin / 1440) + ' 日前です' } else { '前に確かめたのは ' + [int]($vMin / 60) + ' 時間前です' })
    [void]$kb.Append("<div class='note'><b>⚠ 送れているかどうかを確かめましょう</b>（" + $vTxt2 + "）<br><span class='m'>熊田さんのPCの発注ボードで、右上の［送ったか確かめる］を押してください。送信済み・送信トレイ・戻ってきたメールを見て、二重発注や届かなかった分を見つけます。1〜4分かかります。</span></div>")
}
# 2026-10-08 熊田さん（LINE「合格」）の取消・数量変更のうち、当てる先が1つに決まらず仕組みが当てなかった行（line_shusei_import.py が書く）＝人が「予定を直す窓」で直す
$lsn = Read-JsonFile (Join-Path $planDir '_LINEの修正_当てられない.json')
if ($lsn -and @($lsn.行).Count) {
    $lsnTxt = @(foreach ($x in @($lsn.行)) { $ys = @($x.当てなかった行 | Where-Object { $_ }); if ($ys.Count) { foreach ($y in $ys) { [string]$x.案件ID + '：' + ([string]$y.行).Trim() + ' … ' + [string]$y.理由 } } else { '（どの催事か決まらない）' + (([string]$x.原文) -replace '\s+', ' ').Trim() } })
    [void]$kb.Append("<div class='note'><b>⚠ 熊田さんのLINEの取消・数量変更のうち、仕組みが当てられなかった行が " + $lsnTxt.Count + " 行あります</b>（その催事の［予定を直す窓を開く］で直してください）<br><span class='m'>" + (($lsnTxt | ForEach-Object { Esc $_ }) -join '<br>') + "</span></div>")
}
# 2026-09-23：どの発注のものか分からない「戻ってきたメール」を、画面の一番上に出す（見落とすと未達に気づけない）
$mod = Read-JsonFile (Join-Path $planDir '_戻ってきたメール.json')
if ($mod -and @($mod.行).Count) {
    [void]$kb.Append("<div class='note'><b>⚠ 戻ってきたメールが " + @($mod.行).Count + " 通あります</b>（どの発注のものか分かりませんでした。Outlook の受信トレイを見てください）<br><span class='m'>" + ((@($mod.行) | ForEach-Object { (Esc ([string]$_.受信)) + '　' + (Esc ([string]$_.件名)) + $(if ($_.届かなかった宛先) { '　→ 届かなかった宛先：<b>' + (Esc ([string]$_.届かなかった宛先)) + '</b>' + $(if ($_.理由) { '　理由：' + (Esc ([string]$_.理由)) } else { '' }) } else { '' }) }) -join '<br>') + "</span></div>")
}
# 2026-10-13 相手先の返事（aite_henji.py が info@gokaku.co.jp の箱から作る）＝玉井さんのゴール「相手先の挙動までも全て把握して熊田に伝える」
#   行ごと＝その相手の最新の返事（出荷日・納品予定・送り状・FAXの成否）。上の帯＝熊田さんが手を打つ物だけ（欠品・遅れ・FAXが送れなかった・FAXは送れたのにボードが送っていない）を14日分
$henji = Read-JsonFile (Join-Path $planDir '_相手の返事.json')
$henjiMap = @{}
$henjiTe = @()
if ($henji) {
    $hAll = @($henji.返事)
    foreach ($e in $hAll) {
        foreach ($a in @($e.当てた)) { if ($a) { $hk = [string]$a.案件ID + '|' + [string]$a.相手; $henjiMap[$hk] = @(@($henjiMap[$hk]) + $e | Where-Object { $_ }) } }
        $hd = $null; try { $hd = [datetime]([string]$e.日時) } catch {}
        if (-not $hd -or $hd -lt (Get-Date).AddDays(-14)) { continue }
        $syu = [string]$e.種類
        $te = $false
        if ($syu -in @('欠品', '遅れ')) { $te = $true }
        elseif ($syu -eq 'FAX送れなかった') {
            # 同じ番号へ後で送れていれば済み
            $num = $(if ([string]$e.要点 -match '（(\d+)宛') { $Matches[1] } else { '' })
            $te = -not @($hAll | Where-Object { [string]$_.種類 -eq 'FAX送れた' -and [string]$_.日時 -gt [string]$e.日時 -and $num -and ([string]$_.要点).Contains('（' + $num + '宛') }).Count
        } elseif ($syu -eq 'FAX送れた') { $te = @(@($e.当てた) | Where-Object { $_ -and [string]$_.ボードの状態 -notin @('送った', '') }).Count -gt 0 }
        if ($te) { $henjiTe += $e }
    }
}
if ($henjiTe.Count) {
    $hTxt = @(foreach ($e in $henjiTe) {
        $ate = @(@($e.当てた) | Where-Object { $_ } | ForEach-Object { [string]$_.案件ID + $(if ([string]$_.ボードの状態 -and [string]$_.ボードの状態 -ne '送った') { '（FAXは送れています・ボードは「' + [string]$_.ボードの状態 + '」のまま）' } else { '' }) })
        $ateH = $(if ($ate.Count) { $ate -join '・' } else { '<b>どの発注か分かりません</b>' + $(if (@($e.納品分 | Where-Object { $_ }).Count) { '（' + (Esc ((@($e.納品分 | Where-Object { $_ })) -join '・')) + ' 納品分）' } else { '' }) })
        (Esc ([string]$e.日時).Substring(5)) + '　<b>' + (Esc ([string]$e.種類)) + '</b>　' + (Esc ([string]$e.相手)) + '　' + (Esc ([string]$e.要点)) + '　→ ' + $ateH
    })
    [void]$kb.Append("<div class='note'><b>⚠ 相手先の返事で、気をつけるものが " + $hTxt.Count + " 件あります</b>（欠品・納品の遅れ・FAXが送れなかった・FAXは送れたのにボードが送っていない。14日分）<br><span class='m'>" + ($hTxt -join '<br>') + "</span></div>")
}
# 人が「確かめました」を押した依頼は畳む（2026-09-23 点検役）
$lineOK = Read-JsonFile (Join-Path $planDir '_LINE依頼の確認済み.json')
$lineOKKeys = @(); if ($lineOK) { $lineOKKeys = @(@($lineOK.確認済み) | ForEach-Object { [string]$_.鍵 }) }
$machi = @(); if ($lineDone) { $machi = @(@($lineDone.返事待ちの依頼) | Where-Object { $lineOKKeys -notcontains ([string]$_.日時 + '|' + [string]$_.会場) }) }
if (@($machi).Count) {
    $lineAge = ''
    if ($lineDone.更新) { $la = $null; try { $la = [int]((Get-Date) - [datetime]$lineDone.更新).TotalMinutes } catch {}; $lineAge = '（LINEを見たのは ' + [string]$lineDone.更新 + $(if ($la -ne $null -and $la -gt 240 -and (Get-Date).Hour -ge 9 -and (Get-Date).Hour -le 19) { '＝' + [int]($la / 60) + '時間前。見張りが止まっているかもしれません' } else { '' }) + '）' }
    [void]$kb.Append("<div class='note'><b>⚠ LINEで担当者から発注の依頼が出ています（まだ「発注完了」と返していません）</b>" + (Esc $lineAge) + "<br><span class='m'>先に送っていないか確かめてから、ボードで送ってください。二重に届きます。<br>※下の文はLINEのまとめから写したものです。<b>数量はLINEの原文で確かめてください</b>（まとめは写し＝原本ではありません）。</span><table><tr><th>いつ</th><th>だれから</th><th>現場</th><th>中身</th><th></th></tr>")
    foreach ($q in @($machi)) {
        $kagi = Hex ([string]$q.日時 + '|' + [string]$q.会場)
        [void]$kb.Append("<tr><td>" + (Esc ([string]$q.日時)) + "</td><td>" + (Esc ([string]$q.だれが)) + "</td><td><b>" + (Esc ([string]$q.会場)) + "</b></td><td class='m'>" + (Esc ([string]$q.本文)) + "</td><td class='acts'><button onclick=""act('lineok','$kagi','','')"">LINEを見ました</button></td></tr>")
    }
    [void]$kb.Append("</table></div>")
}
[void]$kb.Append("<table><tr><th>送る日</th><th>相手・中身</th><th>発注した人</th><th>現場・納品日</th><th>今の状態</th><th>担当者の修正</th><th></th></tr>")
# 2026-09-23 点検役 A6：15日より先でも、各現場の「次に送る1行」だけは必ず出す（全部畳むと画面が空になる）
$tsugi = @{}
# 会場ごとに「いちばん早い送る日」を出し、その日に送る分はまとめて全部出す（1行だけだと同じ日の3件が隠れる）
$tsugiN = @{}
foreach ($k in $kyou) { if ($k.N -le 14) { continue }; if (-not $tsugiN.ContainsKey($k.会場)) { $tsugiN[$k.会場] = $k.N } }
$tsugi = @(@($kyou) | Where-Object { $_.N -gt 14 -and $tsugiN.ContainsKey($_.会場) -and $_.N -eq $tsugiN[$_.会場] })
$band = ''; $saki = 0
foreach ($k in $kyou) {
    if ($k.N -gt 14) { $saki++; continue }
    # 2026-09-26 点検役20：「送る日」は納品日から逆算した**目安**であって締切ではない。
    #   過ぎただけで🔴にすると、月末に赤が積み上がって読まれなくなる。🔴は納品日そのものを過ぎたときだけ
    $b2 = $(if ($k.N -lt 0) { '🟠 目安を過ぎています（まだ間に合うことがあります）' } elseif ($k.N -eq 0) { '🟠 今日が目安' } elseif ($k.N -le 7) { '🟡 7日以内' } else { '⚪ 14日以内' })
    if ($b2 -ne $band) { [void]$kb.Append("<tr><td colspan='7' style='background:#eef1ec;font-weight:bold'>" + $b2 + "</td></tr>"); $band = $b2 }
    $hi = $(if ($k.D) { $k.D.ToString('M/d') + '（' + '日月火水木金土'[[int]$k.D.DayOfWeek] + '）' } else { '—' })
    $scl2 = $(if ($STUCK -contains $k.状態) { 'ng' } elseif ($k.状態 -eq '下書き済') { 'wn' } else { 'nt' })
    [void]$kb.Append("<tr><td>" + $hi + "<br><span class='m'>あと" + $k.N + "日" + $(if ($k.仮) { '［仮］' } else { '' }) + "</span></td><td><b>" + (Esc $k.相手) + "</b><br><span class='m'>" + (Esc $k.中身) + "</span></td><td><b>" + (Esc $k.担当) + "</b></td><td>" + (Esc $k.会場) + "<br><span class='m'>" + (Esc $k.納品) + "</span></td><td><span class='pill " + $scl2 + "'>" + (Esc (Yasashiku $k.状態)) + "</span>" + $k.戻り + "</td><td>" + (Esc $k.修正) + "</td><td class='acts'>" + $k.B + "</td></tr>")
}
if (@($tsugi).Count) {
    [void]$kb.Append("<tr><td colspan='7' style='background:#eef1ec;font-weight:bold'>⚪ この先（現場ごとに、次に送る日の分）</td></tr>")
    foreach ($k in (@($tsugi) | Sort-Object N, 会場)) {
        $hi2 = $(if ($k.D) { $k.D.ToString('M/d') + '（' + '日月火水木金土'[[int]$k.D.DayOfWeek] + '）' } else { '—' })
        [void]$kb.Append("<tr><td>" + $hi2 + "<br><span class='m'>あと" + $k.N + "日" + $(if ($k.仮) { '［仮］' } else { '' }) + "</span></td><td><b>" + (Esc $k.相手) + "</b><br><span class='m'>" + (Esc $k.中身) + "</span></td><td><b>" + (Esc $k.担当) + "</b></td><td>" + (Esc $k.会場) + "<br><span class='m'>" + (Esc $k.納品) + "</span></td><td><span class='pill nt'>" + (Esc (Yasashiku $k.状態)) + "</span></td><td>" + (Esc $k.修正) + "</td><td class='acts'>" + $k.B + "</td></tr>")
    }
}
if ($saki) { [void]$kb.Append("<tr><td colspan='7' class='m'>この先（15日より後）に送る分は、ぜんぶで " + $saki + "件あります。のこりは下の現場ごとの表で見られます。</td></tr>") }
[void]$kb.Append("</table><div class='m'>「送る日」は納品日から逆算した<b>目安</b>です。締切ではありません（過ぎても間に合うことがあります。急ぐときは相手に電話で聞いてください）。<br>送る前に見る3点＝納品日・現場・担当者の修正。⏳まだ＝担当者がまだ［OK］を押していません。赤い状態（二重・送信トレイ・古い中身）は、下書きを開かず先に確かめてください。</div></div>")
$sb = New-Object Text.StringBuilder
# 2026-09-23 AIかおりの聞き取りの状況（確認\_状況.json・毎朝7:30）を案件IDで引けるようにする。台帳の「担当者のOK待ち」が実際は「まだ質問を出していない」ことがあるため、画面に実態を出す
$askStatus = @{}
$askPath = Join-Path (Split-Path $PSScriptRoot -Parent) '確認\_状況.json'
if (Test-Path $askPath) {
    try { foreach ($r in @((Get-Content $askPath -Raw -Encoding UTF8 | ConvertFrom-Json).発注案)) { if ($r.案件ID) { $askStatus[[string]$r.案件ID] = $r } } } catch {}
}
$nav = New-Object Text.StringBuilder
$i = 0
foreach ($d in $cases) {
    $i++
    $st = [string]$d.状態
    $cls = $(if ($d.対象外 -eq $true) { 'nt' } elseif ($st -eq '完了') { 'ok' } elseif ($st -like '残り*') { 'ng' } elseif ($d.下書き可 -eq $true) { 'nt' } else { 'wn' })
    $ks = [string]$d.会期開始; $ke = [string]$d.会期終了
    $kikan = $(if ($ks.Length -ge 10) { $ks.Substring(5).Replace('-', '/') + '〜' + $ke.Substring(5).Replace('-', '/') } else { $ks })
    # 2026-10-23 24代目ボス（AIかおり 31 の点検役）：学問の型は空か、だるまの割合の数字（40〜65）。空なら出さない・数字なら「だるま55%」・クシローの A〜E はそのまま「A型」
    $kata = [string]$d.型
    $kataLabel = $(if (-not $kata) { '' } elseif ($kata -match '^\d+$') { "　だるま${kata}%" } else { "　${kata}型" })
    $meta = "$kikan　$($d.担当者)　予算 $('{0:N0}' -f [double]$d.売上予算)円$kataLabel"
    # 2026-10-15 玉井さん（14代目ボス経由）「催事は週で分けない」＝週ごとの予算と持ち主は出さない（大きな催事は日程で担当者ごとに案件を分ける）
    # 2026-09-21 穴4：いつ送るかを画面に出す（台帳の「いちばん早い送る日」。仮なら（仮）を付ける）
    $okuru = [string]$d.いちばん早い送る日
    if ($okuru.Length -ge 10) { $meta += "　送る日 " + $okuru.Substring(5).Replace('-', '/') + $(if ($d.送る日は仮 -eq $true) { '（仮）' } else { '' }) }
    [void]$nav.Append(("<div class='card' id='c{0}' onclick=""sel({0})""><div class='v'>{1}</div><div class='m'>{2}</div><span class='pill {3}'>{4}</span></div>" -f $i, (Esc $d.会場), (Esc $meta), $cls, (Esc (Yasashiku $st))))
    $cid = Hex ([string]$d.案件ID)
    [void]$sb.Append(("<div class='sec' id='s{0}'><div class='head'><div class='v'>{1}　<span class='m'>{2}</span></div><span class='pill {3}'>{4}</span></div>" -f $i, (Esc $d.会場), (Esc $meta), $cls, (Esc (Yasashiku $st))))
    $n = $d.納品
    [void]$sb.Append(("<div class='m'>納品：{0}　{1}　{2}　{3}　TEL {4}{5}</div>" -f (Esc $n.納品希望日), (Esc $n.住所), (Esc $n.会場), (Esc $n.宛名), (Esc $n.TEL), $(if ($n.注意) { '　<b>注意：' + [regex]::Replace((Esc ([string]$n.注意)), '\*\*(.+?)\*\*', '$1') + '</b>' } else { '' })))
    if ($d.対象外 -eq $true) {
        [void]$sb.Append("<div class='m' style='background:#f1efe8;padding:8px 10px;border-radius:8px'><b>この催事は、発注ボードでは扱いません。</b>" + $(if ($d.対象外の理由) { "<br>" + (Esc ([string]$d.対象外の理由)) } else { '' }) + "<br>担当者がLINEで直接手配します。<b>熊田さんはこの欄で何もしなくて大丈夫です。</b></div>")
    } elseif ($d.下書き可 -ne $true) { [void]$sb.Append("<div class='note'>" + (Esc (Yasashiku $st)) + "。頼む中身は見られますが、下書きはまだ作れません。</div>") }
    # 2026-09-23：この現場について、LINEで何が起きているか（もう発注したのか／依頼が来ているのか）
    if ($lineDone) {
        foreach ($q in @($machi | Where-Object { Kaijo-Onaji ([string]$_.会場) ([string]$d.会場) })) {
            [void]$sb.Append("<div class='note'><b>⚠ LINEで " + (Esc ([string]$q.だれが)) + " から依頼が出ています</b>（" + (Esc ([string]$q.日時)) + "・まだ「発注完了」と返していません）<br><span class='m'>" + (Esc ([string]$q.本文)) + "</span><br>この分をもう送っていないか、先に確かめてください。</div>")
        }
        # 1タップ＝担当者が押した事実。まとめ（推測）より上に、はっきり出す
        # 案件IDが入っていればそれで、無ければ会場名で突き合わせる（形は 2026-09-28 に統合設計と確定）
        foreach ($t1 in @($oneTap.行 | Where-Object { ([string]$_.案件ID -and [string]$_.案件ID -eq [string]$d.案件ID) -or ((-not [string]$_.案件ID) -and [string]$_.会場 -eq [string]$d.会場) })) {
            $shubetsu = $(if ($t1.種別) { [string]$t1.種別 } else { '発注完了' })
            [void]$sb.Append("<div class='m'>✔ LINEで<b>" + (Esc $shubetsu) + "</b>が押されています：" + (Esc ([string]$t1.日時)) + "（" + (Esc ([string]$t1.だれが)) + "）" + $(if ($t1.もとの発言) { "<br><span class='m'>もとの発言：" + (Esc ([string]$t1.もとの発言)) + "</span>" } else { '' }) + "<br>※<b>本人が押した記録です</b>。この分はボードから送らないでください（数量はLINEの原文が正）</div>")
        }
        $dn = @($lineDone.発注完了 | Where-Object { ([string]$_.案件ID -and [string]$_.案件ID -eq [string]$d.案件ID) -or ((-not [string]$_.案件ID) -and [string]$_.会場 -eq [string]$d.会場) })   # 2026-10-19 18代目ボス④：案件IDのある記録はその催事だけ
        if (@($dn).Count) { [void]$sb.Append("<div class='m'>LINEでの「発注完了」：" + ((@($dn) | Select-Object -First 3 | ForEach-Object { (Esc ([string]$_.日時)) + '（' + (Esc ([string]$_.だれが)) + '）' }) -join '・') + "　※この分はボードから送らないでください</div>") }
    }
    # 2026-09-23 AIかおりの聞き取りの実態（まだ質問を出していない／返事待ち・送った回数）を出す。台帳の「OK待ち」だけだと、質問すら出ていない件と見分けが付かない
    $as = $askStatus[[string]$d.案件ID]
    if ($as) {
        $line = 'AIかおり：' + [string]$as.状況
        if ([int]$as.送った回数 -gt 0) { $line += '（' + [string]$as.送った回数 + '回・最後 ' + ([string]$as.最後に送った日時 -replace 'T', ' ').Substring(0, [Math]::Min(16, ([string]$as.最後に送った日時).Length)) + '）' }
        # 2026-09-24：AIかおりが「まだ送っていない理由」を書き出すようになった。止まっている理由が分かるように画面へ出す
        # 2026-09-25：AIかおりが「止まっている時間」も書き出すようになった。何時間待っているかを画面に出す
        if ($as.止まっている時間 -and -not ([string]$as.止まっている時間).StartsWith('-')) { $line += '　<b>止まって ' + [string]$as.止まっている時間 + '</b>' }   # 2026-10-23 A群 F17：最後の日付が先の日付だと負の時間（-205時間）になる＝止まっていないので出さない
        if ($as.まだ送っていない理由) { $line += '　理由：' + [string]$as.まだ送っていない理由 }
        [void]$sb.Append("<div class='m'>" + ((Esc $line) -replace '&lt;b&gt;', '<b>' -replace '&lt;/b&gt;', '</b>') + "</div>")
    }
    # 2026-09-22 玉井さん：倉庫の在庫で相殺したら「発注○→倉庫○で相殺→発注○」を見せる
    # 2026-09-30 統合設計と取り決め：倉庫に残っているのに使わない品の理由。
    #   出さないと「倉庫にあるのに、なぜ仕入先に頼むのか」が分からない
    # 2026-09-30 玉井さん 9/23 の心配（週で担当者が分かれる催事を1回でまとめて聞くと二重発注になる）への止め金。
    #   週ごとの持ち主が2人以上いるのに、候補が週で分かれていない催事は、送る前に必ず人が確かめる
    $mochinushi = @()
    if ($d.週ごとの持ち主) { $mochinushi = @($d.週ごとの持ち主.PSObject.Properties | ForEach-Object { [string]$_.Value } | Where-Object { $_ } | Sort-Object -Unique) }
    $shuWakare = (@($mochinushi).Count -ge 2)
    $kirokuKara = (@(@($d.候補) | Where-Object { [string]$_.現場の記録 }).Count -eq 0)
    if ($shuWakare) {
        [void]$sb.Append("<div class='note' style='border:2px solid #b01c1c'><b>この催事は週で担当者が分かれています（" + (Esc (($mochinushi | ForEach-Object { $_ + 'さん' }) -join '／')) + "）</b>")
        [void]$sb.Append("<br>発注の候補は<b>会期ぜんぶを1回でまとめた量</b>です。週ごとには分かれていません。")
        if ($kirokuKara) { [void]$sb.Append("<br><b>すでにLINEで頼んだ分が混ざっている可能性があります。</b>この催事について「誰が何を発注済みか」の記録が1件もありません。") }
        [void]$sb.Append("<br><b>送る前に、週ごとの担当者（" + (Esc (($mochinushi | ForEach-Object { $_ + 'さん' }) -join '・')) + "）に、LINEでもう頼んだ品が無いかを聞いてください。</b>そのまま送ると二重発注になります。</div>")   # 2026-10-19 玉井さん承認（問い3）：聞く相手は週ごとの担当者（§14-35 C の案のとおり）
    }
    $riyuRows = @(@($d.引き当てなしの理由) | Where-Object { $_ })
    if ($riyuRows.Count) {
        [void]$sb.Append("<div class='m'><b>倉庫に少し残っていますが、この催事には使いません</b>（1ケースに足りない分は倉庫に残します）")
        foreach ($r in $riyuRows) { [void]$sb.Append("<br>・" + (Esc ([string]$r))) }
        [void]$sb.Append("</div>")
    }
    foreach ($z in @($d.倉庫の相殺)) { if ($z -and $z.品目) { [void]$sb.Append("<div class='m'>倉庫の相殺：" + (Esc $z.品目) + "　元の注文 " + (Esc $z.注文) + "（" + (Esc $z.相手) + "・" + $z.必要kg + "kg）／使える倉庫の在庫 " + $z.使える在庫kg + "kg → <b>" + (Esc $z.結果) + "</b>" + $(if (@($z.倉庫の中身 | Where-Object { $_ }).Count) { "<br>　<b style='color:#b01c1c'>倉庫にある形：" + (Esc ((@($z.倉庫の中身) | ForEach-Object { [string]$_ }) -join "／")) + "</b>（注文の字は仕入先の荷姿です。倉庫ではこの形で置いてあります）" } else { "" }) + "</div>") } }   # 2026-10-01 倉庫の中身＝現物の荷姿（統合設計が台帳に足した）。13kgの箱か1kgの袋かを熊田さんが取り違えないように
    # 2026-09-30 統合設計と取り決め：担当者の修正を本文へ「反映した／反映できない」が台帳に入る。
    #   反映済みなのに「手で直して」と出すと嘘になるので3つに分ける
    if ($d.担当者の確認 -and $d.担当者の確認.答え -eq '修正あり') {
        $kk = $d.担当者の確認
        $shashin = $(if (@($kk.修正の写真).Count) { '　※写真あり（G:\LINE保存\発注の修正リスト）' } else { '' })
        $atama = "<b>担当者から修正あり</b>（" + (Esc ([string]$kk.答えた日時)) + "）：" + (Esc ([string]$kk.修正リスト)) + $shashin
        $hanei = [string]$kk.反映
        if ($hanei -eq '反映した' -and @(@(Mj-Rows $d) | Where-Object { Mj-Dake $_ }).Count) {
            # 2026-10-29 13枚目（点検役⛔1）：文字だけの答え＝品目の行が無く、何も反映していない。「反映してあります」と言わない
            [void]$sb.Append("<div class='note' style='border:2px solid #d8a600'>" + $atama + "<br><b>担当者の答えは文字だけで、数に直せていません。下の中身は担当者の直しの前の数です。</b>答えを読んで、送る前に「予定を直す窓」で数を直してください。</div>")
        } elseif ($hanei -eq '反映した') {
            $naoshita = $(if (@($kk.直した品目).Count) { "<br><span class='m'>直したところ：" + ((@($kk.直した品目) | ForEach-Object { Esc ([string]$_) }) -join '／') + "</span>" } else { '' })
            [void]$sb.Append("<div class='note'>" + $atama + "<br><b>この修正は、下の中身にもう反映してあります。</b>手で直す必要はありません。" + $naoshita + "</div>")
        } elseif ($hanei -eq '反映できない') {
            $riyu = $(if (@($kk.反映できない理由).Count) { "<br><span class='m'>止まっているところ：" + ((@($kk.反映できない理由) | ForEach-Object { Esc ([string]$_) }) -join '／') + "</span>" } else { '' })
            [void]$sb.Append("<div class='note' style='border:2px solid #b01c1c'>" + $atama + "<br><b>この現場の発注は、まだ送れません。</b>担当者の直しを中身に入れられていません。<br>仕組みの側の止まりです。熊田さんが直す必要はありません（いちばん下の［くわしい表を開く］の中の「仕組みの困りごと」に載っています）。熊田さんがすること：何もしない（仕組みの側で直します）。" + $riyu + "</div>")
        } else {
            [void]$sb.Append("<div class='note'>" + $atama + "<br>下書きを開いたら、この修正に合わせて数量を直してから送ってください。</div>")
        }
    } elseif ($d.担当者の確認 -and $d.担当者の確認.答え -eq 'OK' -and [string]$d.担当者の確認.反映 -eq '反映できない') {
        # 2026-10-12 ★10/11「確認後は数字を変えない」：OK でも確認の数を当てる。当てられない時は下書きを作らない＝熊田さんには「何もしない」を出す（マニュアル係 続き6）
        $kk = $d.担当者の確認
        $riyu = $(if (@($kk.反映できない理由).Count) { "<br><span class='m'>止まっているところ：" + ((@($kk.反映できない理由) | ForEach-Object { Esc ([string]$_) }) -join '／') + "</span>" } else { '' })
        [void]$sb.Append("<div class='note' style='border:2px solid #b01c1c'><b>担当者は［これでいい］と答えています</b>（" + (Esc ([string]$kk.答えた日時)) + "）。<br><b>この現場の発注は、まだ送れません。</b>担当者が確認した数を、下書きの中身に入れられていません。<br>仕組みの側の止まりです（いちばん下の［くわしい表を開く］の中の「仕組みの困りごと」に載っています）。熊田さんがすること：何もしない（仕組みの側で直します）。" + $riyu + "</div>")
    }
    # 2026-10-29 13枚目：文字の注文（下書きに入れられない行・文字だけの答え）。この催事の他の下書きは止めていない
    foreach ($m in @(Mj-Rows $d)) { if (Mj-Dake $m) { continue }; [void]$sb.Append("<div class='note' style='border:2px solid #d8a600'><b>文字の注文：" + (Esc (Mj-Ji $m)) + "</b>（" + (Esc ([string]$m.理由)) + "）　送る日 " + (Esc ([string]$d.いちばん早い送る日)) + "<br><span class='m'>どこへ頼むかを熊田さんが決めて、下の「予定を直す窓」の「これから頼む」で入れてください。入れたら、いちばん上の「確かめること」の［決めた］を押します。この催事の他の相手の下書きは止めていません。</span></div>") }
    # その現場が、数量限定の品を何kg取ることになっているか
    foreach ($kk in $kyokyuNG) {
        foreach ($uch in @($kk.内訳 | Where-Object { [string]$_.案件ID -eq [string]$d.案件ID })) {
            [void]$sb.Append("<div class='note'><b>⚠ " + (Esc ([string]$kk.品名)) + "　この現場の分 " + [string]$uch.kg + "kg</b>（今季の確保は全部で " + (Esc ([string]$kk.上限kg)) + "kg・全体で " + (Esc ([string]$kk.不足kg)) + "kg 足りません）<br><span class='m'>割り振りは未定です。<b>この品が入っている発注は、送る前に一声かけてください。</b>代わりの候補：" + (Esc ([string]$kk.代わりの候補)) + "</span></div>")
        }
    }
    # 2026-10-07 仕入先が手配できなくなった品（仕組み\仕入先未定.json・阿川の干貝柱）。下書きからは抜いてある＝黙って落とさずここに出す
    foreach ($hm in @($d.品目 | Where-Object { [string]$_.注意 -like '仕入先未定*' })) {
        [void]$sb.Append("<div class='note' style='border:2px solid #b01c1c'><b>⚠ " + (Esc ([string]$hm.商品)) + "：仕入先未定</b>（どこからも発注されていません）<br><span class='m'>" + (Esc (Hira ([string]$hm.注意))) + "</span></div>")
    }
    # 2026-10-07 玉井さん「発注の予定＝鍵のかかった箱」：入れた直しの一覧と、窓（発注の予定を直す.hta）を開くボタン。
    #   鍵がこのPCにあるかは、開くときに JS が確かめる（画面は G ドライブで共有＝作った時点では分からない）。押した先の board_action も鍵を見る（二重の歯止め）
    $nd = $d.予定の直し
    $ndRows = @($nd.一覧 | Where-Object { $_ })
    [void]$sb.Append("<div class='note' style='background:#eef5ff;border:1px solid #9bbbe8;color:#1b3a66'><b>発注の予定を直す</b>　<span class='m'>足す・量を変える・外す／もう頼んである分の記録。鍵のあるPC（倉庫メインPC・自宅メインPC）だけ。熊田さんはブラウザ版の発注ボードの同じ催事の［予定を直す窓を開く］から直せます</span>　<span id='kg$i' class='m'></span><button class='p' id='kb$i' style='display:none' onclick=""naoshi($i)"">予定を直す窓を開く</button>")
    if ([string]$nd.状態 -eq '反映できない') { [void]$sb.Append("<div style='color:#b01c1c;margin-top:4px'><b>⚠ 直しを下書きに反映できていません＝下書きは作れません</b><br>" + (Esc (@($nd.できない理由) -join '／')) + "</div>") }
    if ($ndRows.Count) {
        [void]$sb.Append("<table style='margin-top:4px'><tr><th>いつ・誰が</th><th>何を</th><th>何をもとに</th><th>メモ</th></tr>")
        foreach ($r in $ndRows) {
            $g = $r.行
            $nani = $(if ([string]$r.種別 -eq 'もう頼んである') { '【記録】' } elseif ([string]$r.種別 -eq '頼んだ分を減らした') { '【取消済み（メーカーが応じた）】' } else { '【これから頼む】' }) + $(if ($g.人が読む -eq $true) { '※' + [string]$g.本文の字 } else { [string]$g.商品 + ' ' + [string]$g.ケース + 'c/s（' + [string]$g.発注量kg + 'kg）' }) + '　→ ' + [string]$g.頼む先 + $(if ([string]$g.ケース -eq '0' -and $g.人が読む -ne $true) { '　＝外す' } else { '' })
            [void]$sb.Append("<tr><td>" + (Esc (([string]$r.いつ) -replace 'T', ' ' -replace '\+09:00', '')) + "<br><span class='m'>" + (Esc ((Hira ([string]$r.誰が)) + '（' + [string]$r.PC + '）')) + "</span></td><td>" + (Esc $nani) + "</td><td>" + (Esc (Hira ([string]$r.何をもとに))) + "</td><td>" + (Esc $(if ([string]$r.メモ) { Hira ([string]$r.メモ) } else { 'メモなし' })) + "</td></tr>")
        }
        [void]$sb.Append("</table>")
        if (@($nd.直した).Count) { [void]$sb.Append("<div class='m'>反映：" + (Esc (Hira (@($nd.直した) -join '／'))) + "</div>") }
    }
    [void]$sb.Append("</div>")
    if ([string]$d.担当者の確認.反映 -like '確かめ待ち*') { $cidS = Hex ([string]$d.案件ID); [void]$sb.Append("<div class='note'>⚠ 担当者の修正の字に、倉庫から持ち出した報告らしい言葉があります（" + (Esc ((@($d.担当者の確認.反映できない理由) | Select-Object -First 1) -join '')) + "）。数は変えていません。<br><button onclick=""act('shusei','$cidS','','注文')"">注文として当てる</button><button onclick=""act('shusei','$cidS','','報告')"">報告なので当てない（今の数のまま）</button></div>") }   # 2026-10-31 草案（発注チェーンの点検・本番未投入） 項目5
    [void]$sb.Append("<table><tr><th>相手</th><th>方法</th><th>中身</th><th>送る日</th><th>状態</th><th></th></tr>")
    $today = (Get-Date).Date
    foreach ($c in @($d.候補)) {
        $aid = Hex ([string]$c.相手)
        $s = [string]$c.状態
        # 2026-09-26：候補から外れた相手（品目が減った・方法が変わった等）。
        #   『送った』も EntryID も残してある。熊田さんには「もう頼まなくていい／前に送った分」と分かるように
        $kouhogai = ($c.候補外 -eq $true)
        $scls = $(if ($kouhogai) { 'nt' } elseif ($DONE -contains $s) { 'ok' } elseif ($STUCK -contains $s) { 'ng' } elseif ($s -eq '下書き済') { 'wn' } else { 'nt' })
        # 2026-09-28：数量限定などで「送る前に一声」が付いた行。人が確かめるまで下書きのボタンを出さない
        $youkakunin = ($c.送る前に確認 -eq $true -and ([string]$c.確認しました.確かめた理由 -ne [string]$c.確認の理由))
        $b = ''
        if ($kouhogai) {
            # 今回の候補に入っていない行。押せるのは［戻す］だけ（間違って外れた時に戻すため）
            # 2026-10-23 A群 F5（追31）：確認文を付ける・「候補」の語を出さない
            $b = "<button onclick=""if(confirm('この行を、今回の発注に戻します。戻すと下書きが作れるようになります。前に送った分と二重に送らないよう、確かめてから押してください。よろしいですか？'))act('mark','$cid','$aid','候補')"">戻す</button>"
        } elseif ($DONE -contains $s) {
            $modoMsg = '「' + $s + '」を取り消して「まだ送っていない」に戻します。' + $(if ($c.方法 -eq '倉庫出し' -and $s -eq '倉庫から出した') { '倉庫から出した記録も消え、倉庫の在庫の数が元に戻ります。' } else { '' }) + 'よろしいですか？'
            $b = "<button onclick=""if(confirm('$modoMsg'))act('mark','$cid','$aid','候補')"">戻す</button>"
            if ($s -eq '現場が発注済み' -and [string]$c.現場の照合.数 -ne '確認済み') { $b += "<span class='m'>数は確かめていません</span><button onclick=""act('mark','$cid','$aid','数を確かめた')"">数を確かめた</button>" }   # 2026-10-31 草案（発注チェーンの点検・本番未投入） 項目1
        } elseif ($GENBA_HOLD -contains $s) {
            $b = Genba-Hold-Btn $s $cid $aid $c   # 2026-10-31 草案（発注チェーンの点検・本番未投入） 項目1・2
        } elseif ($STUCK -contains $s) {
            # 2026-09-23 点検役⛔1：送信済み・送信トレイに同じ目印の便が見つかっている行。下書きを作り直すと二重に送るので、まず確かめてもらう
            $b = Stuck-Btn $s $cid $aid
        } elseif ($c.止め金) {
            # 2026-10-01 止め金：この相手だけ止める。ボタンは1つも出さない
            $b = Tome-Fuda $d $c
        } else {
            if ($youkakunin) {
                $b += "<button class='p' onclick=""if(askCheck())act('okcheck','$cid','$aid','')"">注意を確かめました</button>"
            } elseif ($c.方法 -notin @('電話メモ', '倉庫出し') -and $d.下書き可 -eq $true -and -not (Test-KaikiOwatta $d)) {   # 2026-10-31 草案：会期が終わった催事は出さない
                $b += $(if ($s -eq '下書き済') { "<button class='p' onclick=""act('open','$cid','$aid','')"">下書きを開く</button>" } else { "<button class='p' onclick=""act('draft','$cid','$aid','')"">下書きを作って開く</button>" })
            }
            if ($c.方法 -eq '電話メモ' -and $d.下書き可 -eq $true) { $b += "<button class='p' onclick=""act('draft','$cid','$aid','')"">電話メモを開く</button>" }
            $doneLabel = $(if ($c.方法 -eq '電話メモ') { '電話した' } elseif ($c.方法 -eq '倉庫出し') { '倉庫から出した' } else { '送った' })   # 2026-09-22 倉庫出し＝倉庫から送ったら押す（倉庫の在庫が減る）
            # 2026-09-21 穴2：下書きが作れない案件では［送った］［電話した］を出さない（何も送っていないのに「送った」と記録できてしまうため）。［不要］は戻せるので残す
            # 2026-09-26 点検役：下書きを作っていない行でも［送った］が押せて、押すと戻せない → 1回だけ確かめる
            if ($d.下書き可 -eq $true) {
                $ask = $(if ($s -eq '下書き済') { '' } else { "askSent(" })
                # 2026-10-08 仕組みの穴22：倉庫出しの行で「Outlook から自分で送りましたか？」と聞いていた＝倉庫出し用の確かめ（askOut）に分ける
                $askFn = $(if ($c.方法 -eq '倉庫出し') { 'askOut' } elseif ($c.方法 -eq '電話メモ') { 'askTel' } else { 'askSent' })   # 2026-10-12 マニュアル係 続き6-2：電話の行に「Outlook から送りましたか」は合わない
                $b += $(if ($s -eq '下書き済') { "<button onclick=""act('mark','$cid','$aid','$doneLabel')"">$doneLabel</button>" } else { "<button onclick=""if($askFn())act('mark','$cid','$aid','$doneLabel')"">$doneLabel</button>" })
            }
            $b += "<button onclick=""if(confirm('この行を「不要」にします（この相手には頼みません）。押し間違えた時は、同じ行の［戻す］で戻せます。よろしいですか？'))act('mark','$cid','$aid','不要')"">不要</button>"   # 2026-10-23 A群 F12（追42）：小窓に戻し方
        }
        $when = $(if ($c.日時) { '<br><span class="m">' + (Esc $c.日時) + '</span>' } else { '' })
        # 2026-09-21 穴4：相手ごとの送る日。今日以前で未処理なら赤、仮なら（仮）
        $sd = [string]$c.送る日; $sdHtml = ''
        if ($sd) {
            $due = $false; try { $due = ([datetime]$sd -le $today) -and ($DONE -notcontains $s) } catch {}
            $sdHtml = $(if ($due) { "<span class='pill ng'>" + (Esc $sd) + "</span>" } else { Esc $sd }) + $(if ($d.送る日は仮 -eq $true) { '<span class="m">（仮）</span>' } else { '' })
        }
        # 2026-09-23：メールが戻ってきている行に赤い印（送った事実は消さない。CCの1人だけが戻ることがある）
        # 台帳は「候補」なのに、押した記録が残っている＝作り直しで消えた可能性。必ず知らせる
        $kioku = ''
        $kkey = [string]$d.案件ID + '|' + [string]$c.相手
        if ($DONE -notcontains $s -and $okuttaMap.ContainsKey($kkey)) {
            $kioku = "<br><span class='pill ng'>⚠ 送った記録があります</span><br><span class='m'>" + (Esc $okuttaMap[$kkey]) + "　もう一度送ると二重になります。先に［送ったか確かめる］を押してください</span>"
        }
        # 候補外の説明（画面に理由を出す）
        $kgTxt = $(if ($kouhogai) { "<br><span class='m'>今回の候補には入っていません" + $(if ($c.候補外になった日) { "（" + (Esc ([string]$c.候補外になった日)) + "）" } else { '' }) + "。前に送った分の記録として残しています。もう頼む必要はありません。</span>" } else { '' })
        # 理由の文に入っている ** は、画面では太字にする（記号のまま出すと読みにくい）
        $riyuHtml = [regex]::Replace((Esc (Hira ([string]$c.確認の理由))), '\*\*(.+?)\*\*', '<b>$1</b>')
        $kubariTxt = $(if ($null -ne $c.配る量kg) { "<br><b>この催事に配る量：" + [string]$c.配る量kg + "kg</b>" } else { '' })
        $youTxt = $(if ($youkakunin) { "<br><span class='pill ng'>⚠ 送る前に一声</span>" + $kubariTxt + "<br><span class='m'>" + $riyuHtml + "</span>" } elseif ($c.確認しました) { "<br><span class='m'>送る前の確認：済み（" + (Esc ([string]$c.確認しました.日時)) + "）</span>" + $kubariTxt } else { '' })
        # 2026-09-30 統合設計の依頼：倉庫出しの行に「どの催事の残りを出すのか」を出す（二重に当てないため）
        $hikiTxt = ''
        $hikiRows = @(@($c.引き当て) | Where-Object { $_ -and $_.品名 })
        if ($hikiRows.Count) {
            $hikiTxt = "<br><span class='m'><b>倉庫のどこから出すか</b>"
            foreach ($h in $hikiRows) {
                $motoList = @(@($h.元) | ForEach-Object { Moto-Yomiyasuku ([string]$_) } | Where-Object { $_ })
                $moto = $(if ($motoList.Count) { ($motoList -join '／') } else { '出どころが分かりません' })
                $kosu = $(if ($h.ケース) { '（' + [string]$h.ケース + 'c/s）' } else { '' })
                $hikiTxt += "<br>・" + (Esc ([string]$h.品名)) + "　" + (Esc (KgFmt $h.kg)) + "kg" + (Esc $kosu) + "　← <b>" + (Esc $moto) + "</b> の残り"
            }
            $hikiTxt += "</span>"
        }
        # 2026-10-08 倉庫出しの行に「出す人」（既定＝担当者が自分で持っていく）を出す
        $dasuTxt = ''
        if ($c.方法 -eq '倉庫出し' -and -not $kouhogai) { $dh = Dasu-Hito $d $cases; $dasuTxt = "<br><b>出す人：" + (Esc ([string]$dh.出す人)) + "</b><br><span class='m'>" + (Esc (Hira ([string]$dh.理由))) + "</span>" + $(if ([string]$c.出す人が変わった) { "<br><b style='color:#b01c1c'>⚠ 出す人が変わりました：" + (Esc ([string]$c.出す人が変わった)) + "</b>" } else { '' }) + $(if ([string]$c.LINEで報告あり) { "<br><span class='pill wn'>LINEで報告あり</span><br><span class='m'>" + (Esc ([string]$c.LINEで報告あり)) + "<br>※出した事実の確定は熊田さんの［倉庫から出した］か熊田さんの答え（LINE の文に品名が無い）</span>" } else { '' }) }   # 2026-10-12 12代目ボス：変わったことに気づかないまま出荷が漏れないように／2026-10-23 24代目ボスの裁定（井上 10/23・b6 の型）：LINEで報告ありの印
        # 2026-10-08 穴22：担当者がAIかおりで「一部だけ持っていった」と押した分（_持っていった_当てた.json の 一部）を出す。締めるのは熊田さんの［倉庫から出した］
        if ($c.方法 -eq '倉庫出し') {
            $mtp = Join-Path $planDir '_持っていった_当てた.json'
            if (Test-Path $mtp) { try { $mtj = Get-Content $mtp -Raw -Encoding UTF8 | ConvertFrom-Json; foreach ($m in @($mtj.一部)) { if ($m -and [string]$m.案件ID -eq [string]$d.案件ID) { $dasuTxt += "<br><span class='pill ng'>担当者が一部だけ持っていった</span><br><span class='m'>" + (Esc ([string]$m.担当者 + '：' + (@($m.品) -join '／') + '（' + [string]$m.時刻 + '）' + $(if ($m.理由) { '　' + [string]$m.理由 } else { '' }))) + "</span>" } } } catch {}
            }
        }
        # 2026-10-08 ボスの依頼（鍵=仕組み/取消）②：送った後に中身（数量）が変わった行に⚠。相手へ直すかは人（熊田さん）が決める
        $henko = $(if ($c.送った後に変わった -eq $true) { "<br><span class='pill ng'>⚠送った後に数が変わっています</span><br><span class='m'>送った時：" + (Esc ([string]$c.送った時の中身)) + "<br>相手に伝えたら、予定を直す窓の「送った後の取消・減らした」か「もう頼んである」で記録し、下のボタンを押します</span><br><button onclick=""if(confirm('この変更は相手に伝えた（または伝えなくてよい）ですね？\n押すと、この⚠を消します。何も送りません。'))act('henkook','$cid','$aid','')"">相手に伝えた／問題なし</button>" } else { '' })
        # 2026-10-23 穴A（24代目ボスの裁定）：送った時の中身は実物のメールから（verifycopy）。手で直して送った行は注（⚠ではない）・「確かめ待ち」は上の「確かめること」で熊田さんが押す。読みの規則は process_budget_files（送った中身の読み）
        #   「確かめ待ち」の行の注と案内の文は、ボスが熊田さんに分かる言葉に直して送るまで出さない（玉井さん 10/23 版6 12枚目［直してほしい］＝「文章の内容が全く理解できない」）
        if ($c.手で直して送った -eq $true) { $henko += "<br><span class='pill " + $(if ([string]$c.送った中身の読み -eq '確かめ待ち') { 'ng' } else { 'ok' }) + "'>手で直して送った</span><br><span class='m'>送ったメール：" + (Esc ([string]$c.送った時の中身)) + "<br>発注ボード：" + (Esc ([string]$c.中身全文)) + $(if ([string]$c.送った中身の注 -and [string]$c.送った中身の読み -ne '確かめ待ち') { "<br>" + (Esc ([string]$c.送った中身の注)) } else { '' }) + "</span>" }
        elseif ([string]$c.送った中身の注 -like 'PDF*') { $henko += "<br><span class='m'>" + (Esc ([string]$c.送った中身の注)) + "</span>" }
        # 2026-10-09 玉井さん：送った後に弊社がメーカーへ取消を頼み、メーカーが応じた分を、その相手の行に「取消済み」で出す（記録＝予定の直し「頼んだ分を減らした」）。
        #   メーカーが応じた時だけ記録する決まり（玉井さん 10/9）＝ここは出すだけ
        #   10/8 までの熊田さんの取消（送った後の相手へ「これから頼む・0」で当てた分＝井上の阿川・セニヤ）も、送った後の行なら同じく「取消済み」に出す
        $okuttaGo = ([string]$c.状態 -match '^(送った|電話した|現場が発注済み)')
        $torikeshi = @(@($d.予定の直し.一覧) | Where-Object { $_ -and [string]$_.行.頼む先 -eq [string]$c.相手 -and ([string]$_.種別 -eq '頼んだ分を減らした' -or ($okuttaGo -and [string]$_.種別 -eq 'これから頼む' -and [string]$_.行.ケース -eq '0' -and [string]$_.行.注意 -like '取消*')) })
        if ($torikeshi.Count) { $henko += "<br><span class='pill ok'>取消済み（メーカーが応じた分）</span>" + (@($torikeshi | ForEach-Object { "<br><span class='m'>・" + (Esc ([string]$_.行.商品)) + $(if ([string]$_.種別 -eq '頼んだ分を減らした') { ' ' + (Esc ([string]$_.行.ケース)) + 'c/s を取消　' } else { ' を取消　' }) + (Esc (Hira ((([string]$_.誰が) + ' ' + ([string]$_.いつ -replace 'T', ' ' -replace '\+09:00', '')).Trim()))) + $(if ([string]$_.メモ) { '　理由：' + (Esc (Hira ([string]$_.メモ))) } else { '' }) + "</span>" }) -join '') }
        # 2026-10-08 穴28：下書きがどのPCの Outlook にあるか（別のPCでは開けない・作り直さない）
        $pcTxt = $(if ([string]$c.状態 -eq '下書き済' -and [string]$c.作ったPC) { "<br><span class='m'>下書きは「" + (Esc ([string]$c.作ったPC)) + "」のPCの Outlook にあります</span>" } else { '' })
        $modori = $pcTxt + $henko + $(if ($c.戻り) { "<br><span class='pill ng'>⚠戻ってきています</span><br><span class='m'>" + (Esc ([string]$c.戻り.受信)) + $(if ($c.戻り.届かなかった宛先) { "<br>届かなかった宛先：<b>" + (Esc ([string]$c.戻り.届かなかった宛先)) + "</b>" + $(if ($c.戻り.理由) { "<br>理由：" + (Esc ([string]$c.戻り.理由)) } else { '' }) } else { "　宛先を確かめてください" }) + "</span>" } else { '' })
        # 2026-10-13 相手先の返事（aite_henji.py）＝この相手の返事を新しい順に3つまで
        $hEv = @($henjiMap[[string]$d.案件ID + '|' + [string]$c.相手] | Where-Object { $_ } | Sort-Object { [string]$_.日時 } -Descending | Select-Object -First 3)
        # 2026-10-23 b6③（玉井さんのハンコ 10/22 03:09）：［電話した］の行に、熊田さんの LINE「発注完了 〈会場〉」（ハンコ 6-4）を出す。読むのは _LINEで発注済み.json の 発注完了（書き手 line_hacchu_import・会場で当てた物＝相手までは当てない）
        if ([string]$c.状態 -eq '電話した' -and $lineDone) { $lnK = @(@($lineDone.発注完了) | Where-Object { $_ -and [string]$_.案件ID -eq [string]$d.案件ID } | Sort-Object { [string]$_.日時 } -Descending | Select-Object -First 2); $modori += $(if ($lnK.Count) { "<br><span class='pill ok'>LINEで報告あり</span>" + (@($lnK | ForEach-Object { "<br><span class='m'>" + (Esc ([string]$_.日時 + ' ' + [string]$_.だれが + '「' + [string]$_.本文 + '」')) + '</span>' }) -join '') } else { "<br><span class='m'>この現場の「発注完了」の LINE はまだ見つかっていません（電話で頼んだら、珍味などの LINE に「発注完了 会場名」と書きます）</span>" }) }
        if ($hEv.Count) { $modori += "<br><span class='m'><b>相手の返事</b>" + (@($hEv | ForEach-Object { '<br>' + (Esc ([string]$_.日時).Substring(5)) + ' ' + $(if ([string]$_.種類 -in @('欠品', '遅れ', 'FAX送れなかった')) { "<span class='pill ng'>" + (Esc ([string]$_.種類)) + '</span>' } else { (Esc ([string]$_.種類)) }) + ' ' + (Esc ([string]$_.要点)) }) -join '') + "</span>" }
        # 2026-10-09 マニュアル係⑯：手で送る時に宛先が分からなかった＝相手の名前の下にメールアドレス／FAX番号を出す（台帳の宛先そのまま）
        $atoHtml = ''
        $ato0 = [string]$c.宛先
        if ($ato0 -and $c.方法 -eq 'メール') { $atoHtml = "<br><span class='m'>" + (Esc $ato0) + "</span>" }
        elseif ($ato0 -and $c.方法 -eq 'FAX') { $fx = ($ato0 -replace '@.*$', ''); if ($fx -match '^81(\d+)$') { $fx = '0' + $Matches[1] }; $atoHtml = "<br><span class='m'>FAX " + (Esc $fx) + "</span>" }
        [void]$sb.Append(("<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{7}</td><td><span class='pill {3}'>{4}</span>{5}{8}</td><td class='acts'>{6}</td></tr>" -f ((Esc $c.相手) + $atoHtml), (Esc $c.方法), (Esc $(if ($c.中身全文) { [string]$c.中身全文 } else { [string]$c.中身 })), $scls, (Esc (Yasashiku $s)), $when, $b, $sdHtml, ($modori + $kioku + $kgTxt + $youTxt + $hikiTxt + $dasuTxt)))
    }
    [void]$sb.Append("</table>")
    # 2026-09-22 玉井さん：下書きの中身とマネキン人数をボードの中で見られるように＝発注案の文書（品目・数量・マネキン人数）をそのまま載せる
    if ($d.発注案 -and (Test-Path $d.発注案)) { [void]$sb.Append("<div class='m' style='margin-top:8px'><b>発注案の中身（品目・数量・マネキン人数）</b>　" + (Esc $d.発注案) + "</div><pre class='plan'>" + (Esc (Get-Content $d.発注案 -Raw -Encoding UTF8)) + "</pre>") }
    elseif ($d.マネキン人数) { [void]$sb.Append("<div class='m'>マネキン人数：" + (Esc ([string]($d.マネキン人数 | ConvertTo-Json -Compress))) + "</div>") }
    [void]$sb.Append((Manq-Block $d $i))   # 2026-10-09 マネキン（電話）の行
    [void]$sb.Append("</div>")
}
[void]$sb.Append((Manq-Datalists))
if (-not @($cases).Count) { [void]$sb.Append("<div class='note'>まだ発注の候補がありません。AIかおりの「予算と型」が届くと、ここに並びます。</div>") }
$guard = (Join-Path $PSScriptRoot 'run_guard.ps1').Replace('\', '\\')
$act = (Join-Path $PSScriptRoot 'board_action.ps1').Replace('\', '\\')
$cfgp = $Config.Replace('\', '\\')
# 2026-09-26 点検役：Gドライブに置くと、倉庫PCで札を押した結果が熊田さんの画面に飛ぶ → このPCの中だけに覚える
$selFile = (Join-Path $seenDir '_ボードの選択.txt').Replace('\', '\\')
$js = @'
var GUARD="__GUARD__", ACT="__ACT__", CFG="__CFG__", SELF="__SEL__", N=__N__;
function fso(){return new ActiveXObject("Scripting.FileSystemObject");}
function hex(s){var o="",i,c;for(i=0;i<s.length;i++){c=s.charCodeAt(i);if(c<128){o+=("0"+c.toString(16)).slice(-2);}else if(c<2048){o+=(192|(c>>6)).toString(16)+("0"+(128|(c&63)).toString(16)).slice(-2);}else{o+=(224|(c>>12)).toString(16)+("0"+(128|((c>>6)&63)).toString(16)).slice(-2)+("0"+(128|(c&63)).toString(16)).slice(-2);}}return o;}
function loadSel(){try{var f=fso();if(f.FileExists(SELF)){var t=f.OpenTextFile(SELF,1,false,0);var v=t.ReadLine();t.Close();return parseInt(v)||1;}}catch(e){}return 1;}
function saveSel(n){try{var t=fso().CreateTextFile(SELF,true,false);t.WriteLine(n);t.Close();}catch(e){}}
function sel(n){var i;for(i=1;i<=N;i++){var s=document.getElementById("s"+i),c=document.getElementById("c"+i);if(s){s.style.display=(i==n)?"":"none";}if(c){c.className=(i==n)?"card sel":"card";}}saveSel(n);}
// 2026-10-07 玉井さん「5分に1回『このスクリプトの実行を中止しますか』が出る」＝裏の処理（1〜5分）が終わるまで画面の動きを止めて待っていたため。
//   待たずに裏で走らせ、終わった印のファイルを1秒ごとに見て、出たら画面を作り直す（押し直しは受けない）
var BUSYNOW=false;
function run(argLine,timeout,after){if(BUSYNOW){return;}BUSYNOW=true;var f=fso();var done=f.GetSpecialFolder(2).Path+"\\board_done_"+(new Date().getTime())+".txt";var sh=new ActiveXObject("WScript.Shell");sh.Run('cmd /c powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+GUARD+'" -Target "'+ACT+'" -TimeoutSec '+timeout+' -ArgLine "'+argLine+'" & echo x> "'+done+'"',0,false);var t0=new Date().getTime(),lim=(timeout+60)*1000;function poll(){var ok=false;try{ok=fso().FileExists(done);}catch(e){}if(ok){try{fso().DeleteFile(done);}catch(e){}after();return;}if(new Date().getTime()-t0>lim){after();return;}setTimeout(poll,1000);}setTimeout(poll,1000);}
function askCheck(){return confirm("この発注には「送る前に確かめること」が付いています。\n行の ⚠ の文を読んで、確かめましたか？\n・数量限定の品の量（何kg配るか）は、玉井さんに聞いてください\n・納品日が「推定」の時は、その催事の担当者さんに着く日を聞いてください\n\n［OK］確かめた　／　［キャンセル］まだ");}
function askSent(){return confirm("この行は、この画面から下書きを作っていません。\nOutlook から自分で送りましたか？\n\n［OK］送った　／　［キャンセル］まだ送っていない");}
function askTel(){return confirm("相手に電話で頼みましたか？\n\n［OK］電話で頼んだ　／　［キャンセル］まだ");}
function askOut(){return confirm("この品は、もう倉庫から出ましたか？\n（担当者が自分で持っていった分も、出たら押します）\n押すと、倉庫の在庫から減ります。\n\n［OK］出た　／　［キャンセル］まだ倉庫にある");}
function busy(msg){try{var d=document.getElementById("busy");if(d){d.innerHTML=msg;d.style.display="block";}}catch(e){}}
function keepPos(){try{var y=document.body.scrollTop||document.documentElement.scrollTop||0;var t=fso().CreateTextFile(POSF,true,false);t.WriteLine(y);t.Close();}catch(e){}}
function loadPos(){try{var f=fso();if(f.FileExists(POSF)){var r=f.OpenTextFile(POSF,1,false,0);var v=r.ReadLine();r.Close();var y=parseInt(v)||0;if(y>0){window.scrollTo(0,y);}}}catch(e){}}
var POSF="__POSF__";
function act(a,cid,aid,st){try{keepPos();busy("処理しています。終わると画面が自動で書き直ります。そのまま少し待ってください。");var line="-Action "+a+" -CaseHex "+cid+(aid?" -AiteHex "+aid:"")+(st?" -StateHex "+hex(st):"")+" -Config "+CFG;run(line,120,function(){location.reload();});}catch(e){alert("ボタンの裏の道具が動きませんでした（"+e.message+"）。\n\n熊田さんがすること：ボードを閉じて開き直し、もう一度だけ押してください。それでも同じときは、ブラウザ版の発注ボード（https://hacchu-board.gokaku-san.workers.dev）で同じ催事の同じボタンを押してください。");}}
function verify(){try{keepPos();busy("送信済みと戻ってきたメールを見ています。1〜4分かかります。画面が動かなくても、そのまま待ってください。");run("-Action verify -Config "+CFG,240,function(){location.reload();});}catch(e){alert("確かめられません: "+e.message);}}
function refresh(){if(!confirm("候補を作り直して、ボードを最新にします（1〜2分かかります）。よろしいですか？")){return;}try{busy("候補を作り直しています。1〜2分かかります。そのまま待ってください。");run("-Action refresh -Config "+CFG,300,function(){location.reload();});}catch(e){alert("更新できません: "+e.message);}}
var SEENF="__SEENF__";
function saveSeen(t){try{var f=fso();var o={};if(f.FileExists(SEENF)){var r=f.OpenTextFile(SEENF,1,false,0);var txt=r.ReadAll();r.Close();try{o=eval('('+txt+')');}catch(e){o={};}}
var d=new Date();function p(n){return (n<10?'0':'')+n;}
o[t]=d.getFullYear()+'-'+p(d.getMonth()+1)+'-'+p(d.getDate())+' '+p(d.getHours())+':'+p(d.getMinutes())+':'+p(d.getSeconds());
var w=fso().CreateTextFile(SEENF,true,false);w.Write('{"k":"'+(o.k||'')+'","g":"'+(o.g||'')+'"}');w.Close();}catch(e){}}
function pick(t){var k=document.getElementById('pk'),g=document.getElementById('pg');
k.style.display=(t=='k')?'block':'none';g.style.display=(t=='g')?'block':'none';
document.getElementById('tk').className=(t=='k')?'tab sel':'tab';
document.getElementById('tg').className=(t=='g')?'tab sel':'tab';
var b=document.getElementById('b'+t);if(b){b.style.display='none';}
saveSeen(t);try{var w=fso().CreateTextFile(TABF,true,false);w.WriteLine(t);w.Close();}catch(e){}}
var TABF="__TABF__";
var KAGI="__KAGI__", NAOSHIF="__NAOSHIF__", WINF="__WINF__", KREP="__KREP__";
// 2026-10-07 発注の予定を直す鍵（このPCの中・%LOCALAPPDATA%\HacchuBoard\予定を直す鍵.json・UTF-16）。ホスト名が一致するときだけ窓のボタンを出す
function hasKey(){try{var f=fso();if(!f.FileExists(KAGI)){return false;}var r=f.OpenTextFile(KAGI,1,false,-1);var tx=r.ReadAll();r.Close();var o=eval('('+tx+')');var h=new ActiveXObject("WScript.Shell").ExpandEnvironmentStrings("%COMPUTERNAME%");return (o["ホスト名"]==h);}catch(e){return false;}}
function reportKey(ok){try{var f=fso();if(!f.FolderExists(KREP)){f.CreateFolder(KREP);}var h=new ActiveXObject("WScript.Shell").ExpandEnvironmentStrings("%COMPUTERNAME%");var d=new Date();var t=f.CreateTextFile(KREP+"\\"+h+".txt",true,false);t.WriteLine((ok?"key=1":"key=0")+" "+d.getFullYear()+"-"+(d.getMonth()+1)+"-"+d.getDate()+" "+d.getHours()+":"+d.getMinutes());t.Close();}catch(e){}}
function showKagi(){var ok=hasKey();reportKey(ok);for(var i=1;i<=N;i++){var b=document.getElementById("kb"+i),g=document.getElementById("kg"+i);if(b){b.style.display=ok?"":"none";}if(g){g.innerHTML=ok?"":"（このPCには鍵がありません）";}}}
function naoshi(n){try{var t=fso().CreateTextFile(NAOSHIF,true,false);t.WriteLine(n);t.Close();new ActiveXObject("WScript.Shell").Run('mshta "'+WINF+'"',1,false);}catch(e){alert("窓を開けません: "+e.message);}}
function loadTab(){try{var f=fso();if(f.FileExists(TABF)){var r=f.OpenTextFile(TABF,1,false,0);var v=r.ReadLine();r.Close();if(v=='g'){return 'g';}}}catch(e){}return 'k';}
// 2026-10-08 仕組みの穴24：開いたままのボードは自動で読み直さない＝送った後も「下書き済」に見え、二重に送る元になる。
//   30秒ごとにこの画面のファイルの日時を見て、書き直されていたら上に黄色の帯を出し、次の30秒でも同じ日時なら自動で読み直す（書きかけを読まない）。
//   処理中（BUSYNOW）と、確かめの小窓を出している間は動かない（小窓の間は時計が止まる）。
var BOARDF="__BOARDF__", BT0=null, BSEEN=0;
function boardTime(){try{return new Date(fso().GetFile(BOARDF).DateLastModified).getTime();}catch(e){return 0;}}
function staleBar(){try{if(document.getElementById("stale")){return;}var d=document.createElement("div");d.id="stale";d.className="note";d.style.cssText="position:sticky;top:0;z-index:9;font-size:15px;background:#fff3d6;border:2px solid #d8a600";d.innerHTML="<b>この画面は古くなりました。</b>新しい中身ができています。30秒で自動で書き直します。 ";var b=document.createElement("button");b.className="p";b.innerText="今すぐ最新にする";b.onclick=function(){keepPos();location.reload();};d.appendChild(b);document.body.insertBefore(d,document.body.firstChild);}catch(e){}}
function watchBoard(){var t=boardTime();if(BT0===null){BT0=t;}else if(t>BT0&&!BUSYNOW){if(BSEEN===t){keepPos();location.reload();return;}BSEEN=t;staleBar();}setTimeout(watchBoard,30000);}
window.onload=function(){sel(loadSel());pick(loadTab());loadPos();showKagi();watchBoard();};
'@
# ===== 2026-09-25 屋号のタブ：学問のするめ =====
#   玉井さんが「予算送信開始 学問」を送り、尾崎さん・田中さんへ売上予算を聞き始めた。学問は発注の台帳ができない屋号なので、
#   予算が届いたことだけをこの欄で知らせる。**発注はこれまでどおり手で**（下書きのボタンは出さない）。
$gk = New-Object Text.StringBuilder
$gkRows = Read-JsonFile (Join-Path $planDir '_学問のするめ.json')   # gakumon_ichiran.py が日程一覧から作る
$budDir = Join-Path $root '予算と型'
$gkBudget = @{}
foreach ($bf in (Get-ChildItem $budDir -Filter *.json -ErrorAction SilentlyContinue)) {
    try { $bj = Get-Content $bf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
    if ([string]$bj.屋号 -ne '学問のするめ') { continue }
    $gkBudget[[string]$bj.案件ID] = [pscustomobject]@{ 予算 = [double]$bj.売上予算; 更新 = $bf.LastWriteTime }
}
# 前に見たときからの増え方（覚える場所は、このPCの中だけ）
$seenPath = Join-Path $seenDir 'tab_seen.json'
$seen = Read-JsonFile $seenPath
function Seen-Time($k) { $v = $null; if ($seen) { $v = [string]$seen.$k }; if ($v) { try { return [datetime]$v } catch {} }; return (Get-Date).AddYears(-5) }
$seenK = Seen-Time 'k'; $seenG = Seen-Time 'g'
$badgeK = 0
foreach ($d in $cases) { foreach ($c in @($d.候補)) { if ($c.日時) { try { if ([datetime]$c.日時 -gt $seenK) { $badgeK++ } } catch {} } } }
$badgeG = 0
foreach ($kv in $gkBudget.GetEnumerator()) { if ($kv.Value.更新 -gt $seenG) { $badgeG++ } }
$gkAll = @($gkRows.行)
$gkKita = @($gkAll | Where-Object { $gkBudget.ContainsKey([string]$_.案件ID) }).Count
[void]$gk.Append("<div class='sec'><div class='head'><div class='v'>予算が届いた催事（学問のするめ）</div><span class='pill " + $(if ($gkKita) { 'ok' } else { 'nt' }) + "'>" + $gkKita + "件 届いた／ぜんぶで " + @($gkAll).Count + "件</span></div>")
# 2026-09-25 玉井さん：「知らせるだけでは熊田の負担を和らげるどころか、覚えることが増えるだけで労力は増す」。
#   そのとおりなので、作りかけの間は「何もしなくていい」を最初に大きく出す。発注候補と下書きが出るようになったらこの帯を消す。
[void]$gk.Append("<div class='note'><b>学問のするめの発注も、クシローと同じです。</b>左のタブ「発注（クシロー・学問）」の催事の一覧に、学問の催事も並んでいます。その行の［下書きを作って開く］→送る、で発注します（2026-10-12 から）。<br>この欄は「担当者から売上予算が届いたか」の一覧です。ここで押すものはありません。</div>")   # 2026-10-12 学問の止めを全部外した（玉井さん「1」）＝古い「まだ発注の役に立ちません・手で」を替えた（マニュアル係 続き6）
if (-not @($gkAll).Count) {
    [void]$gk.Append("<div class='note'>学問のするめの、これからの催事がまだ読めていません。倉庫のPCで <b>gakumon_ichiran.py</b> を動かすと出ます。</div>")
} else {
    [void]$gk.Append("<table><tr><th>商品の期限</th><th>会場</th><th>会期</th><th>担当</th><th>売上予算</th><th>状態</th></tr>")
    $gkN = 0
    foreach ($g in $gkAll) {
        $gkN++
        if ($gkN -gt 12) { continue }
        $kg = [string]$g.商品発注期日
        $nok = 9999; if ($kg) { try { $nok = ([datetime]$kg - (Get-Date).Date).Days } catch {} }
        $kgH = $(if ($kg) { $kg.Substring(5).Replace('-', '/') } else { '—' })
        # 2026-09-25：開始21日以内の催事は売上予算を聞かない決まり（玉井さん 9/18）＝この欄で急かさない。灰色にして期限の色も付けない
        $gaibu2 = ($g.聞き取りの対象外 -eq $true)
        if (-not $gaibu2) { $kgH = $(if ($nok -lt 0) { "<span class='pill ng'>" + $kgH + '（過ぎました）</span>' } elseif ($nok -le 14) { "<span class='pill wn'>" + $kgH + '（あと' + $nok + '日）</span>' } else { $kgH }) }
        else { $kgH = "<span class='m'>" + $kgH + "</span>" }
        $b = $null; if ($gkBudget.ContainsKey([string]$g.案件ID)) { $b = $gkBudget[[string]$g.案件ID] }
        $yo = $(if ($b) { "<b>" + ('{0:N0}' -f $b.予算) + "円</b>" } else { "<span class='m'>—</span>" })
        $naze = [string]$g.聞かない理由
        $st2 = $(if ($naze -eq '会場名が未確定') { "<span class='pill nt'>会場名が未確定</span>" } elseif ($gaibu2) { "<span class='pill nt'>従来どおり手で</span>" } elseif ($b) { $(if ($b.更新 -gt $seenG) { "<span class='pill ok'>新しい</span>" } else { "<span class='pill ok'>届いた</span>" }) } else { "<span class='pill wn'>返事待ち</span>" })
        $kik = ([string]$g.会期開始).Substring(5).Replace('-', '/') + '〜' + $(if ([string]$g.会期終了) { ([string]$g.会期終了).Substring(5).Replace('-', '/') } else { '' })
        [void]$gk.Append("<tr><td>" + $kgH + "</td><td>" + (Esc ([string]$g.会場)) + "</td><td>" + (Esc $kik) + "</td><td>" + (Esc ([string]$g.担当者)) + "</td><td>" + $yo + "</td><td>" + $st2 + "</td></tr>")
    }
    if (@($gkAll).Count -gt 12) { [void]$gk.Append("<tr><td colspan='6' class='m'>この先にもう " + (@($gkAll).Count - 12) + " 件あります（商品の期限が遠い順）。</td></tr>") }
    [void]$gk.Append("</table>")
    [void]$gk.Append("<div class='note'>この欄は「担当者から売上予算が届いたか」の一覧です。発注は左のタブの一覧から行います。<br><b>「従来どおり手で」</b>＝会期の開始まで21日を切っているため、売上予算を聞いていません（玉井さんの決まり）。何もしなくて大丈夫です。<br><b>「会場名が未確定」</b>＝日程の会場名がまだ【未翻訳】なので、担当者に聞けていません。会場名が決まると自動で聞きにいきます。<br>どちらも<b>急ぎの印ではありません</b>。</div>")
    if ($gkRows.更新) { [void]$gk.Append("<div class='m'>日程を読んだのは " + (Esc ([string]$gkRows.更新)) + "（倉庫のPCの gakumon_ichiran.py）</div>") }
}
[void]$gk.Append("</div>")
# ===== 2026-10-12 屋号の欄：広島たま屋（玉井さんのゴール「クシロー・学問・広島たま屋・マネキンの4種類を足りない所なく」）=====
#   たま屋は仕組みにまだ乗っていない（AIかおりの聞き取りの対象＝クシロー・学問だけ＝domain/budget.ts BUDGET_TARGET_YAGO／発注案は作らない）。
#   乗っていないことを隠さずに出す。「返事待ち」とは出さない（聞いていないので）。マネキンは依頼エクセルの写しの記録だけ重ねる
$tmRows = Read-JsonFile (Join-Path $planDir '_広島たま屋.json')   # gakumon_ichiran.py が日程一覧から作る（同じ道具で2屋号）
$tmAll = @($tmRows.行)
$tmMq = Read-JsonFile (Join-Path $PSScriptRoot 'マネキン依頼エクセルの写し.json')
$tmBudget = @{}
foreach ($bf in (Get-ChildItem $budDir -Filter *.json -ErrorAction SilentlyContinue)) {
    try { $bj = Get-Content $bf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
    if ([string]$bj.屋号 -ne '広島たま屋') { continue }
    $tmBudget[[string]$bj.案件ID] = [double]$bj.売上予算
}
[void]$gk.Append("<div class='sec'><div class='head'><div class='v'>広島たま屋（もみじ饅頭）の催事</div><span class='pill nt'>ぜんぶで " + $tmAll.Count + "件・仕組みにまだ乗っていません</span></div>")
[void]$gk.Append("<div class='note'><b>広島たま屋は、まだ今までどおりです。</b>AIかおりは石田さんに売上予算を聞いていません。発注の下書きも出ません（石田さんの LINE の頼みで、今までどおり手配）。<br>この欄は「どの催事があって、マネキンの記録があるか」を見るためのものです。ここで押すものはありません。</div>")
if ($tmAll.Count) {
    [void]$gk.Append("<table><tr><th>商品の期限</th><th>会場</th><th>会期</th><th>担当</th><th>売上予算</th><th>マネキン（依頼エクセル）</th></tr>")
    $tmN = 0
    foreach ($g in $tmAll) {
        $tmN++
        if ($tmN -gt 12) { continue }
        $kg = [string]$g.商品発注期日
        $kgH = $(if ($kg) { $kg.Substring(5).Replace('-', '/') } else { '—' })
        $yo = $(if ($tmBudget.ContainsKey([string]$g.案件ID)) { "<b>" + ('{0:N0}' -f $tmBudget[[string]$g.案件ID]) + "円</b>" } else { "<span class='m'>聞いていない</span>" })
        $mq = @()
        foreach ($r in @($tmMq.行)) {
            if ([string]$r.屋号 -ne '広島たま屋' -or [string]$r.開始 -ne [string]$g.会期開始) { continue }
            $vj = [string]$r.会場の字
            if ($vj -and ([string]$g.会場).Contains($vj)) { $mq += $r }
        }
        $mqH = $(if ($mq.Count) { "<span class='pill ok'>" + (Esc ([string]$mq[0].依頼)) + ' ' + $mq.Count + '名</span> ' + (Esc ((@($mq | ForEach-Object { [string]$_.会社 } | Select-Object -Unique)) -join '・')) } else { "<span class='m'>記録なし</span>" })
        $kik = ([string]$g.会期開始).Substring(5).Replace('-', '/') + '〜' + $(if ([string]$g.会期終了) { ([string]$g.会期終了).Substring(5).Replace('-', '/') } else { '' })
        [void]$gk.Append("<tr><td>" + $kgH + "</td><td>" + (Esc ([string]$g.会場)) + "</td><td>" + (Esc $kik) + "</td><td>" + (Esc ([string]$g.担当者)) + "</td><td>" + $yo + "</td><td>" + $mqH + "</td></tr>")
    }
    if ($tmAll.Count -gt 12) { [void]$gk.Append("<tr><td colspan='6' class='m'>この先にもう " + ($tmAll.Count - 12) + " 件あります。</td></tr>") }
    [void]$gk.Append("</table>")
    if ($tmRows.更新) { [void]$gk.Append("<div class='m'>日程を読んだのは " + (Esc ([string]$tmRows.更新)) + "（倉庫のPCの gakumon_ichiran.py）・社員の催事だけ（代理店の分は出していません）</div>") }
}
[void]$gk.Append("</div>")
# 画面の覚え書きの置き場所（tab_seen.json / tab_now.txt）は、上で $seenDir を決めたあとでないと書けない
$seenJs = $seenPath.Replace('\', '\\')
$tabFile = (Join-Path $seenDir 'tab_now.txt').Replace('\', '\\')
$kagiJs = (Join-Path $seenDir '予定を直す鍵.json').Replace('\', '\\')   # 2026-10-07 鍵（このPCの中）
$naoshiSelJs = (Join-Path $seenDir '_直す案件.txt').Replace('\', '\\')   # 窓に渡す「どの催事か」（このPCの中）
$winOut = Join-Path $root '発注の予定を直す.hta'; $winJs = $winOut.Replace('\', '\\')
$js = $js.Replace('__BOARDF__', $out.Replace('\', '\\'))   # 2026-10-08 穴24：自分のファイルの日時を見る（見るだけ版は下で差し替える）
$js = $js.Replace('__KREP__', (Join-Path $root '記録\鍵の有無').Replace('\', '\\')).Replace('__KAGI__', $kagiJs).Replace('__NAOSHIF__', $naoshiSelJs).Replace('__WINF__', $winJs)
$js = $js + "`r`n" + $manqJs   # 2026-10-09 マネキン（電話）のボタン
$js = $js.Replace('__GUARD__', $guard).Replace('__ACT__', $act).Replace('__CFG__', $cfgp).Replace('__SEL__', $selFile).Replace('__N__', [string]$i).Replace('__SEENF__', $seenJs).Replace('__TABF__', $tabFile).Replace('__POSF__', (Join-Path $seenDir 'pos.txt').Replace('\', '\\'))
# 2026-09-26 Gemini（使う人の代弁役）：「初めて開いた30秒で何をすればいいか言えない」「送るボタンが見つからない」
#   → 青いボタン（下書きを作れる行）の数を数えて、いちばん上に1行で出す
$osuKazu = 0        # 送る日が来ているもの＝今日ほんとうに押すもの
$junbiKazu = 0      # 準備はできているが、送る日がまだ先のもの
$tsugiOkuru = $null # いちばん早い送る日
$kyouDate = (Get-Date).Date
foreach ($d in $cases) {
    if ($d.対象外 -eq $true -or $d.下書き可 -ne $true) { continue }
    foreach ($c in @($d.候補)) {
        if ($c.候補外 -eq $true) { continue }   # 2026-10-12 マニュアル係 続き6：下の「今日やること」（候補外を飛ばす）と同じ条件に。候補外7件を数えて熊田さんが探しても見つからなかった
        $s9 = [string]$c.状態
        if ($DONE -contains $s9 -or $STUCK -contains $s9 -or $c.止め金) { continue }   # 2026-10-20 止め金の行は押すものではない（ひらかた10/29 を数えていた）
        $sd9 = $null; try { $sd9 = [datetime]$c.送る日 } catch {}
        if ($sd9 -and $sd9 -gt $kyouDate) {
            $junbiKazu++
            if (-not $tsugiOkuru -or $sd9 -lt $tsugiOkuru) { $tsugiOkuru = $sd9 }
        } else { $osuKazu++ }
    }
}
# ===== 2026-10-20 シンプルな上の画面（玉井さん「とにかく簡単にシンプルに熊田が見やすくて失敗が少ない状態を」・発注ボード修正 [63f84f]・21代目ボス異論なし・AIかおり27／在庫3 に影響なしを確認） =====
#   見せ方だけを作り直す。どの行が送れるか（下書き可・止め金・送る前に確認・STUCK）の判定とボタンの動き（act・board_action）は変えない。ボタンの名前も変えない（AIかおりの文が名指ししている）。
#   今までの表・催事ごとの表・予定を直す窓は、下の［くわしい表］に畳んで残す（消さない）。HTA（IE）でも動くよう details は使わず、文字のリンクで開け閉めする
function Naka-Matome([string]$s) {
    $pts = @(($s -split '／') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $cs = 0.0; foreach ($p in $pts) { if ($p -match '(\d+(?:\.\d+)?)\s*c/s\s*$') { $cs += [double]$Matches[1] } }
    return @{ sum = ([string]$pts.Count + '品' + $(if ($cs -gt 0) { '・合計 ' + $cs + 'c/s' } else { '' })); list = (($pts | ForEach-Object { Esc $_ }) -join '<br>') }
}
function Fmt-Hi($dt) { if ($dt) { return $dt.ToString('M/d') + '（' + '日月火水木金土'[[int]$dt.DayOfWeek] + '）' } else { return '—' } }
function Kaiki($d) { $ks = [string]$d.会期開始; $ke = [string]$d.会期終了; if ($ks.Length -ge 10 -and $ke.Length -ge 10) { return $ks.Substring(5).Replace('-', '/') + '〜' + $ke.Substring(5).Replace('-', '/') } else { return '' } }
# ボタンは「今日やること」の表と同じ条件・同じ動き（ここで判定を変えない）
function Btn-For($d, $c) {
    $s0 = [string]$c.状態; $cid0 = Hex ([string]$d.案件ID); $aid0 = Hex ([string]$c.相手)
    if (Test-KaikiOwatta $d) { return "<span class='m'>会期が終わった催事です（下書きは作れません）</span>" }   # 2026-10-31 草案（発注チェーンの点検・本番未投入）
    if ($GENBA_HOLD -contains $s0) { return (Genba-Hold-Btn $s0 $cid0 $aid0 $c) }
    if ($STUCK -contains $s0) { return (Stuck-Btn $s0 $cid0 $aid0) }
    if ($d.下書き可 -eq $true -and $c.送る前に確認 -eq $true -and ([string]$c.確認しました.確かめた理由 -ne [string]$c.確認の理由)) {
        return "<button class='p' onclick=""if(askCheck())act('okcheck','$cid0','$aid0','')"">注意を確かめました</button><br><span class='m'>⚠ 送る前に確かめること：" + [regex]::Replace((Esc (Hira ([string]$c.確認の理由))), '\*\*(.+?)\*\*', '<b>$1</b>') + "</span>"
    }
    if ($c.方法 -eq '倉庫出し') { return "<button onclick=""if(confirm('倉庫から出した、と記録します。倉庫の在庫が、この行の中身の分だけ減ります。この行の中身は全部出ましたか？'))act('mark','$cid0','$aid0','倉庫から出した')"">倉庫から出した</button>" }   # 2026-10-23 A群 F4
    if ($c.方法 -eq '電話メモ') { return "<button class='p' onclick=""act('draft','$cid0','$aid0','')"">電話メモ</button><button onclick=""act('mark','$cid0','$aid0','電話した')"">電話した</button>" }
    return "<button class='p' onclick=""act('" + $(if ($s0 -eq '下書き済') { 'open' } else { 'draft' }) + "','$cid0','$aid0','')"">" + $(if ($s0 -eq '下書き済') { '下書きを開く' } else { '下書きを作って開く' }) + "</button>"
}
# 倉庫出しの行に必ず見せる物（在庫3 の答え 10/20）：倉庫にある形・最後に人が数えた日・取り置きに使わない印・出す人
function Souko-Info($d, $c) {
    $o = @()
    if ([string]$c.出す人) { $o += '出す人：' + (Esc ([string]$c.出す人)) + $(if ([string]$c.出す人の説明) { '（' + (Esc (Hira ([string]$c.出す人の説明))) + '）' } else { '' }) }
    if ([string]$c.LINEで報告あり) { $o += "<b>LINEで報告あり</b>：" + (Esc ([string]$c.LINEで報告あり)) + '　※出した事実の確定は熊田さんの［倉庫から出した］か熊田さんの答え（LINE の文に品名が無い）' }   # 2026-10-23 24代目ボスの裁定（井上 10/23・b6 の型）
    foreach ($z in @($d.倉庫の相殺)) { if ($z -and @($z.倉庫の中身 | Where-Object { $_ }).Count) { $o += '倉庫にある形：' + (Esc ((@($z.倉庫の中身) | ForEach-Object { [string]$_ }) -join '／')) } }
    if ($zaikoLot) {
        foreach ($h in @($c.引き当て)) {
            if (-not $h) { continue }; $cd = [string]$h.品目コード
            $hits = @($zaikoLot.品目.PSObject.Properties | Where-Object { $_.Name -eq $cd -or $_.Name -like ($cd + '-*') } | ForEach-Object { $_.Value })
            $ng = @($hits | Where-Object { $_.引当に使える -eq $false })
            $hi = @($hits | ForEach-Object { [string]$_.実数.日 } | Where-Object { $_ } | Sort-Object -Descending)
            $line = (Esc ([string]$h.品名)) + '：倉庫の数を最後に数えた日 ' + $(if ($hi.Count) { $hi[0] } else { '記録なし' })
            if ($ng.Count) { $line = "<b style='color:#b01c1c'>" + $line + '＝人が数えるまで倉庫から出さない（仕入先へ頼む）' + $(if ([string]$ng[0].引当に使えない理由) { '・' + (Esc ([string]$ng[0].引当に使えない理由)) } else { '' }) + '</b>' }
            $o += $line
        }
    }
    return ($o -join '<br>')
}
# どの催事か当たっていない「倉庫から出した」の投稿（AIかおりの止まった物・未）。倉庫出しの行に添える＝二重に出さないため（21代目ボス 10/20：井上 10/23 は 10/15 の玉井さんの投稿の分の見込み）
$soukoMiate = @(); try { $akx = Read-JsonFile (Join-Path $planDir '_AIかおりの止まった物.json'); if ($akx) { $soukoMiate = @(@($akx.行) | Where-Object { $_ -and [string]$_.状態 -eq '未' -and ([string]$_.何が).Contains('倉庫から出した') }) } } catch {}
$tdy = (Get-Date).Date
$kyouC = [ordered]@{}; $shuuR = @(); $nochi = 0; $kakuR = @(); $matsuC = [ordered]@{}
foreach ($d in ($cases | Sort-Object { [string]$_.いちばん早い送る日 })) {
    if ($d.対象外 -eq $true) { continue }
    $tan = $(if ([string]$d.担当者) { [string]$d.担当者 + 'さん' } else { '担当者' })
    foreach ($c in @($d.候補)) {
        if (-not $c -or $c.候補外 -eq $true) { continue }
        $s0 = [string]$c.状態
        if ($DONE -contains $s0) { continue }
        $sd = $null; try { $sd = ([datetime]$c.送る日).Date } catch {}
        $n = $(if ($sd) { ($sd - $tdy).Days } else { 9999 })
        if ($STUCK -contains $s0) { $kakuR += [pscustomobject]@{ d = $d; c = $c; sd = $sd }; continue }
        if ($c.止め金) {
            $t = @($tomekin.止め金) | Where-Object { $_ -and [string]$_.案件ID -eq [string]$d.案件ID -and [string]$_.相手 -eq [string]$c.相手 } | Select-Object -First 1
            $why = $(if ($t -and ([string]$t.戻す条件).StartsWith('外さない')) { '玉井さんの決定で送らない' } else { '送る前の確かめ待ち（送らない）' + $(if ($t -and [string]$t.見直す日) { '・見直す日 ' + [string]$t.見直す日 + '（過ぎたら玉井さんへ知らせが届く）' } else { '' }) })
            $k = [string]$d.案件ID; if (-not $matsuC.Contains($k)) { $matsuC[$k] = [ordered]@{ d = $d; r = @() } }
            $matsuC[$k].r += ((Esc ([string]$c.相手)) + '：' + $why + $(if ($t) { ' ' + (Tg '［くわしく］' ("<span class='m'>" + (Esc (Hira ([string]$t.理由))) + '</span>')) } else { '' }))
            continue
        }
        if ($d.下書き可 -ne $true) {
            $k = [string]$d.案件ID
            if (-not $matsuC.Contains($k)) {
                $st = [string]$d.状態; $as = $askStatus[$k]
                $fs = $null; try { $fs = ([datetime][string]$d.いちばん早い送る日).Date } catch {}
                $tome = $null; try { if ([string]$as.最後に送った日時) { $lp = [datetime]([string]$as.最後に送った日時); if ($lp -gt (Get-Date)) { $tome = $lp } } } catch {}   # AIかおり27 10/20：最後に送った日時が先の日付＝その日まで催促を止めている（八木橋）
                if ($as -and $tome) { $why = $tan + 'への催促を ' + $tome.ToString('M/d') + ' まで止めています（玉井さんが引き取り中）' }
                elseif ($as -and ([string]$as.状況).StartsWith('返事待ち')) { $why = $tan + 'の答え待ち（' + (Esc (([string]$as.状況).Replace('返事待ち：', ''))) + '・AIかおりが聞いています・送った回数 ' + [string]$as.送った回数 + '）' }
                elseif ($as -and ([string]$as.状況) -eq 'まだ質問を出していない') { $why = $tan + 'にはまだ聞いていません（AIかおりが聞く前）' }
                elseif ($st -like '*OK待ち*' -or $st -like '*返事待ち*') { $why = $tan + 'の答え待ち（AIかおりが聞いています）' }
                else { $why = Esc (Yasashiku $st) }
                $matsuC[$k] = [ordered]@{ d = $d; r = @($why + '・いちばん早い送る日 ' + (Fmt-Hi $fs)) }
            }
            continue
        }
        if ($n -le 0) { $k = [string]$d.案件ID; if (-not $kyouC.Contains($k)) { $kyouC[$k] = [ordered]@{ d = $d; r = @() } }; $kyouC[$k].r += [pscustomobject]@{ c = $c; sd = $sd; n = $n } }
        elseif ($n -le 7) { $shuuR += [pscustomobject]@{ d = $d; c = $c; sd = $sd; n = $n } }
        else { $nochi++ }
    }
}
$osu2 = 0; foreach ($k in $kyouC.Keys) { $osu2 += @($kyouC[$k].r).Count }
$simple = New-Object Text.StringBuilder
[void]$simple.Append("<div class='m' style='margin:-4px 0 8px'>10/20 から画面を見やすくしました。上から順に「今日 送るもの」→「確かめること」だけ見れば大丈夫です。今までの表は、いちばん下の［くわしい表を開く］にあります。</div>")
# 1. 今日 送るもの（催事ごとのカード）
[void]$simple.Append("<div class='sec' style='margin-bottom:10px;border:2px solid #3a7bd5'>")
if ($osu2 -gt 0) {
    [void]$simple.Append("<div class='v' style='font-size:18px'>今日 送るもの：" + $osu2 + "件</div><div class='m'>青いボタン［下書きを作って開く］→ Outlook で中身を見て［送信］。送れば30分ほどで自動で「送った」になります（確かめるのは朝8:15〜夜9:45。夜に送った分は翌朝8:15に「送った」になります）。手で書いて送った時だけ、下の［くわしい表］のその行で［送った］を押してください。</div>")
    foreach ($k in $kyouC.Keys) {
        $d = $kyouC[$k].d
        [void]$simple.Append("<div class='card2'><div class='v'>" + (Esc ([string]$d.会場)) + "　<span class='m'>会期 " + (Kaiki $d) + "・担当 " + (Esc ([string]$d.担当者)) + "さん・納品 " + (Esc ([string]$d.納品.納品希望日)) + "</span></div><table>")
        foreach ($x in $kyouC[$k].r) {
            $c = $x.c; $nm = Naka-Matome $(if ([string]$c.中身全文) { [string]$c.中身全文 } else { [string]$c.中身 })
            $chu = @()
            foreach ($kk in @($kyokyuNG)) { if ($kk -and ([string]$c.中身全文 + [string]$c.中身).Contains([string]$kk.品名)) { $chu += "<b style='color:#b01c1c'>⚠ " + (Esc ([string]$kk.品名)) + " は今季足りません。送る前に玉井さんに「どこへ何kg配るか」を聞いてください</b>" } }
            if ($c.方法 -eq '倉庫出し') {
                $chu += (Souko-Info $d $c)
                if ($soukoMiate.Count) { $chu += "<b style='color:#b01c1c'>⚠ どの催事か当たっていない「倉庫から出した」の LINE が " + $soukoMiate.Count + "件あります。この分を既に出していないか、押す前に確かめてください</b> " + (Tg '［LINEの文］' ("<span class='m'>" + ((@($soukoMiate) | ForEach-Object { (Esc ([string]$_.中身)) }) -join '<br>') + '</span>')) }
            }
            $hiTxt = $(if ($x.n -lt 0) { "<b style='color:#b01c1c'>" + (Fmt-Hi $x.sd) + '<br>' + (-$x.n) + '日過ぎ</b>' } else { (Fmt-Hi $x.sd) + '<br>今日' })
            [void]$simple.Append("<tr><td style='width:22%'><b>" + (Esc ([string]$c.相手)) + "</b><br><span class='m'>" + (Esc ([string]$c.方法)) + "</span></td><td style='width:12%'>" + $hiTxt + "</td><td>" + $nm.sum + ' ' + (Tg '［中身を見る］' ("<span class='m'>" + $nm.list + '</span>')) + $(if ($chu.Count) { "<div class='m' style='margin-top:4px'>" + ($chu -join '<br>') + '</div>' } else { '' }) + "</td><td class='acts' style='width:26%'>" + (Btn-For $d $c) + "</td></tr>")
        }
        [void]$simple.Append("</table></div>")
    }
} else {
    $nx = @($shuuR | Sort-Object n | Select-Object -First 1)
    [void]$simple.Append("<div class='v' style='font-size:18px'>今日 送るものはありません</div><div class='m'>" + $(if ($nx.Count) { '次に送る日は <b>' + (Fmt-Hi $nx[0].sd) + '（あと' + $nx[0].n + '日）</b>です。まだ押さないでください。' } else { 'この7日に送るものもありません。' }) + "</div>")
}
[void]$simple.Append("</div>")
# 2. 確かめること（送ったかもしれない行・戻ってきたメール14日・相手の返事・LINEの依頼・送れたかの確かめ）
$kk2 = New-Object Text.StringBuilder; $kkN = 0
foreach ($x in $kakuR) { $kkN++; [void]$kk2.Append("<tr><td><b>" + (Esc ([string]$x.d.会場)) + "</b>・" + (Esc ([string]$x.c.相手)) + "<br><span class='m'>" + (Esc ([string]$x.c.状態)) + "</span></td><td class='acts'>" + (Btn-For $x.d $x.c) + "</td></tr>") }
$modR = @(); if ($mod) { $modR = @(@($mod.行) | Where-Object { $dd = $null; try { $dd = [datetime]([string]$_.受信) } catch {}; $dd -and $dd -gt (Get-Date).AddDays(-14) }) }
if ($modR.Count) { $kkN += $modR.Count; [void]$kk2.Append("<tr><td colspan='2'>戻ってきたメール（14日以内）" + $modR.Count + "通＝Outlook の受信トレイで確かめてください " + (Tg '［一覧］' ("<span class='m'>" + ((@($modR) | ForEach-Object { (Esc ([string]$_.受信)) + '　' + (Esc ([string]$_.件名)) + '　→ ' + (Esc ([string]$_.届かなかった宛先)) }) -join '<br>') + '</span>')) + "</td></tr>") }
if (@($henjiTe).Count) { $kkN += @($henjiTe).Count; [void]$kk2.Append("<tr><td colspan='2'>相手先の返事で気をつけるもの（欠品・遅れ・FAX）" + @($henjiTe).Count + "件 " + (Tg '［一覧］' ("<span class='m'>" + ((@($henjiTe) | ForEach-Object { (Esc ([string]$_.日時)) + '　<b>' + (Esc ([string]$_.種類)) + '</b>　' + (Esc ([string]$_.相手)) + '　' + (Esc ([string]$_.要点)) }) -join '<br>') + '</span>')) + "</td></tr>") }
# 2026-10-23 b6①②（玉井さんのハンコ 10/22 03:09・案＝蔵人運用\design-docs\hacchu-board-teokuri-tashikame-an-2026-10-21.md）：熊田さんが手で送ったFAXを、まだ送っていない行に当てて聞く。機械は自動で「送った」にしない。
#   まだ送っていない FAX の行（止め金・候補外・対象外は除く）の番号に、送る日の前後3日以内の「FAX送れた」（_相手の返事.json・書き手 aite_henji）があれば、行ごとに1行。
#   ［はい］＝今ある mark 送った／［いいえ］＝今ある lineok で鍵「FAX外|〈送信完了の鍵〉|〈案件ID〉|〈相手〉」を _LINE依頼の確認済み.json に足す＝その組は二度と出ない（新しい置き場・欄は作らない）。
#   発注案に無い番号の FAX は画面に出さない（_相手の返事.json の行に「誰宛か」＝aite_henji が付ける）
if ($henji) {
    $faxEv = @(@($henji.返事) | Where-Object { $_ -and [string]$_.種類 -eq 'FAX送れた' -and [string]$_.要点 -match '（(\d{6,})宛' })
    foreach ($d in $cases) {
        if ($d.対象外 -eq $true -or ([string]$d.状態).StartsWith('送らないでください')) { continue }
        foreach ($c in @($d.候補)) {
            if (-not $c -or $c.候補外 -eq $true -or $c.止め金 -or [string]$c.状態 -ne '候補' -or [string]$c.方法 -ne 'FAX') { continue }
            $fxNum = ([string]$c.宛先) -replace '[^\d]', ''; if ($fxNum.Length -lt 7) { continue }; $fxNum7 = $fxNum.Substring($fxNum.Length - 7)
            $fxSd = $null; try { $fxSd = ([datetime][string]$c.送る日).Date } catch { continue }
            foreach ($e in $faxEv) {
                $fxEn = $(if ([string]$e.要点 -match '（(\d{6,})宛') { $Matches[1] } else { '' }); if (-not $fxEn.EndsWith($fxNum7)) { continue }
                $fxEd = $null; try { $fxEd = [datetime]([string]$e.日時) } catch { continue }
                if ([math]::Abs(($fxEd.Date - $fxSd).TotalDays) -gt 3) { continue }
                $fxK = 'FAX外|' + [string]$e.鍵 + '|' + [string]$d.案件ID + '|' + [string]$c.相手
                if ($lineOKKeys -contains $fxK) { continue }
                $fxHoka = @(@($e.当てた) | Where-Object { $_ } | ForEach-Object { [string]$_.案件ID + '（' + [string]$_.ボードの状態 + '）' })
                $fxCid = Hex ([string]$d.案件ID); $fxAid = Hex ([string]$c.相手); $fxKh = Hex $fxK
                $kkN++
                [void]$kk2.Append("<tr><td>手で送ったFAXの確かめ：<b>" + (Esc ([string]$d.会場)) + "</b>（会期 " + (Kaiki $d) + "）・" + (Esc ([string]$c.相手)) + "の行（送る日 " + (Fmt-Hi $fxSd) + "・ボードではまだ送っていない）<br><span class='m'>" + (Esc ($fxEd.ToString('M/d HH:mm'))) + " に " + (Esc ([string]$c.相手)) + " へ FAX が送れています（" + (Esc ([string]$e.要点)) + "）。<b>この行の分ですか？</b>" + $(if ($fxHoka.Count) { '　このFAXは ' + (Esc ($fxHoka -join '・')) + ' にも当たっています。' } else { '' }) + "</span></td><td class='acts'><button class='p' onclick=""if(confirm('この行の分として「送った」にします。中身は画面の候補の数で記録します。よろしいですか？'))act('mark','$fxCid','$fxAid','送った')"">はい（この行の分）</button><button onclick=""if(confirm('このFAXは、この行の分ではない、と記録します。この組はもう出ません。'))act('lineok','$fxKh','','')"">いいえ（別の分）</button></td></tr>")
            }
        }
    }
}
# 2026-10-29 送った品の確かめの読み手（AIかおり33 10/24 の受け渡しの形＝_LINEで1タップ.json の欄「送った品の確かめ」・26代目ボス 10/29 の頼み・10/25 の約束の遅れ分・点検役 10/29 の指摘を反映）
#   熊田さんの LINE のボタン（AIかおり）で「頼んであるか」を聞いた品を、確かめることの一覧に出す。押し直しは同じ id の最後が正。
#   答え＝頼んだ→出さない（閉じる）
#        ／頼んでいない→「足りない分を追加で頼みますか［追加の下書きを作る］［頼まない］」。数は今の発注ボードの行−送った物で出し、聞いた時の数（10/24）も並べる。
#          ［追加の下書きを作る］＝予定を直す窓（数は熊田さんが入れる）。窓で〈相手〉〈頼み直し〉を答えの後に足してあれば出さない（穴A 2段目と同じ守り＝二度押しで重ねない）
#          ［頼まない］＝今ある lineok で鍵「送った品|〈id〉|頼まない」
#        ／未回答→「確かめ中」＋確かめるための FAX のメモ（同じ番号の相手への送信完了で、どの発注にも当たっていない物・その相手へ実際に送った日〜今日）
#   閉じるのは熊田さん。機械は「頼んだ」と決めない
function Sc-Su([string]$zen, [string]$hin) {
    # 「品 1c/s／品 7c/s」から、その品の c/s を読む。返す物＝@{ N＝数（読めない・決められない時は $null）; Hit＝当たった所の数 }
    #   当て方＝品名そのもの（例「わさびさきいか 75g」）を含む所。無ければ先頭の語で始まる所。どちらも当たる所が2つ以上なら決めない（荷姿違い・同じ品の2行）
    #   当たった所に c/s が無い（kg 書きなど）時は読めない＝$null（「入っていない」と誤らない）
    $parts = @($zen -split '／' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $hit = @($parts | Where-Object { $_.Contains($hin) })
    if (-not $hit.Count) { $w = ($hin -split '\s')[0]; if ($w) { $hit = @($parts | Where-Object { $_.StartsWith($w) }) }; if ($hit.Count -gt 1) { return @{ N = $null; Hit = $hit.Count } } }
    if (-not $hit.Count) { return @{ N = 0; Hit = 0 } }
    if ($hit.Count -gt 1) { return @{ N = $null; Hit = $hit.Count } }   # 同じ名の所が2つ以上（荷姿違い・同じ品の2行）＝機械では決めない
    $n = 0; foreach ($t in $hit) { if ($t -match '(\d+(?:\.\d+)?)\s*c/s\s*$') { $n += [double]$Matches[1] } else { return @{ N = $null; Hit = $hit.Count } } }
    return @{ N = $n; Hit = $hit.Count }
}
if ($oneTap -and $oneTap.送った品の確かめ) {
    $scLast = [ordered]@{}; foreach ($s in @($oneTap.送った品の確かめ)) { if ($s -and [string]$s.id) { $scLast[[string]$s.id] = $s } }
    $scFax = @(); if ($henji) { $scFax = @(@($henji.返事) | Where-Object { $_ -and [string]$_.種類 -eq 'FAX送れた' -and -not @(@($_.当てた) | Where-Object { $_ }).Count }) }
    foreach ($s in $scLast.Values) {
        $scAns = [string]$s.答え; if ($scAns -eq '頼んだ') { continue }
        $scK = '送った品|' + [string]$s.id + '|頼まない'; if ($lineOKKeys -contains $scK) { continue }
        $d = @($cases | Where-Object { [string]$_.案件ID -eq [string]$s.案件ID }) | Select-Object -First 1; if (-not $d) { continue }
        $scC = @(@($d.候補) | Where-Object { $_ -and [string]$_.相手 -eq [string]$s.相手 }) | Select-Object -First 1
        $scAite = Esc ([string]$s.相手); $scHin = Esc ([string]$s.品名)
        $scHead = "<b>" + (Esc ([string]$d.会場)) + "（会期 " + (Kaiki $d) + "）｜" + $scAite + "　" + $scHin + "</b>"
        $scDare = $(if ([string]$s.だれが) { [string]$s.だれが } else { '答えた人は不明' })
        if ($scAns -eq '頼んでいない') {
            $scAt = $null; try { $scAt = [datetime]([string]$s.日時) } catch {}
            $scTashita = @(@($d.予定の直し.一覧) | Where-Object { $_ -and $_.行 -and ([string]$_.行.頼む先 -eq ([string]$s.相手 + '〈頼み直し〉')) -and $(try { -not $scAt -or ([datetime]([string]$_.いつ)) -gt $scAt } catch { $false }) }).Count
            if ($scTashita) { continue }
            $scN = [array]::IndexOf(@($cases), $d) + 1; $scKh = Hex $scK
            $scBo = $null; $scOk = $null   # 読めない・分からない時は $null のまま（0 と読まない）
            if ($scC) {
                $scBoR = Sc-Su $(if ([string]$scC.中身全文) { [string]$scC.中身全文 } else { [string]$scC.中身 }) ([string]$s.品名); if ($scBoR.Hit) { $scBo = $scBoR.N }
                if ([string]$scC.送った中身の読み -eq '実物' -and [string]$scC.送った時の中身) { $scOk = (Sc-Su ([string]$scC.送った時の中身) ([string]$s.品名)).N }
            }
            $scSa = $(if ($null -ne $scBo -and $null -ne $scOk) { [double]$scBo - [double]$scOk } else { $null })
            $scSuTxt = $(if ($null -ne $scSa -and $scSa -gt 0) { "今の発注ボードの" + $scAite + "の行は " + $scBo + "c/s、最初に送った物は " + $scOk + "c/s＝足りないのは <b>" + $scSa + "c/s</b>（聞いた時の数は " + (Esc ([string]$s.数量)) + "・後から追加で送った FAX は数えていません）" } else { "足りない数は機械では出せません（聞いた時の数は " + (Esc ([string]$s.数量)) + "・今の発注ボードの" + $scAite + "の行で確かめてください）" })
            $kkN++
            [void]$kk2.Append("<tr><td>" + $scHead + "<br>答え＝頼んでいない（" + (Esc $scDare) + "・" + (Esc ([string]$s.日時)) + "）。<b>足りない分を追加で頼みますか。</b><br><span class='m'>" + $scSuTxt + "。［追加の下書きを作る］＝予定を直す窓が開きます。「これから頼む」で" + $scAite + "に数を入れると、新しい便の下書きになります。</span></td><td class='acts'><button class='p' onclick=""if(confirm('予定を直す窓を開きます。「これから頼む」で " + $scAite + " に足りない数を入れてください。'))naoshi($scN)"">追加の下書きを作る</button><button onclick=""if(confirm('追加では頼みません、と記録します。何も送りません。'))act('lineok','$scKh','','')"">頼まない</button></td></tr>")
            continue
        }
        # 未回答（と分からない答え）＝確かめ中
        $scZaiTxt = ''
        if ($scC -and [string]$scC.方法 -ne 'FAX') {
            $scZaiTxt = $scAite + 'は FAX で頼む相手ではない（頼み方＝' + (Esc ([string]$scC.方法)) + '）ので、FAX のメモは並べられません'
        } else {
            # 幅＝この催事でその相手へ実際に送った日（無ければ印の日時・それも無ければ初日の30日前）〜今日と初日の遅い方
            $scKs = $null; try { $scKs = ([datetime][string]$d.会期開始).Date } catch {}
            $scFrom = $null; if ($scKs) { $scFrom = $scKs.AddDays(-30) }
            if ($scC) { foreach ($scF in @([string]$scC.実際に送った日時, [string]$scC.日時)) { if ($scF) { try { $scFrom = ([datetime]$scF).Date; break } catch {} } } }
            $scTo = (Get-Date).Date; if ($scKs -and $scKs -gt $scTo) { $scTo = $scKs }
            $scZai = @()
            if ($scFrom) {
                foreach ($e in $scFax) {
                    if ([string]$e.誰宛か -ne [string]$s.相手) { continue }
                    $scEd = $null; try { $scEd = [datetime]([string]$e.日時) } catch { continue }
                    if ($scEd.Date -gt $scTo -or $scEd.Date -lt $scFrom) { continue }
                    $scKen = $(if ([string]$e.件名 -match '［件名:(.+?)］') { $Matches[1] } else { '' })
                    $scZai += ((Fmt-Hi $scEd.Date) + ' ' + $scEd.ToString('HH:mm') + $(if ($scKen) { '「' + $scKen + '」' } else { '' }))
                }
            }
            $scZaiTxt = $(if ($scZai.Count) { $scAite + 'へ送れた FAX で、どの催事の分か機械には分からない物＝' + (Esc ($scZai -join '／')) + '。同じ相手の別の催事の分が混ざることがあります。中身は eFax の送信履歴で見てください' } else { $scAite + 'へ送れた FAX で、どの催事の分か分からない物はありません' })
        }
        $scKg = [string]$s.期限; $scOsoi = $false; try { $scOsoi = ((Get-Date).Date -gt ([datetime]$scKg).Date) } catch {}
        $kkN++
        [void]$kk2.Append("<tr><td colspan='2'>" + $scHead + $(if (([string]$s.品名).Contains([string]$s.数量)) { '' } else { "（" + (Esc ([string]$s.数量)) + "）" }) + "<br><b>確かめ中</b>：" + $scAite + "に頼んであるかを、熊田さんの LINE に聞いています。答えは LINE のボタンで。" + $(if ($scOsoi) { "<span class='pill ng'>期限 " + (Esc $scKg) + " を過ぎています</span>" } else { '' }) + "<br><span class='m'>確かめるためのメモ：" + $scZaiTxt + "。聞いた中身＝" + (Esc ([string]$s.もとの発言)) + "</span></td></tr>")
    }
}
# 2026-10-23 穴A（24代目ボスの裁定）：送ったメールの数と発注ボードの数が違い、送った後の熊田さんの修正の記録も無い行（送った中身の読み＝確かめ待ち・書き手 process_budget_files）＝熊田さんに「仕入先に届いているのはどちらの数か」をボタンで聞く（字は打たせない・k1c）。
#   ［メールの数］［発注ボードの数］＝今ある lineok で鍵「送った中身|〈案件ID〉|〈相手〉|メール／ボード」を _LINE依頼の確認済み.json に足す→次の作り直しで読みが決まり、珍味グループへの発注の報告に出る。新しい置き場・欄は作らない
#   ⚠ 2026-10-23 玉井さん（版6 12枚目［直してほしい］「文章の内容が全く理解できない、熊田もわからない」）＝この1行は、24代目ボスが言葉を直して送るまで出さない。言葉が来たら下の $anaAKakuWords を $true にし、文を差し替える
# 2026-10-23 18:32 24代目ボス（玉井さん 18:27 版7 12枚目「デメリットの解決の仕方を見ても、うまくできていると思うので、君の提案通りに進めても良い」）＝版7 12枚目の言葉で出す。
#   1段目＝「〈会場 初日〉｜〈相手〉 〈品〉／〈送った日〉に送った〈メール/FAX〉は〈X〉、発注ボードは〈Y〉です。〈相手〉に頼んであるのはどちらですか。［X］［Y］」（今ある lineok の鍵 メール／ボード）
#   2段目＝メールの数を押し、品1つで メール＜ボード の時だけ「予定はYです。足りないY−Xを追加で頼みますか。［追加の下書きを作る］［Xのままでよい］」
#     ［追加の下書きを作る］＝今ある予定を直す窓を開く（「これから頼む」で送った相手に足すと〈頼み直し〉の新しい便＝board_build の窓の作り）。窓で足した記録（予定の直し）が送った日時より後にあれば2段目は消える
#     ［Xのままでよい］＝lineok の鍵「送った中身|〈案件ID〉|〈相手〉|メールのまま」
#   AIが埋めた所（ボスへ1行）：品が2つ以上・c/s でない行は［メールの数］［発注ボードの数］の名前で聞き、2段目は出さない
#   期限＝会期の3日前。過ぎても押されない行は上の困りごと（送った数の確かめが期限を過ぎた）に1行・群の報告は両方の数（AIかおり group_report.py）
$anaAKakuWords = $true
function Tk-Ryou([string]$s) {
    $t = ([string]$s).Trim(); if (-not $t -or $t.Contains('／')) { return $null }
    if ($t -match '^(.*?)\s*(\d+(?:\.\d+)?)\s*(c/s|ケース)\s*$') { return [pscustomobject]@{ Hin = ($Matches[1].Trim(' ・･')); N = [double]$Matches[2] } }
    return $null
}
function Tk-Su([double]$n) { return ($n.ToString('0.##') + 'ケース') }
# 2026-10-23 25代目ボス（r13 玉井さんハンコ 21:51・手当て dm）：品が2つ以上の行は、送ったメールの中身と発注ボードの中身を品ごとに比べ、差だけを文にする（同じなら空）
function Tk-Sa([string]$mail, [string]$board) {
    $m = @{}; $b = @{}; $ord = New-Object System.Collections.ArrayList
    foreach ($p in ([string]$mail -split '／')) { $r = Tk-Ryou $p; if ($r -and $r.Hin) { $m[$r.Hin] = $r.N; if (-not $ord.Contains($r.Hin)) { [void]$ord.Add($r.Hin) } } }
    foreach ($p in ([string]$board -split '／')) { $r = Tk-Ryou $p; if ($r -and $r.Hin) { $b[$r.Hin] = $r.N; if (-not $ord.Contains($r.Hin)) { [void]$ord.Add($r.Hin) } } }
    if (-not $m.Count -or -not $b.Count) { return '' }
    $out = @()
    foreach ($h in $ord) {
        if ($m.ContainsKey($h) -and $b.ContainsKey($h)) { $d = $b[$h] - $m[$h]; if ($d -gt 0) { $out += ($h + '：発注ボードより' + (Tk-Su $d) + '少ない') } elseif ($d -lt 0) { $out += ($h + '：発注ボードより' + (Tk-Su (-$d)) + '多い') } }
        elseif ($b.ContainsKey($h)) { $out += ($h + '：メールに無い（発注ボードは' + (Tk-Su $b[$h]) + '）') }
        else { $out += ($h + '：発注ボードに無い（メールは' + (Tk-Su $m[$h]) + '）') }
    }
    return ($out -join '／')
}
$tkTdy = (Get-Date).Date
foreach ($d in $(if ($anaAKakuWords) { $cases } else { @() })) {
    if ($d.対象外 -eq $true) { continue }
    $tkN = [array]::IndexOf(@($cases), $d) + 1
    $tkKigen = $null; try { $tkKigen = ([datetime][string]$d.会期開始).Date.AddDays(-3) } catch {}
    $tkKgTxt = $(if ($tkKigen) { $tkKigen.ToString('M/d') } else { '会期の3日前' })
    $tkKai = (Esc ([string]$d.会場)) + $(if (([string]$d.会期開始).Length -ge 10) { ' ' + ([datetime][string]$d.会期開始).ToString('M/d') } else { '' })
    foreach ($c in @($d.候補)) {
        if (-not $c -or $c.候補外 -eq $true) { continue }
        $k0 = '送った中身|' + [string]$d.案件ID + '|' + [string]$c.相手
        $tkHou = $(if ([string]$c.方法 -eq 'FAX') { 'FAX' } else { 'メール' })
        $tkAt = [string]$(if ([string]$c.実際に送った日時) { $c.実際に送った日時 } else { $c.日時 })
        $tkAtD = $tkAt; try { $tkAtD = ([datetime]$tkAt).ToString('M/d') } catch {}
        $tkZen = $(if ([string]$c.中身全文) { [string]$c.中身全文 } else { [string]$c.中身 })
        $mR = Tk-Ryou ([string]$c.送った時の中身); $bR = Tk-Ryou $tkZen
        $tkOne = ($null -ne $mR -and $null -ne $bR)
        $tkHin = $(if ($tkOne -and $bR.Hin) { '　' + (Esc $bR.Hin) } else { '' })
        $tkAite = Esc ([string]$c.相手)
        if ([string]$c.送った中身の読み -eq '確かめ待ち') {
            $tkM = Hex ($k0 + '|メール'); $tkB = Hex ($k0 + '|ボード')
            $mTxt = $(if ($tkOne) { Tk-Su $mR.N } else { '「' + [string]$c.送った時の中身 + '」' }); $bTxt = $(if ($tkOne) { Tk-Su $bR.N } else { '「' + $tkZen + '」' })
            $mBtn = $(if ($tkOne) { Tk-Su $mR.N } else { $tkHou + 'の数' }); $bBtn = $(if ($tkOne) { Tk-Su $bR.N } else { '発注ボードの数' })
            $tkOsoi = ($tkKigen -and $tkTdy -ge $tkKigen)
            $kkN++
            [void]$kk2.Append("<tr><td><b>" + $tkKai + "｜" + $tkAite + $tkHin + "</b><br>" + (Esc $tkAtD) + " に送った" + $tkHou + "は" + (Esc $mTxt) + "、発注ボードは" + (Esc $bTxt) + "です。<b>" + $tkAite + "に頼んであるのはどちらですか。</b><br><span class='m'>" + $(if ($tkOsoi) { "<span class='pill ng'>期限 " + $tkKgTxt + " を過ぎています</span> 珍味グループの報告には両方の数を並べて出しています。" } else { "期限 " + $tkKgTxt + "（会期の3日前）。押すまで、珍味グループの報告にはこの行を出しません。" }) + "送った" + $tkHou + "の数は info@ の送信済みで探せた分です（kumada@ の箱は入っていません）。</span></td><td class='acts'><button class='p' onclick=""if(confirm('" + $tkAite + "に頼んであるのは " + (Esc $mBtn) + "、と記録します。何も送りません。'))act('lineok','$tkM','','')"">" + (Esc $mBtn) + "</button><button onclick=""if(confirm('" + $tkAite + "に頼んであるのは " + (Esc $bBtn) + "、と記録します。何も送りません。'))act('lineok','$tkB','','')"">" + (Esc $bBtn) + "</button></td></tr>")
        } elseif ($tkOne -and $mR.N -lt $bR.N -and ($lineOKKeys -contains ($k0 + '|メール')) -and -not ($lineOKKeys -contains ($k0 + '|メールのまま'))) {
            $tkAtDt = $null; try { $tkAtDt = [datetime]$tkAt } catch {}
            $tkTashita = @(@($d.予定の直し.一覧) | Where-Object { $_ -and $_.行 -and ([string]$_.行.頼む先 -eq ([string]$c.相手 + '〈頼み直し〉')) -and $(try { -not $tkAtDt -or ([datetime]([string]$_.いつ)) -gt $tkAtDt } catch { $false }) }).Count
            if ($tkTashita) { continue }
            $tkSa = $bR.N - $mR.N; $tkMm = Hex ($k0 + '|メールのまま')
            $kkN++
            [void]$kk2.Append("<tr><td><b>" + $tkKai + "｜" + $tkAite + $tkHin + "</b><br>予定は" + (Esc (Tk-Su $bR.N)) + "です。<b>足りない" + (Esc (Tk-Su $tkSa)) + "を追加で頼みますか。</b><br><span class='m'>［追加の下書きを作る］＝予定を直す窓が開きます。「これから頼む」で" + $tkAite + "に" + (Esc (Tk-Su $tkSa)) + "を入れると、新しい便の下書きになります。</span></td><td class='acts'><button class='p' onclick=""if(confirm('予定を直す窓を開きます。「これから頼む」で " + $tkAite + " に " + (Esc (Tk-Su $tkSa)) + " を入れてください。'))naoshi($tkN)"">追加の下書きを作る</button><button onclick=""if(confirm('" + (Esc (Tk-Su $mR.N)) + " のままにします。何も送りません。'))act('lineok','$tkMm','','')"">" + (Esc (Tk-Su $mR.N)) + "のままでよい</button></td></tr>")
        } elseif (-not $tkOne -and ($lineOKKeys -contains ($k0 + '|メール'))) {
            # 2026-10-23 25代目ボス（r13 玉井さんハンコ 21:51・手当て dm）：品が2つ以上の行で熊田さんが［メールの数］を押した後は、発注ボードとの差を品ごとに同じ一覧に出す（2段目のボタンは出さない＝r13 (3)）。
            #   予定を直す窓で〈相手〉〈頼み直し〉を送った日時より後に足してあれば出さない（1段目の2段目と同じ）。差が無ければ出さない
            $tkAtDt = $null; try { $tkAtDt = [datetime]$tkAt } catch {}
            $tkTashita = @(@($d.予定の直し.一覧) | Where-Object { $_ -and $_.行 -and ([string]$_.行.頼む先 -eq ([string]$c.相手 + '〈頼み直し〉')) -and $(try { -not $tkAtDt -or ([datetime]([string]$_.いつ)) -gt $tkAtDt } catch { $false }) }).Count
            if ($tkTashita) { continue }
            $tkSa2 = Tk-Sa ([string]$c.送った時の中身) $tkZen
            if ($tkSa2) {
                $kkN++
                [void]$kk2.Append("<tr><td><b>" + $tkKai + "｜" + $tkAite + "</b><br>" + $tkHou + "の数で確かめ済みです。発注ボードとの差：<b>" + (Esc $tkSa2) + "</b><br><span class='m'>追加で頼む時は、予定を直す窓の「これから頼む」で " + $tkAite + " に足してください（送った相手なので、追加の便になります）。差がこのままでよければ、何もしなくて大丈夫です。</span></td><td class='acts'></td></tr>")
            }
        }
    }
}
# LINEの発注の依頼：3日以内は1件ずつ、それより前は畳む（10/15 の古い依頼で一覧が埋まり、新しい依頼が見えなくなるため）。ボタンは同じ［LINEを見ました］
$lineNew = New-Object Text.StringBuilder; $lineOld = New-Object Text.StringBuilder; $lineOldN = 0
foreach ($q in @(@($machi) | Where-Object { $_ } | Sort-Object { [string]$_.日時 } -Descending)) {
    $kagi = Hex ([string]$q.日時 + '|' + [string]$q.会場)
    $qd = $null; try { $qd = [datetime]([string]$q.日時) } catch {}
    # 2026-10-23 A群 F14（24代目ボス裁定）：止め金「外さない（玉井さんの決定）」の催事の依頼には「ストップ」を出す（例＝ひらかた 10/29・玉井さん 10/20「全てストップ」）。板挟みにしない。ボタンは同じ
    $tomeAll = $false; $cid4 = [string]$q.案件ID
    if (-not $cid4) { $cm4 = @($cases | Where-Object { [string]$_.会場 -eq [string]$q.会場 }); if ($cm4.Count -eq 1) { $cid4 = [string]$cm4[0].案件ID } }
    # 2026-10-23 16時 直し（在庫4 の知らせ・尾崎さん 15:51 の補填）：止めた時より後に届いた依頼は「ストップ」にしない＝★10/20 夜「先走って頼んだ分は玉井さんか熊田さんの許可・OKなら正式な発注として通す」
    $tomeAt = $null
    if ($cid4 -and $tomekin) { foreach ($tm in @(@($tomekin.止め金) | Where-Object { $_ -and [string]$_.案件ID -eq $cid4 -and -not [string]$_.期限 -and ([string]$_.戻す条件).StartsWith('外さない') })) { $ta = $null; try { $ta = [datetime]([string]$tm.いつ) } catch {}; if ($ta -and (-not $tomeAt -or $ta -gt $tomeAt)) { $tomeAt = $ta } } }
    $tomeNew = $false
    if ($tomeAt) { if ($qd -and $qd -gt $tomeAt) { $tomeNew = $true } else { $tomeAll = $true } }
    $row = "<tr><td>LINEの発注の依頼：<b>" + (Esc ([string]$q.会場)) + "</b>・" + (Esc ([string]$q.だれが)) + "（" + (Esc ([string]$q.日時)) + "）" + $(if ($tomeAll) { "<span class='pill ng'>ストップ（玉井さんの決定・この催事は送りません）</span> 確かめは要りません " } elseif ($tomeNew) { "<span class='pill wn'>止めた後に届いた新しい依頼</span> この催事は玉井さんの決定で止めています。<b>頼むには玉井さんか熊田さんの許可が要ります</b>（許可が出たら正式な発注として通します）。先に送っていないかも確かめてください " } else { "＝先に送っていないか確かめる " }) + (Tg '［本文］' ("<span class='m'>" + (Esc ([string]$q.本文)) + '</span>')) + "</td><td class='acts'><button onclick=""act('lineok','$kagi','','')"">LINEを見ました</button></td></tr>"
    if ($qd -and $qd -gt (Get-Date).AddDays(-3)) { $kkN++; [void]$lineNew.Append($row) } else { $lineOldN++; [void]$lineOld.Append($row) }
}
[void]$kk2.Append($lineNew.ToString())
if ($lineOldN) { $kkN++; [void]$kk2.Append("<tr><td colspan='2'>3日より前のLINEの発注の依頼 " + $lineOldN + "件（まだ［LINEを見ました］が押されていない） " + (Tg '［一覧］' ("<table>" + $lineOld.ToString() + "</table>")) + "</td></tr>") }
if ($vMin -gt 1440) { $kkN++; [void]$kk2.Append("<tr><td colspan='2'>送れたかの確かめ：" + $(if ($vMin -ge 999999) { 'まだ一度もしていません' } else { [string][int]($vMin / 1440) + '日前' }) + "＝右上の［送ったか確かめる］を押してください（1〜4分）</td></tr>") }
# 2026-10-29 13枚目：文字の注文＝頼む先を熊田さんが決める（予定を直す窓で入れる）。［決めた］で閉じる（何も送らない）
foreach ($d in $cases) {
    if (-not (Mj-Deru $d)) { continue }
    foreach ($m in @(Mj-Rows $d)) {
        $mjN2 = [array]::IndexOf(@($cases), $d) + 1; $mjKh = Hex (Mj-Key $d $m)
        $mjSd2 = $null; try { $mjSd2 = ([datetime][string]$d.いちばん早い送る日).Date } catch {}
        $mjOsoi = ($mjSd2 -and ($mjSd2 - (Get-Date).Date).Days -le 3)
        $kkN++
        [void]$kk2.Append("<tr><td><b>" + (Esc ([string]$d.会場)) + "（会期 " + (Kaiki $d) + "）｜" + $(if (Mj-Dake $m) { '文字だけの答え：' } else { '文字の注文：' }) + (Esc (Mj-Ji $m)) + "</b>（" + (Esc ([string]$m.理由)) + "）<br><span class='m'>" + $(if ($mjSd2) { $(if ($mjOsoi) { "<span class='pill ng'>送る日 " + (Fmt-Hi $mjSd2) + "</span> " } else { '送る日 ' + (Fmt-Hi $mjSd2) + '。' }) } else { '' }) + $(if (Mj-Dake $m) { '担当者の答えが文字だけで、数に直せていません。下書きは担当者の直しの前の数です。答えを読んで、［予定を直す窓を開く］で数を直してから送ってください。直したら（直さなくてよければ）［決めた］を押します。' } else { '担当者が文字で書いた注文で、下書きに入れられませんでした。どこへ頼むかを決めて、［予定を直す窓を開く］の「これから頼む」で入れてください。頼まないと決めた時も［決めた］を押します。この催事の他の相手の下書きは止めていません。' }) + "</span></td><td class='acts'><button class='p' onclick=""naoshi($mjN2)"">予定を直す窓を開く</button><button onclick=""if(confirm('この文字の注文は決めた（窓で入れた・頼まない）、と記録します。何も送りません。'))act('lineok','$mjKh','','')"">決めた</button></td></tr>")
    }
}
if ($kkN) { [void]$simple.Append("<div class='sec' style='margin-bottom:10px;border:2px solid #d8a600'><div class='v'>確かめること：" + $kkN + "件</div><table>" + $kk2.ToString() + "</table></div>") }
# 3. この7日で送るもの（まだ押さない）・4. 待っている物（熊田さんは何もしない）
$sh = (@($shuuR | Sort-Object n) | ForEach-Object { (Fmt-Hi $_.sd) + '　<b>' + (Esc ([string]$_.d.会場)) + '</b>（会期 ' + (Kaiki $_.d) + '）・' + (Esc ([string]$_.c.相手)) + "<span class='m'>（担当 " + (Esc ([string]$_.d.担当者)) + "さん）</span>" }) -join '<br>'
[void]$simple.Append("<div class='sec' style='margin-bottom:10px'><div class='v'>この7日で送るもの：" + $shuuR.Count + "件 <span class='m'>（まだ押さない・送る日になると上に上がります）" + $(if ($nochi) { '　その先：' + $nochi + '件' } else { '' }) + "</span></div>" + $(if ($shuuR.Count) { Tg '［一覧を見る］' ("<div class='m' style='margin-top:4px;line-height:1.7'>" + $sh + '</div>') } else { '' }) + "</div>")
$askAt = ''; try { if (Test-Path $askPath) { $askAt = ([datetime]((Get-Content $askPath -Raw -Encoding UTF8 | ConvertFrom-Json).作った時刻)).ToString('M/d HH:mm') } } catch {}
$mt = (@($matsuC.Keys) | ForEach-Object { $e = $matsuC[$_]; $d = $e.d; '<b>' + (Esc ([string]$d.会場)) + '</b>（会期 ' + (Kaiki $d) + "）<span class='m'>担当 " + (Esc ([string]$d.担当者)) + "さん</span><br>　" + ($e.r -join '<br>　') }) -join '<br>'
[void]$simple.Append("<div class='sec' style='margin-bottom:10px'><div class='v'>待っている物：" + $matsuC.Count + "催事 <span class='m'>（熊田さんは何もしなくて大丈夫です" + $(if ($askAt) { '・AIかおりの聞き取りは ' + $askAt + ' 時点' } else { '' }) + "）</span></div>" + $(if ($matsuC.Count) { Tg '［一覧を見る］' ("<div class='m' style='margin-top:4px;line-height:1.7'>" + $mt + '</div>') } else { '' }) + "</div>")
# ===== シンプルな上の画面 ここまで =====

$css = @'
body{font-family:"Yu Gothic UI","Meiryo UI",sans-serif;font-size:13px;margin:0;padding:12px;background:#f6f6f4;color:#222}
h1{font-size:16px;margin:0 0 8px}.bar{display:flex;justify-content:space-between;align-items:center;gap:8px;margin-bottom:10px}
.wrap{display:flex;gap:12px;align-items:flex-start}.left{width:300px;flex:none}.right{flex:1}
.card{border:1px solid #ddd;border-radius:10px;padding:8px 10px;background:#fff;cursor:pointer;margin-bottom:8px}.card.sel{border-color:#3a7bd5;background:#eaf2fd}
.v{font-size:14px;font-weight:bold}.m{font-size:12px;color:#666}.sec{border:1px solid #ddd;border-radius:10px;padding:10px 12px;background:#fff}
.head{display:flex;justify-content:space-between;align-items:center;margin-bottom:6px}
.pill{display:inline-block;font-size:11px;padding:2px 8px;border-radius:999px;margin-top:4px}.ok{background:#e3f5e8;color:#1e7b3a}.wn{background:#fff3d6;color:#8a5a00}.ng{background:#fde5e5;color:#b01c1c}.nt{background:#eee;color:#555}
table{width:100%;border-collapse:collapse;margin-top:6px}th{font-size:11px;color:#666;text-align:left;padding:4px 6px;border-bottom:1px solid #ddd}td{padding:6px;border-bottom:1px solid #eee;vertical-align:top;font-size:12px}
button{font-size:12px;padding:4px 8px;border-radius:6px;border:1px solid #bbb;background:#fafafa;cursor:pointer;margin:1px}button.p{background:#3a7bd5;color:#fff;border-color:#3a7bd5}
pre.plan{font-family:"MS Gothic",monospace;font-size:12px;background:#fbfbf9;border:1px solid #e3e3df;border-radius:8px;padding:8px;white-space:pre-wrap;max-height:420px;overflow:auto}
.acts{white-space:nowrap}.note{font-size:12px;color:#8a5a00;background:#fff8e6;padding:6px 8px;border-radius:8px;margin:6px 0}
.tabs{display:flex;gap:8px;margin-bottom:10px}
.tab{flex:1;text-align:left;padding:9px 12px;border:1px solid #ddd;border-radius:10px;background:#fff;cursor:pointer;position:relative}
.tab.sel{border-color:#3a7bd5;background:#eaf2fd}.tab .n{font-size:14px;font-weight:bold}
.tgl{font-size:12px;color:#3a7bd5;text-decoration:underline;cursor:pointer;margin-left:4px}.card2{border:1px solid #cfd8e3;border-radius:10px;background:#fbfdff;padding:8px 10px;margin:8px 0}
.badge{position:absolute;top:6px;right:8px;min-width:18px;height:18px;line-height:18px;padding:0 5px;border-radius:999px;background:#e02424;color:#fff;font-size:11px;text-align:center;font-weight:bold}
'@
$html = @"
<html><head><meta http-equiv="x-ua-compatible" content="IE=edge"><meta charset="utf-8"><title>発注ボード</title>
<hta:application id="app" applicationname="HacchuBoard" scroll="yes" singleinstance="yes" windowstate="maximize" />
<style>$css</style></head><body>
<div id="busy" class="note" style="display:none;font-size:15px;background:#fff3d6;border:2px solid #d8a600"></div>
<div class="bar"><h1>発注ボード（$(Get-Date -Format 'yyyy年M月d日 HH:mm') 現在$(if ($cfg.Test -eq $true) { '・試験モード' })）</h1><div><button onclick="verify()">送ったか確かめる</button><button onclick="refresh()">作り直しを頼む</button></div></div>
$($simple.ToString())
<div class="tabs">
  <div class="tab sel" id="tk" onclick="pick('k')"><div class="n">発注（クシロー・学問）</div><div class="m">発注の台帳 $(@($cases).Count)件</div>$(if ($badgeK) { "<span class='badge' id='bk'>$badgeK</span>" })</div>
  <div class="tab" id="tg" onclick="pick('g')"><div class="n">学問のするめ</div><div class="m">予算が届いたかの一覧</div></div>
</div>
<div id="pk">
$($hj.ToString())
<div class="sec" style="margin-bottom:10px">$(Tg '<b>［くわしい表を開く］</b>' ('<div class="m">今までの画面です（送る日の順の全部の行・催事ごとの表・予定を直す窓・補充の時期の原料・仕組みの困りごと）。ふだんは開かなくて大丈夫です。</div>' + $kb.ToString() + $hj2.ToString() + '<div class="wrap"><div class="left">' + $nav.ToString() + '</div><div class="right">' + $sb.ToString() + '</div></div>'))</div>
</div>
<div id="pg" style="display:none">$($gk.ToString())</div>
<script language="JScript">$js</script>
</body></html>
"@
# 2026-10-30 ①②（26代目ボス 10/30 09:0x の裁定・マニュアル冊3 穴-41・穴-101・決まり 10/5「台帳と書かない」）：熊田さんの画面に出る字だけを、人に通じる言葉に置き換える。
#   置き換えるのはタグの外の字だけ（script・style・ボタンの中の鍵は触らない）。発注案ファイルや知らせのファイルの中身は変えない
function Hito-Ji([string]$h) {
    return [regex]::Replace($h, '(<script[\s\S]*?</script>|<style[\s\S]*?</style>|<[^>]*>)|([^<]+)', [System.Text.RegularExpressions.MatchEvaluator]{ param($m)
        if ($m.Groups[1].Success) { return $m.Value }
        $s = $m.Value
        $s = $s.Replace('発注の台帳', '発注案').Replace('台帳', '発注案')
        $s = [regex]::Replace($s, '(統合設計)?\d+代目ボス', '発注の仕組み')
        $s = $s.Replace('ボス裁定', '発注の仕組みの裁定').Replace('ボス', '発注の仕組み').Replace('蔵人', '発注の仕組み')
        $s = $s.Replace('地図に無い箱', '登録されていない置き場')
        return $s })
}
$html = Hito-Ji $html
[IO.File]::WriteAllText($out, $html, (New-Object Text.UTF8Encoding $true))
# 2026-10-08 ブラウザ版（玉井さん「誰でも・どこでも」・9代目ボスの裁定）：同じ中身で、動き（JScript）だけを web_board.js に差し替えた画面を 発注\web\board.html に書く。
#   置くのは web_push.ps1（D1 の board_pages）。見せるのは Worker hacchu-board（合言葉）。
$webDir = Join-Path $root 'web'; if (-not (Test-Path $webDir)) { New-Item -ItemType Directory -Path $webDir -Force | Out-Null }
try {
    $wjs = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'web_board.js'), [Text.Encoding]::UTF8).Replace('__N__', [string]$i) + "`r`n" + $manqJs
    $webHtml = [regex]::Replace($html, '<script language="JScript">[\s\S]*?</script>', [Text.RegularExpressions.MatchEvaluator]{ param($m) '<script>' + $wjs + '</script>' })
    $webHtml = [regex]::Replace($webHtml, '<hta:application[^>]*>', '')
    $webHtml = $webHtml.Replace('<head>', '<head><meta name="viewport" content="width=device-width,initial-scale=1">')
    # 2026-10-23 A群 F25：ブラウザ版では下書きのボタンが押した後に断られる＝押す前に分かるよう、ボタンの名前に「（PCのボードで）」を足す
    $webHtml = $webHtml.Replace('>下書きを作って開く</button>', '>下書きを作って開く（PCのボードで）</button>').Replace('>下書きを開く</button>', '>下書きを開く（PCのボードで）</button>')
    [IO.File]::WriteAllText((Join-Path $webDir 'board.html'), $webHtml, (New-Object Text.UTF8Encoding $false))
} catch { "ブラウザ版の画面を書けず：$($_.Exception.Message)" }
# 2026-09-22 玉井さん「熊田さんのPCに行かないと見られない状況ではなく、こちらも同じものを見られるように」＝ボタンの無い見るだけ版を同じ中身で書く（どのPCでも開ける・押しても何も起きない）
$view = [regex]::Replace($html, '<button[^>]*>.*?</button>', '')
$view = $view.Replace(('var BOARDF="' + $out.Replace('\', '\\') + '"'), ('var BOARDF="' + (Join-Path $root '発注ボード_見るだけ.hta').Replace('\', '\\') + '"'))   # 2026-10-08 穴24：見るだけ版は自分のファイルを見る
$view = $view.Replace('<title>発注ボード</title>', '<title>発注ボード（見るだけ）</title>').Replace('applicationname="HacchuBoard"', 'applicationname="HacchuBoardView"')
$view = [regex]::Replace($view, '<div class="note">［中身を見て送る］.*?</div>', '<div class="note">見るだけの画面です（ボタンはありません）。送るのは熊田さんのPCの発注ボードから。中身は熊田さんのPCと同じ台帳から作っています。</div>')
[IO.File]::WriteAllText((Join-Path $root '発注ボード_見るだけ.hta'), $view, (New-Object Text.UTF8Encoding $true))
# ===== 2026-10-07 発注の予定を直す窓（発注の予定を直す.hta）=====
#   玉井さん「発注の予定＝鍵のかかった箱」。鍵を持つPC（熊田さんのPC・倉庫メインPC・自宅メインPC）だけが、送る前の発注を足す・量を変える・外す／もう頼んである分を記録する。
#   窓は台帳と品目.json から組み、押すと board_action.ps1 -Action naoshi（1直し＝1ファイル）→ 台帳の作り直し → この窓とボードを書き直す。
#   品は商品マスターの一覧（品目.json）から選び、量は＋−（点検役(7)）。「何をもとに」5択は必須・メモは任意（空なら「メモなし」）
$hinAll = @()
try {
    $hjj = Get-Content (Join-Path $PSScriptRoot '品目.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($pp in @($hjj.品目.PSObject.Properties)) { $hinAll += [ordered]@{ c = [string]$pp.Name; n = [string]$pp.Value.品名; u = [double]$(if ($pp.Value.発注単位kg) { $pp.Value.発注単位kg } else { 0 }); h = [string]$pp.Value.本文名; s = [string]$pp.Value.状態 } }
} catch {}
$wData = @(); $wi = 0
foreach ($d in $cases) {
    $wi++
    $ks = [string]$d.会期開始; $ke = [string]$d.会期終了
    $wData += [ordered]@{ i = $wi; id = [string]$d.案件ID; kaijo = [string]$d.会場; kikan = $(if ($ks.Length -ge 10) { $ks.Substring(5).Replace('-', '/') + '〜' + $ke.Substring(5).Replace('-', '/') } else { $ks }); tantou = [string]$d.担当者; jotai = [string]$d.状態; taishougai = ($d.対象外 -eq $true)
        kouho = @($d.候補 | Where-Object { $_ -and ($_.候補外 -ne $true -or [string]$_.状態 -match '^(送った|電話した)') } | ForEach-Object { [ordered]@{ aite = [string]$_.相手; hou = [string]$_.方法; st = [string]$_.状態; gai = ($_.候補外 -eq $true); naka = [string]$(if ($_.中身全文) { $_.中身全文 } else { $_.中身 }) } })   # 2026-10-12 頼み直し：全部取り消して候補外になった「送った」相手も選べるように（gai＝候補外）
        hin = @($d.品目 | Where-Object { $_ } | ForEach-Object { [ordered]@{ c = [string]$_.品目コード; n = [string]$_.商品; kg = [string]$_.発注量kg; cs = [string]$_.ケース; chu = [string]$_.注意 } })
        naoshi = @($d.予定の直し.一覧 | Where-Object { $_ } | ForEach-Object { $g = $_.行; [ordered]@{ f = [string]$_.ファイル; sh = [string]$_.種別; c = [string]$g.品目コード; n = [string]$g.商品; kg = [string]$g.発注量kg; cs = [string]$g.ケース; hito = ($g.人が読む -eq $true); ji = [string]$g.本文の字; saki = [string]$g.頼む先; moto = [string]$_.何をもとに; memo = [string]$_.メモ; dare = [string]$_.誰が; pc = [string]$_.PC; itsu = [string]$_.いつ } })
        ndState = [string]$d.予定の直し.状態; ndNG = @($d.予定の直し.できない理由 | Where-Object { $_ }); ndDone = @($d.予定の直し.直した | Where-Object { $_ }) }
}
$wJson = ConvertTo-Json -InputObject @($wData) -Depth 6 -Compress
$hJson = ConvertTo-Json -InputObject @($hinAll) -Compress
$mJson = ConvertTo-Json -InputObject @('担当者のLINE・電話', '玉井さんの指示', '仕入先からの返事', '倉庫の実数', '熊田さんの判断') -Compress
$win = @'
<html><head><meta http-equiv="x-ua-compatible" content="IE=edge"><meta charset="utf-8"><title>発注の予定を直す</title>
<hta:application id="app2" applicationname="HacchuNaoshi" scroll="yes" windowstate="normal" />
<style>__CSS__
.q{margin:10px 0;padding:8px 10px;background:#fff;border:1px solid #e3e3df;border-radius:8px}.big{font-size:20px;font-weight:bold;min-width:40px;display:inline-block;text-align:center}
button.pm{font-size:18px;width:44px;height:36px}select,input[type=text]{font-size:14px;padding:4px}label{display:inline-block;margin:3px 0}.warn{color:#b01c1c;font-weight:bold}
</style></head><body>
<div id="busy" class="note" style="display:none;font-size:15px;background:#fff3d6;border:2px solid #d8a600"></div>
<h1 id="ttl">発注の予定を直す</h1><div id="meta" class="m"></div><div id="kagiNote" class="warn"></div>
<div class="sec"><b>いまの予定</b><div id="now"></div></div>
<div class="sec" id="form">
 <div class="q"><b>① 何をする</b><br>
  <label><input type="radio" name="sh" value="これから頼む" checked onclick="upd()"> これから頼む（下書きの中身が変わる。まだ送っていない相手だけ）</label><br>
  <label><input type="radio" name="sh" value="もう頼んである" onclick="upd()"> もう頼んである（記録だけ。下書きは変わらず、台帳の量に<b>足す</b>）</label><br>
  <label><input type="radio" name="sh" value="頼んだ分を減らした" onclick="upd()"> 送った後の取消・減らした（<b>メーカーが応じた分だけ</b>。記録だけ。台帳の量から<b>引く</b>・理由は⑥メモへ）</label></div>
 <div class="q"><b>② 品</b>　<select id="hin" onchange="pickHin()"></select>
  <label style="margin-left:14px"><input type="checkbox" id="jiChk" onclick="upd()"> 一覧に無い品（字で書く）</label>
  <div id="jiBox" style="display:none;margin-top:6px"><input type="text" id="ji" style="width:92%" placeholder="例：干し貝柱（中国）10kg"><br><span class="m" id="jiNote"></span></div></div>
 <div class="q" id="csBox"><b>③ 量</b>　ケース <button class="pm" onclick="step(-1)">−</button> <span id="cs" class="big">1</span> <button class="pm" onclick="step(1)">＋</button>　<span id="kgTxt"></span><br><span class="m">0 にすると「外す」になります</span></div>
 <div class="q"><b>④ 頼む先</b>　<select id="saki" onchange="upd()"></select> <span id="sakiNote" class="m"></span></div>
 <div class="q"><b>⑤ 何をもとに（必ず1つ）</b><br><div id="moto"></div></div>
 <div class="q"><b>⑥ メモ（なくてもよい）</b><br><input type="text" id="memo" style="width:92%"></div>
 <div class="q"><b>⑦ 直している人（必ず1つ）</b><br><label><input type='radio' name='dare' value='熊田さん'> 熊田さん</label>　<label><input type='radio' name='dare' value='玉井さん'> 玉井さん</label></div>
 <div><button class="p" id="okBtn" style="font-size:16px;padding:8px 18px" onclick="submitNaoshi()">この直しを入れる</button>　<button onclick="window.close()">閉じる</button>　<span id="submitNote" class="warn"></span></div>
</div>
<div class="sec"><b>入れた直し（この催事）</b><div id="list"></div></div>
<script language="JScript">
var GUARD="__GUARD__", ACT="__ACT__", CFG="__CFG__", NAOSHIF="__NAOSHIF__", KAGI="__KAGI__";
var DATA=__DATA__; var HIN=__HIN__; var MOTO=__MOTO__;
var C=null, CS=1, UNIT=0, HASKEY=false, BUSYNOW=false;
function fso(){return new ActiveXObject("Scripting.FileSystemObject");}
function hex(s){var o="",i,c;for(i=0;i<s.length;i++){c=s.charCodeAt(i);if(c<128){o+=("0"+c.toString(16)).slice(-2);}else if(c<2048){o+=(192|(c>>6)).toString(16)+("0"+(128|(c&63)).toString(16)).slice(-2);}else{o+=(224|(c>>12)).toString(16)+("0"+(128|((c>>6)&63)).toString(16)).slice(-2)+("0"+(128|(c&63)).toString(16)).slice(-2);}}return o;}
function esc(s){s=String(s==null?"":s);var o="",i,c;for(i=0;i<s.length;i++){c=s.charAt(i);if(c=='"'){o+='\\"';}else if(c=='\\'){o+='\\\\';}else if(c=='\n'){o+='\\n';}else if(c=='\r'){o+='\\r';}else if(c=='\t'){o+='\\t';}else{o+=c;}}return o;}
function he(s){s=String(s==null?"":s);return s.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;");}
function kn(s){s=String(s==null?"":s);var o="",i,c;for(i=0;i<s.length;i++){c=s.charCodeAt(i);if(c>=0x3041&&c<=0x3096){o+=String.fromCharCode(c+0x60);}else{o+=s.charAt(i);}}return o;}
function busy(msg){try{var d=document.getElementById("busy");if(d){d.innerHTML=msg;d.style.display="block";}}catch(e){}}
function run(argLine,timeout,after){if(BUSYNOW){return;}BUSYNOW=true;var f=fso();var done=f.GetSpecialFolder(2).Path+"\\naoshi_done_"+(new Date().getTime())+".txt";var sh=new ActiveXObject("WScript.Shell");sh.Run('cmd /c powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+GUARD+'" -Target "'+ACT+'" -TimeoutSec '+timeout+' -ArgLine "'+argLine+'" & echo x> "'+done+'"',0,false);var t0=new Date().getTime(),lim=(timeout+60)*1000;function poll(){var ok=false;try{ok=fso().FileExists(done);}catch(e){}if(ok){try{fso().DeleteFile(done);}catch(e){}after();return;}if(new Date().getTime()-t0>lim){after();return;}setTimeout(poll,1000);}setTimeout(poll,1000);}
function hasKey(){try{var f=fso();if(!f.FileExists(KAGI)){return false;}var r=f.OpenTextFile(KAGI,1,false,-1);var tx=r.ReadAll();r.Close();var o=eval('('+tx+')');var h=new ActiveXObject("WScript.Shell").ExpandEnvironmentStrings("%COMPUTERNAME%");return (o["ホスト名"]==h);}catch(e){return false;}}
function loadCase(){var n=0;try{var f=fso();if(f.FileExists(NAOSHIF)){var r=f.OpenTextFile(NAOSHIF,1,false,0);n=parseInt(r.ReadLine())||0;r.Close();}}catch(e){}for(var i=0;i<DATA.length;i++){if(DATA[i].i==n){return DATA[i];}}return null;}
function hinByCode(c){for(var i=0;i<HIN.length;i++){if(HIN[i].c==c){return HIN[i];}}return null;}
function caseHin(c){for(var i=0;i<C.hin.length;i++){if(C.hin[i].c==c){return C.hin[i];}}return null;}
function kouhoByAite(a){for(var i=0;i<C.kouho.length;i++){if(C.kouho[i].aite==a){return C.kouho[i];}}return null;}
function kouhoOf(nm){if(!nm){return null;}var k=kn(nm);for(var i=0;i<C.kouho.length;i++){var x=C.kouho[i];if(x.naka&&kn(x.naka).indexOf(k)>=0){return x;}}return null;}
function sh(){var r=document.getElementsByName("sh");for(var i=0;i<r.length;i++){if(r[i].checked){return r[i].value;}}return "これから頼む";}
function dare(){var r=document.getElementsByName("dare");for(var i=0;i<r.length;i++){if(r[i].checked){return r[i].value;}}return "";}
function moto(){var r=document.getElementsByName("moto");for(var i=0;i<r.length;i++){if(r[i].checked){return r[i].value;}}return "";}
function render(){
 C=loadCase(); if(!C){alert("どの催事を直すかが分かりません。発注ボードの［予定を直す窓を開く］から開いてください。");window.close();return;}
 HASKEY=hasKey();
 document.getElementById("ttl").innerHTML="発注の予定を直す："+he(C.kaijo);
 document.getElementById("meta").innerHTML=he(C.kikan+"　"+C.tantou+"　状態："+C.jotai);
 if(!HASKEY){document.getElementById("kagiNote").innerHTML="このPCには鍵がありません（鍵のあるPC＝倉庫メインPC・自宅メインPC）。ここでは見るだけです。<br>このPCで直すときは、ブラウザ版の発注ボード（https://hacchu-board.gokaku-san.workers.dev ・合言葉で入る）の同じ催事の［予定を直す窓を開く］から直せます。スマホからも同じです。";}
 if(C.taishougai){document.getElementById("kagiNote").innerHTML+="<br>この催事は仕組みの対象外です。ここでは直せません。対象外の間は、今までどおり LINE の依頼を見て手で送ります。";}
 var h="<table><tr><th>相手</th><th>方法</th><th>状態</th><th>中身</th></tr>";
 for(var i=0;i<C.kouho.length;i++){var k=C.kouho[i];h+="<tr><td><b>"+he(k.aite)+"</b></td><td>"+he(k.hou)+"</td><td>"+he(k.st)+"</td><td class='m'>"+he(k.naka)+"</td></tr>";}
 h+="</table><table style='margin-top:6px'><tr><th>品</th><th>ケース</th><th>kg</th><th>注意</th></tr>";
 for(var i=0;i<C.hin.length;i++){var x=C.hin[i];h+="<tr><td>"+he(x.c)+" "+he(x.n)+"</td><td>"+he(x.cs)+"</td><td>"+he(x.kg)+"</td><td class='m'>"+he(x.chu)+"</td></tr>";}
 h+="</table>"; document.getElementById("now").innerHTML=h;
 var s=document.getElementById("hin"); s.options.length=0;
 for(var i=0;i<C.hin.length;i++){var x=C.hin[i];var o=document.createElement("option");o.value=x.c;o.text="▶ "+x.n+"（いま "+x.cs+"c/s・"+x.kg+"kg）";s.options.add(o);}
 for(var i=0;i<HIN.length;i++){var m=HIN[i];if(caseHin(m.c)){continue;}var o=document.createElement("option");o.value=m.c;o.text="　"+m.n+"（発注案に無い品・1ケース "+m.u+"kg）";s.options.add(o);}
 var ss=document.getElementById("saki"); ss.options.length=0; var souko=false;
 for(var i=0;i<C.kouho.length;i++){var k=C.kouho[i];if(k.aite=="倉庫出し"){souko=true;}var o=document.createElement("option");o.value=k.aite;o.text=k.aite+"（"+k.hou+"・"+k.st+(k.gai?"・全部取り消し済み":"")+"）";ss.options.add(o);}
 if(!souko){var o=document.createElement("option");o.value="倉庫出し";o.text="倉庫出し";ss.options.add(o);}
 var mh=""; for(var i=0;i<MOTO.length;i++){mh+="<label><input type='radio' name='moto' value='"+he(MOTO[i])+"'> "+(i+1)+". "+he(MOTO[i])+"</label>　";}
 document.getElementById("moto").innerHTML=mh;
 var lh=""; if(C.ndState=="反映できない"){lh+="<div class='warn'>⚠ 直しを下書きに反映できていません（仕組みの困りごとに載っています。熊田さんがすること：何もしない＝仕組みの側で直します）：";for(var i=0;i<C.ndNG.length;i++){lh+="<br>"+he(C.ndNG[i]);}lh+="</div>";}
 if(C.naoshi.length){lh+="<table><tr><th>いつ・誰が</th><th>何を</th><th>何をもとに</th><th>メモ</th><th></th></tr>";
  for(var i=0;i<C.naoshi.length;i++){var r=C.naoshi[i];var nani=(r.sh=="もう頼んである"?"【記録】":(r.sh=="頼んだ分を減らした"?"【取消済み（メーカーが応じた）】":"【これから頼む】"))+(r.hito?"※"+r.ji:r.n+" "+r.cs+"c/s（"+r.kg+"kg）")+"　→ "+r.saki+((r.cs=="0"&&!r.hito&&r.sh=="これから頼む")?"　＝外す":"");
   lh+="<tr><td>"+he(String(r.itsu).replace("T"," ").replace("+09:00",""))+"<br><span class='m'>"+he(r.dare+"（"+r.pc+"）")+"</span></td><td>"+he(nani)+"</td><td>"+he(r.moto)+"</td><td>"+he(r.memo||"メモなし")+"</td><td>"+(HASKEY?"<button onclick=\"cancelNaoshi('"+he(r.f)+"')\">取り消す</button>":"")+"</td></tr>";}
  lh+="</table>"; if(C.ndDone.length){lh+="<div class='m'>反映："+he(C.ndDone.join("／"))+"</div>";}
 } else {lh+="<div class='m'>まだありません</div>";}
 document.getElementById("list").innerHTML=lh;
 pickHin();
}
function pickHin(){var c=document.getElementById("hin").value;var m=hinByCode(c);var ch=caseHin(c);UNIT=m?m.u:0;CS=ch?(parseFloat(ch.cs)||0):1;
 var k=null; if(m){k=kouhoOf(m.n)||kouhoOf(m.h);} var ss=document.getElementById("saki");
 if(k){for(var i=0;i<ss.options.length;i++){if(ss.options[i].value==k.aite){ss.selectedIndex=i;}}}
 document.getElementById("ji").value=(m&&!ch)?(m.n+" "+CS+"c/s"):"";
 upd();}
function step(d){CS=Math.max(0,CS+d);upd();}
function upd(){var s=sh();var jiMode=document.getElementById("jiChk").checked;var c=document.getElementById("hin").value;var m=hinByCode(c);var ch=caseHin(c);
 var newHin=(m&&!ch); var hito=jiMode||(s=="これから頼む"&&newHin);
 document.getElementById("hin").disabled=jiMode;
 document.getElementById("jiBox").style.display=hito?"":"none";
 document.getElementById("jiNote").innerHTML=jiMode?"字のまま、頼む先の下書きに「・※」の行として足します（量は字の中に書く）":"発注案に無い品は、頼む先の下書きに「・※〈字〉」の行として足します（字は直してよい）";
 document.getElementById("csBox").style.display=jiMode?"none":"";
 document.getElementById("cs").innerHTML=CS;
 document.getElementById("kgTxt").innerHTML=(s=="頼んだ分を減らした"?"減らす量 ":"")+(UNIT>0?("＝ "+(Math.round(CS*UNIT*100)/100)+"kg（1ケース "+UNIT+"kg）"):"（1ケースの重さが品目の一覧に無い）")+(CS==0&&s!="頼んだ分を減らした"?"　<span class='warn'>外す</span>":"");
 if(!jiMode&&!newHin&&s=="これから頼む"){document.getElementById("ji").value="";}
 var ss=document.getElementById("saki"); var lock=(s=="これから頼む"&&ch&&!jiMode); ss.disabled=lock;
 document.getElementById("sakiNote").innerHTML=lock?"（発注案でこの品が入っている便。変えられません）":(s!="これから頼む"?"（送った相手でも記録できます）":"");
 var note=""; var k=kouhoByAite(ss.value);
 if(s=="これから頼む"&&ss.value!="倉庫出し"){ if(!k){note="その頼む先は、この催事の相手にありません";} else if(/^(送った|電話した)/.test(k.st)&&ss.value.indexOf("〈頼み直し〉")<0){document.getElementById("sakiNote").innerHTML+="<br><b>「"+he(ss.value)+"」にはもう送っています。新しい便「"+he(ss.value)+"〈頼み直し〉」の下書きを作ります</b>（前に送った分と取消の記録はそのまま残ります）。電話で頼んで済ませた分なら、③で「もう頼んである」を選んでください";} else if(k.st!="候補"&&k.st!="下書き済"){note="「"+ss.value+"」にはもう送っています（"+k.st+"）。相手に伝えてから「もう頼んである」で記録してください";} }
 if(s=="これから頼む"&&ss.value=="倉庫出し"&&k&&k.st=="倉庫から出した"){note="倉庫出しはもう出しています。「もう頼んである」で記録してください";}
 // 2026-10-08 穴23：減らした記録は一覧の品だけ・1ケース以上
 if(s=="頼んだ分を減らした"){ if(jiMode||!ch){note="減らした記録は、この催事の発注案にある品を選んでください";} else if(CS<=0){note="減らしたケースの数を＋で入れてください";} }
 if(!HASKEY){note="このPCには鍵がありません";} if(C&&C.taishougai){note="仕組みの対象外の催事です";}
 document.getElementById("submitNote").innerHTML=note; document.getElementById("okBtn").disabled=(note!="");}
function submitNaoshi(){var s=sh();var jiMode=document.getElementById("jiChk").checked;var c=document.getElementById("hin").value;var m=hinByCode(c);var ch=caseHin(c);
 var code=c,name=m?m.n:"",kg=String(Math.round(CS*UNIT*100)/100),cs=String(CS),hito=false,ji="";
 var jv=document.getElementById("ji").value; jv=jv.replace(/^\s+|\s+$/g,"");
 if(jiMode){if(!jv){alert("一覧に無い品は、字で書いてください。");return;}hito=true;ji=jv;code="";name=jv;kg="0";cs="0";}
 else if(s=="これから頼む"&&m&&!ch){if(!jv){alert("発注案に無い品は、下書きに足す字が要ります。");return;}hito=true;ji=jv;}
 if(!m&&!jiMode){alert("品を選んでください。");return;}
 var saki=document.getElementById("saki").value; var mt=moto(); var memo=document.getElementById("memo").value;
 var sk0=kouhoByAite(saki); if(s=="これから頼む"&&saki!="倉庫出し"&&sk0&&/^(送った|電話した)/.test(sk0.st)&&saki.indexOf("〈頼み直し〉")<0){saki=saki+"〈頼み直し〉";}   // 2026-10-12 頼み直し＝送った相手には新しい便
 if(!mt){alert("⑤「何をもとに」を1つ選んでください。");return;}
 var dr=dare(); if(!dr){alert("⑦「直している人」を選んでください。");return;}
 var what=(s=="頼んだ分を減らした"?name+" "+cs+"c/s（"+kg+"kg）を減らした":(hito?"※"+ji:name+" "+cs+"c/s（"+kg+"kg）"+(CS==0?"＝外す":"")));
 if(!confirm("この直しを入れます。よろしいですか？\n\n何をする：　"+s+"\n品：　　　"+what+"\n頼む先：　"+saki+"\n何をもとに："+mt+"\nメモ：　　"+(memo||"メモなし")+"\n直す人：　"+dr+"\n\n入れると台帳を作り直します（1〜2分）。")){return;}
 var row='{"種別":"'+esc(s)+'","行":{"品目コード":"'+esc(code)+'","商品":"'+esc(name)+'","発注量kg":"'+esc(kg)+'","ケース":"'+esc(cs)+'","人が読む":'+(hito?'true':'false')+',"本文の字":"'+esc(ji)+'","頼む先":"'+esc(saki)+'","注意":""},"何をもとに":"'+esc(mt)+'","メモ":"'+esc(memo)+'","誰が":"'+esc(dr)+'"}';
 busy("直しを入れて、台帳を作り直しています。1〜2分かかります。そのまま待ってください。");
 run("-Action naoshi -CaseHex "+hex(C.id)+" -RowHex "+hex(row)+" -Config "+CFG,400,function(){location.reload();});}
function cancelNaoshi(f){if(!confirm("この直しを取り消します（記録は消えず、「取り消し」が足されます）。よろしいですか？")){return;}busy("取り消して、台帳を作り直しています。1〜2分かかります。");run("-Action naoshicancel -CaseHex "+hex(C.id)+" -FileHex "+hex(f)+" -Config "+CFG,400,function(){location.reload();});}
window.onload=function(){try{window.resizeTo(980,Math.min(screen.availHeight,1000));}catch(e){}render();};
</script></body></html>
'@
$win = $win.Replace('__CSS__', $css).Replace('__GUARD__', $guard).Replace('__ACT__', $act).Replace('__CFG__', $cfgp).Replace('__NAOSHIF__', $naoshiSelJs).Replace('__KAGI__', $kagiJs).Replace('__DATA__', $wJson).Replace('__HIN__', $hJson).Replace('__MOTO__', $mJson)
$win = Hito-Ji $win   # 2026-10-30 ①②：予定を直す窓も同じ
[IO.File]::WriteAllText($winOut, $win, (New-Object Text.UTF8Encoding $true))
# 2026-10-08 ブラウザ版の窓：元の動きの後ろに web_naoshi.js を足し、PCの道具に触る関数だけを置き換える
try {
    $wnjs = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'web_naoshi.js'), [Text.Encoding]::UTF8)
    $webWin = [regex]::Replace($win, '<hta:application[^>]*>', '').Replace('<head>', '<head><meta name="viewport" content="width=device-width,initial-scale=1">')
    $webWin = $webWin.Replace('</script></body></html>', '</script><script>' + $wnjs + '</script></body></html>')
    [IO.File]::WriteAllText((Join-Path $webDir 'naoshi.html'), $webWin, (New-Object Text.UTF8Encoding $false))
} catch { "ブラウザ版の窓を書けず：$($_.Exception.Message)" }
# 2026-10-08 送った状態を1枚に（AIかおりが「送ったら修正を締める」ために読む・9代目ボスの依頼）。失敗してもボードは止めない
$sentState = ''; try { $sentState = (& (Join-Path $PSScriptRoot 'write_sent_state.ps1') | Out-String).Trim() } catch { $sentState = '送った状態：書けず ' + $_.Exception.Message }
# D1 へ置くのは 発注\web\_置いてよい.txt がある時だけ（2026-10-08 共有の D1 へ書くのは玉井さんの許可の後）
$webState = 'ブラウザ版：止めている（_置いてよい.txt なし）'
if (Test-Path (Join-Path $webDir '_置いてよい.txt')) { try { $webState = (& (Join-Path $PSScriptRoot 'web_push.ps1') | Out-String).Trim() } catch { $webState = 'ブラウザ版：置けず ' + $_.Exception.Message } }
# 2026-10-30 10枚目(4)（玉井さん 10/29 18:25 ハンコ・確認画面 h10）：発注案の日ごとの写し＝後から「どの回で何が変わったか」を確かめる。
#   置き場＝発注\記録\発注案の写し\〈日付 yyyyMMdd〉\〈案件ID〉_〈時刻 HHmmss〉.json。作り直しのたびに、その日の最後の写しと中身が違う発注案だけ写す（同じなら写さない）。30日より前の日付のフォルダは消す（写しだけ・発注案は触らない）。
#   失敗してもボードは止めない（写しの段の結果は書き出しの1行に出す）
$shState = '発注案の写し：'
try {
    $shTop = Join-Path $root '記録\発注案の写し'; $shDir = Join-Path $shTop (Get-Date -Format 'yyyyMMdd'); $shT = Get-Date -Format 'HHmmss'
    New-Item -ItemType Directory -Force $shDir | Out-Null
    $shN = 0
    foreach ($lf in @(Get-ChildItem $planDir -Filter '20*.json' -File -ErrorAction SilentlyContinue)) {
        $shLast = @(Get-ChildItem $shDir -Filter ($lf.BaseName + '_*.json') -File -ErrorAction SilentlyContinue | Sort-Object Name) | Select-Object -Last 1
        if ($shLast -and (Get-FileHash $shLast.FullName -Algorithm MD5).Hash -eq (Get-FileHash $lf.FullName -Algorithm MD5).Hash) { continue }
        Copy-Item $lf.FullName (Join-Path $shDir ($lf.BaseName + '_' + $shT + '.json')) -Force; $shN++
    }
    $shOld = @(Get-ChildItem $shTop -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{8}$' -and [datetime]::ParseExact($_.Name, 'yyyyMMdd', $null) -lt (Get-Date).Date.AddDays(-30) })
    foreach ($od in $shOld) { Remove-Item $od.FullName -Recurse -Force }
    $shState += [string]$shN + '件写した' + $(if ($shOld.Count) { '・' + $shOld.Count + '日分を消した' } else { '' })
} catch { $shState += '書けず ' + $_.Exception.Message }
"書き出し: $out（$(@($cases).Count)件）＋見るだけ版＋予定を直す窓・$sentState・$webState・$shState"
