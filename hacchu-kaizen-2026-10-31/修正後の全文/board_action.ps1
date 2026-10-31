# 発注ボードのボタンの裏側。2026-09-18 蔵人（統合設計の会話・倉庫メインPC）。送信は絶対にしない。
# 【このファイルの持ち主】発注ボード専用の会話（倉庫メインPC）。
#   2026-10-03 玉井さん：発注ボードの会話はボード上で起こるすべてに責任を持つ（下書きの本文・件名・添付・CC＝make_order_drafts.ps1 も）。
#   統合設計のボスは調整役。process_budget_files.ps1・台帳（発注案）の作り方の引き渡しは擦り合わせ中（10/3）。
#   ここを直したい会話は、直接触らず発注ボードの会話へ依頼する。最後に決めるのは玉井さん。
# 使い方：board_action.ps1 -Action draft|open|mark|refresh|build -CaseHex <案件IDのUTF-8 16進> -AiteHex <相手のUTF-8 16進> -State <状態> [-Config <board_config.json>]
#   draft   その相手の下書きを1通だけ作って開く（台帳に EntryID を書く）。古い下書きがあれば件名に【旧】を付ける
#   naoshi / naoshicancel  2026-10-07 発注の予定を直す窓（発注の予定を直す.hta）から。鍵（%LOCALAPPDATA%\HacchuBoard\予定を直す鍵.json）があるPCだけ。1直し＝1ファイル（発注案\予定の直し\）
#   open    作ってある下書きをもう一度開く
#   mark    状態を付ける（送った／電話した／不要／候補）
#   refresh 候補を作り直す（process_budget_files.ps1）→ ボードを書き直す
#   build   ボード（.hta）を書き直すだけ
#   verifycopy  info@ に届く写し（かおりん・送信記録・送信済み）を宛先＋納品希望日＋会場で照合し、下書き済の行を「送った」にする。
#               倉庫メインPCの定期実行から呼ぶ（2026-10-03 玉井さん「送信したら自動で完了。押す必要はない」）。画面は出さない。-DryRun で書かずに結果だけ出す
# 台帳（状態の正本）＝…\発注\発注案\〈案件ID〉.json。書くのはこのファイルと process_budget_files.ps1 だけ。
param(
    [Parameter(Mandatory)][ValidateSet('draft','open','mark','refresh','build','verify','verifycopy','lineok','okcheck','naoshi','naoshicancel','henkook','mottekitta','manq','shusei')][string]$Action,
    [switch]$DryRun,
    [string]$CaseHex = '',
    [string]$AiteHex = '',
    [string]$State = '',
    [string]$StateHex = '',
    [string]$RowHex = '',    # 2026-10-07 naoshi：直しの行（種別・行・何をもとに・メモ の JSON）の UTF-8 16進
    [string]$FileHex = '',   # 2026-10-07 naoshicancel：取り消す直しのファイル名の UTF-8 16進
    [string]$Config = ''
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$planDir = Join-Path $root '発注案'
$utf8bom = New-Object Text.UTF8Encoding $true
$logPath = Join-Path $planDir '発注ボード_操作記録.txt'
function Note([string]$m) { try { [IO.File]::AppendAllText($logPath, ("{0}  {1}`r`n" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m), $utf8bom) } catch {} }
function FromHex([string]$h) { if (-not $h) { return '' }; $b = New-Object byte[] ($h.Length / 2); for ($i = 0; $i -lt $b.Length; $i++) { $b[$i] = [Convert]::ToByte($h.Substring($i * 2, 2), 16) }; return [Text.Encoding]::UTF8.GetString($b) }
# 2026-09-23：戻ってきたメールの『元の件名』『届かなかった宛先』を取り出す道具。
#   本文も宛先欄も COM で読まない（9/15 の安全警告の事故を避ける）。添付のヘッダの写しをファイルに保存して、そこから読む。
function ConvertFrom-MimeWord([string]$v) {
    if (-not $v) { return '' }
    # 長い件名は途中で折り返され、`?= =?` のすき間が入る。decode する前に詰める（詰めないと『お支 払い』になる）
    $v = [regex]::Replace($v, '\?=\s+=\?', '?==?')
    $rx = [regex]'=\?([^?]+)\?([BbQq])\?([^?]*)\?='
    for ($g = 0; $g -lt 20; $g++) {
        $m = $rx.Match($v); if (-not $m.Success) { break }
        $txt = $m.Value
        try {
            $enc = [Text.Encoding]::GetEncoding($m.Groups[1].Value)
            if ($m.Groups[2].Value -imatch 'B') { $txt = $enc.GetString([Convert]::FromBase64String($m.Groups[3].Value)) }
            else {
                $q = $m.Groups[3].Value.Replace('_', ' '); $bl = New-Object 'System.Collections.Generic.List[byte]'
                for ($i = 0; $i -lt $q.Length; $i++) { if ($q[$i] -eq '=' -and ($i + 2) -lt $q.Length) { $bl.Add([Convert]::ToByte($q.Substring($i + 1, 2), 16)); $i += 2 } else { $bl.Add([byte][char]$q[$i]) } }
                $txt = $enc.GetString($bl.ToArray())
            }
        } catch {}
        if ($txt -eq $m.Value) { break }
        $v = $v.Substring(0, $m.Index) + $txt + $v.Substring($m.Index + $m.Length)
    }
    return $v
}
function Get-BounceDetail($att) {
    # 配信不能の明細（details.txt）。Final-Recipient＝届かなかった宛先、Diagnostic-Code＝理由。ここがいちばん確か
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('hacchu_detail_' + [Guid]::NewGuid().ToString('N') + '.txt')
    $to = ''; $why = ''
    try {
        $att.SaveAsFile($tmp)
        foreach ($ln in @(Get-Content $tmp -Encoding UTF8 -ErrorAction Stop)) {
            if (-not $to -and $ln -match '^Final-Recipient:.*;\s*(.+)$') { $to = $Matches[1].Trim() }
            if (-not $why -and $ln -match '^Diagnostic-Code:.*;\s*(.+)$') { $why = $Matches[1].Trim() }
        }
    } catch {}
    try { if (Test-Path $tmp) { Remove-Item $tmp -Force } } catch {}
    return [pscustomobject]@{ 宛先 = $to; 理由 = $why }
}
function Get-BounceHeader($att) {
    # 添付（ヘッダの写し）を一時ファイルに出して、Subject: と To: の行だけを読む
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('hacchu_bounce_' + [Guid]::NewGuid().ToString('N') + '.txt')
    $sub = ''; $to = ''
    try {
        $att.SaveAsFile($tmp)
        $raw = @(Get-Content $tmp -Encoding UTF8 -ErrorAction Stop)
        $unfold = @(); foreach ($ln in $raw) { if ($ln -match '^[ \t]' -and $unfold.Count) { $unfold[$unfold.Count - 1] = $unfold[$unfold.Count - 1] + ' ' + $ln.Trim() } else { $unfold += $ln } }
        foreach ($ln in $unfold) {
            if (-not $sub -and $ln -match '^Subject:\s*(.+)$') { $sub = ConvertFrom-MimeWord $Matches[1].Trim() }
            if (-not $to -and $ln -match '^To:\s*(.+)$') { $to = ($Matches[1] -replace '[<>,]', ' ').Trim() }
        }
    } catch {}
    try { if (Test-Path $tmp) { Remove-Item $tmp -Force } } catch {}
    return [pscustomobject]@{ 件名 = $sub; 宛先 = $to }
}
# 2026-09-26：台帳は作り直しで書き換わるが、この記録は**足すだけ**で消えない。
#   「この相手にはもう送った」を、台帳が忘れても思い出せるようにするため
# 2026-10-09 マニュアル係④⑥⑦（熊田さん用の手引き）：小窓が「蔵人に知らせて」で終わり、熊田さんに次の一手が無かった。蔵人へ届く道も無かった。
#   仕組みが止まったら 発注案\_仕組みの困りごと.json に1行書く（同じ鍵の「未」があれば日時と中身だけ直す）。board_build がボードの上に出し、直れば「済」にする
function Add-Komarigoto([string]$nani, [string]$caseId3, [string]$aite3, [string]$naka3) {
    try {
        $kp3 = Join-Path $planDir '_仕組みの困りごと.json'
        $rows3 = @(); if (Test-Path $kp3) { try { $rows3 = @((Get-Content $kp3 -Raw -Encoding UTF8 | ConvertFrom-Json).行) } catch { $rows3 = @() } }
        $kagi3 = ($nani + '|' + $caseId3 + '|' + $aite3); $now3 = (Get-Date -Format 'yyyy-MM-dd HH:mm')
        $hit3 = $rows3 | Where-Object { $_ -and [string]$_.鍵 -eq $kagi3 -and [string]$_.状態 -eq '未' } | Select-Object -First 1
        if ($hit3) { $hit3.日時 = $now3; $hit3.中身 = $naka3 }
        else { $rows3 += [pscustomobject][ordered]@{ 鍵 = $kagi3; 日時 = $now3; 何が = $nani; 案件ID = $caseId3; 相手 = $aite3; 中身 = $naka3; 出どころ = 'ボタン'; 状態 = '未'; 済んだ日時 = '' } }
        $tmp3 = $kp3 + '.tmp'
        [IO.File]::WriteAllText($tmp3, ([ordered]@{ 説明 = '仕組みが止まった所の一覧（board_action.ps1・board_build.ps1 が書く）。直ると board_build が「済」にする。直すのは発注ボードの会話。玉井さんへの知らせはこの一覧を読む'; 行 = @($rows3) } | ConvertTo-Json -Depth 5), $utf8bom)
        Move-Item $tmp3 $kp3 -Force
    } catch { Note "困りごとが書けず $nani $caseId3 $aite3 : $($_.Exception.Message)" }
}
function Add-OkuttaKiroku([string]$caseId2, [string]$aite2, [string]$state2, [string]$subj2) {
    try {
        $kp = Join-Path $planDir '_送った記録.json'
        $rows2 = @()
        if (Test-Path $kp) { try { $rows2 = @((Get-Content $kp -Raw -Encoding UTF8 | ConvertFrom-Json).行) } catch { $rows2 = @() } }
        $rows2 += [pscustomobject]@{ 日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm'); 案件ID = $caseId2; 相手 = $aite2; どうした = $state2; 件名 = $subj2 }
        $tmp2 = $kp + '.tmp'
        [IO.File]::WriteAllText($tmp2, (@{ 説明 = '発注ボードで人が押した記録。足すだけで消さない。台帳の作り直しで『送った』が消えても、ここに残る'; 行 = @($rows2) } | ConvertTo-Json -Depth 5), $utf8bom)
        Move-Item $tmp2 $kp -Force
    } catch { Note "送った記録が書けず $caseId2 $aite2 : $($_.Exception.Message)" }
}
if (-not $Config) { $Config = Join-Path $PSScriptRoot 'board_config.json' }
$cfg = Get-Content $Config -Raw -Encoding UTF8 | ConvertFrom-Json
$DONE = @('送った', '電話した', '不要', '倉庫から出した', '現場が発注済み')   # 2026-09-22 点検：board_build・process_budget_files とそろえた（倉庫出しが永久に「残り」にならないように）
# 止まっている状態＝送ったかもしれない。ここから下書きを作らせない（2026-09-23）
$STUCK = @('送ったか確かめて', '⚠二重に送っています', '送信トレイで止まっています', '⚠古い中身で送っています')
. (Join-Path $PSScriptRoot 'genba_hantei.ps1')   # 2026-10-31 草案（発注チェーンの点検・本番未投入）：$GENBA_HOLD・Test-KaikiOwatta
$caseId = FromHex $CaseHex
$aite = FromHex $AiteHex
if ($StateHex) { $State = FromHex $StateHex }
function Load-Ledger([string]$id) {
    $p = Join-Path $planDir ($id + '.json')
    if (-not (Test-Path $p)) { Add-Komarigoto '台帳が見つからない' $id '' $p; Alert ("この発注の台帳が見つかりません。`r`n仕組みの側で止まっています。熊田さんが直す必要はありません。`r`nボードのいちばん上の「仕組みの困りごと」に自動で載りました（玉井さんも同じ画面で見ます）。`r`nボードを閉じて開き直すと、直っていることがあります。`r`n" + $p); Note "台帳なし $p"; exit 1 }
    # 2026-09-26：書きかけの中身を読むと壊れて見えることがある。1秒おいて3回まで読み直す
    for ($try = 1; $try -le 3; $try++) {
        try { return @{ Path = $p; Doc = (Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json) } }
        catch { if ($try -eq 3) { Alert ("台帳が読めませんでした（書きかえの途中かもしれません）。`r`n少し待って、もう一度押してください。`r`n" + $p); Note "台帳が読めない $p : $($_.Exception.Message)"; exit 1 }; Start-Sleep -Milliseconds 1000 }
    }
}
function Save-Ledger($L) {
    $d = $L.Doc
    $left = @($d.候補 | Where-Object { $DONE -notcontains $_.状態 }).Count
    if ($d.下書き可 -eq $true) { $d.状態 = $(if (-not @($d.候補).Count) { '候補なし' } elseif ($left -eq 0) { '完了' } else { "残り $left 件" }) }
    $d.更新 = (Get-Date -Format 'yyyy-MM-dd HH:mm')
    [IO.File]::WriteAllText($L.Path, ($d | ConvertTo-Json -Depth 8), $utf8bom)
}
function Outlook-Item([string]$eid, [string]$sid) {
    $ol = New-Object -ComObject Outlook.Application
    $ns = $ol.GetNamespace('MAPI')
    if ($sid) { return $ns.GetItemFromID($eid, $sid) } else { return $ns.GetItemFromID($eid) }
}
function Outlook-Open() {
    # 返信支援の事故（9/15 熊田PC）の対策：Outlook が画面で開いていなければ何もしない
    $p = Get-Process OUTLOOK -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }
    return [bool]$p
}
function Alert([string]$m) {
    # 2026-10-08 定期実行の中（mottekitta から mark を呼ぶ時）は小窓を出さない＝誰もいない画面で止まらない。記録にだけ残す
    # 2026-10-08 ブラウザ版：依頼を拾う道具（web_actions.ps1）が HACCHU_ALERT_FILE を渡す＝小窓の文をそこへ書き、押した人の画面に返す
    if ($env:HACCHU_ALERT_FILE) { try { [IO.File]::AppendAllText($env:HACCHU_ALERT_FILE, ($m + "`r`n"), $utf8bom) } catch {} }
    if ($env:HACCHU_NO_ALERT -eq '1') { Note ('（小窓の代わり）' + ($m -replace "`r?`n", ' ')); return }
    [void][Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
    [Windows.Forms.MessageBox]::Show($m, '発注ボード') | Out-Null
}
# 2026-10-07 発注の予定を直す（玉井さん「発注の予定＝鍵のかかった箱」）の道具
function ToHex([string]$s) { return (([Text.Encoding]::UTF8.GetBytes($s)) | ForEach-Object { $_.ToString('x2') }) -join '' }
function Read-Kagi() {
    # 鍵＝このPCの中（%LOCALAPPDATA%\HacchuBoard\予定を直す鍵.json・UTF-16・仕組み\鍵を置く.ps1 が置く）。Gドライブに置かない＝どのPCからでも直せる箱にしないため。
    #   鍵のあるPC＝熊田さんのPC・倉庫メインPC・自宅メインPC（玉井さん 2026-10-07）。ホスト名が違えば写しても効かない
    $kp = Join-Path (Join-Path $env:LOCALAPPDATA 'HacchuBoard') '予定を直す鍵.json'
    if (-not (Test-Path $kp)) { return $null }
    try { $k = Get-Content $kp -Raw -Encoding Unicode | ConvertFrom-Json } catch { return $null }
    if ([string]$k.ホスト名 -ne $env:COMPUTERNAME) { return $null }
    return $k
}
# 2026-10-08 23時台（10代目ボスの依頼・AIかおり fork 12 の使う人の目の点検 #8・鍵=仕組み/取消）：
#   熊田さんが LINE の［発注を直す］［取消］で直した直後は、直しがまだ発注案に入っていない＝古い中身の下書きを作る・開く・「送った」にできてしまう。
#   D1 の line_order_marks（公式の修正・kind＝cancel／change／cancel_change）のうち、この案件・この相手の行が
#   ①まだ当てていない（発注案\_LINEの修正_当てた.json にも 当てられない.json にも無い）②当てたが台帳がその後に作り直されていない、なら止める。
#   相手はメニューの印（message_id の末尾＝相手）で見る。印の無い自由文の修正は案件の全部の相手を止める。
#   読むだけ。D1 が読めない時は止めずに記録だけ残す（ネットの不調で全部の送りを止めないため）
# 2026-10-09 穴36（マニュアル係続き3・ボス）：D1 の鍵はこのPCのこのユーザーにしか無い＝熊田さんのPCでは読めない恐れ。
#   読めたか読めないかを PC ごとに 発注\記録\鍵の有無\〈PC〉_D1.txt に残す（変わった時だけ書く）
function Kagi-Kiroku([int]$ari) {
    try {
        $kd = Join-Path (Join-Path $root '記録') '鍵の有無'; New-Item -ItemType Directory -Force $kd | Out-Null
        $kf = Join-Path $kd ($env:COMPUTERNAME + '_D1.txt')
        $mae = ''; if (Test-Path $kf) { $mae = ([IO.File]::ReadAllText($kf)).Split(' ')[0] }
        if ($mae -ne ('d1=' + $ari)) { [IO.File]::WriteAllText($kf, ('d1=' + $ari + ' ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + ' 熊田さんの直しの止め金が D1 を読めるか（1＝読める・0＝鍵が無い）'), $utf8bom) }
    } catch {}
}
# 止まる時は必ず次の一手を返す（◎）。進んでよい時は $true
#   ・確かめられない（D1 が読めない）＝［はい］送る／［いいえ］やめる の2択
#   ・自動で当てられなかった＝待っても解けない＝［はい］で予定を直す窓を開く
#   ・まだ入っていない＝待てば解ける＝小窓で知らせて止める
function Kumada-Gate([string]$cid, [string]$who, $doc, [string]$what) {
    $mada = Kumada-Mada $cid $who $doc
    if (-not $mada) { return $true }
    [void][Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
    if ($mada -eq '?') {
        if ($env:HACCHU_NO_ALERT -eq '1') { Note "$what 熊田さんの直しを確かめられず（画面なし＝進めた）$cid $who"; return $true }
        $ans = [Windows.Forms.MessageBox]::Show("熊田さんの直しが入っているか、このPCでは確かめられません。`r`nLINE で直し（［発注を直す］［取消］）を出していなければ、送ってよいです。`r`n`r`n［はい］＝進める　［いいえ］＝やめる", '発注ボード', 'YesNo')
        Note "$what 熊田さんの直しを確かめられず→ $ans $cid $who"
        return ($ans -eq 'Yes')
    }
    if ($mada.StartsWith('NG:')) {
        $moto = $mada.Substring(3).Split('|')[0]; $txt = $mada.Substring(3 + $moto.Length + 1)
        if ($env:HACCHU_NO_ALERT -eq '1') { Alert ($txt + "`r`n（予定を直す窓はボードの上のボタンから開けます。直した後は PC のボードで［いいえ＝窓で直した］を選ぶと進めます）"); Note "$what 中止（熊田さんの直しが当てられない）$cid $who"; return $false }
        $ans = [Windows.Forms.MessageBox]::Show($txt + "`r`n`r`n［はい］＝予定を直す窓を開く`r`n［いいえ］＝もう窓で直した（進める）`r`n［キャンセル］＝やめる", '発注ボード', 'YesNoCancel')
        Note "$what 熊田さんの直しが当てられない→ $ans $cid $who $moto"
        if ($ans -eq 'Yes') { $hta = Join-Path $root '発注の予定を直す.hta'; if (Test-Path $hta) { Start-Process 'mshta.exe' -ArgumentList ('"' + $hta + '"') }; return $false }
        if ($ans -eq 'No') {
            $hp = Join-Path $planDir '_LINEの修正_人が直した.json'
            $hd = $null; try { $hd = Get-Content $hp -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
            $hr = @(); if ($hd) { $hr = @(@($hd.行) | Where-Object { $_ }) }
            $hr += [pscustomobject]@{ 案件ID = $cid; もとの日時 = $moto; 直した = (Get-Date -Format 'yyyy-MM-dd HH:mm'); PC = $env:COMPUTERNAME; 押した人 = $env:USERNAME }
            [IO.File]::WriteAllText($hp, ([ordered]@{ 説明 = '自動で当てられなかった熊田さんの直しを、人が予定を直す窓で直したという印（止め金がこの直しで止めない）。足すだけ'; 行 = @($hr) } | ConvertTo-Json -Depth 4), $utf8bom)
            return $true
        }
        return $false
    }
    Alert $mada; Note "$what 中止（熊田さんの直しがまだ）$cid $who"; return $false
}
function Kumada-Mada([string]$cid, [string]$who, $doc) {
    # 直しの一覧＝（もとの日時・相手）。D1 が読めればそれ、読めなければ G: の書き出し（AIかおり export_marks.py・30分ごと）で見る
    # 2026-10-09 穴39③：鍵の無いPC（熊田さんのPC）で押すたびに「確かめられません」が出ると熊田さんの手が増える（◎に逆らう）。
    #   書き出しが新しい（90分以内）なら書き出しで判定し、該当が無ければ何も出さない。書き出しも古い・読めない時だけ '?'（2択の小窓）
    $list = @()
    $d1ok = $false
    try {
        . 'C:\Users\info\projects\ai-kaori\jobs\load-cf-token.ps1' | Out-Null
        if ($env:CLOUDFLARE_API_TOKEN) {
            $u = "https://api.cloudflare.com/client/v4/accounts/$($env:CLOUDFLARE_ACCOUNT_ID)/d1/database/2e14c45e-33a6-40e8-b787-35338be54395/query"
            $b = [Text.Encoding]::UTF8.GetBytes((@{ sql = "SELECT message_id, sent_at FROM line_order_marks WHERE plan_id = ? AND kind IN ('cancel','change','cancel_change') ORDER BY sent_at"; params = @($cid) } | ConvertTo-Json -Compress))
            $resp = Invoke-WebRequest -Method Post -Uri $u -Headers @{ Authorization = "Bearer $env:CLOUDFLARE_API_TOKEN" } -ContentType 'application/json; charset=utf-8' -Body $b -TimeoutSec 20 -UseBasicParsing
            $r = [Text.Encoding]::UTF8.GetString($resp.RawContentStream.ToArray()) | ConvertFrom-Json
            if ($r.success) {
                $d1ok = $true; Kagi-Kiroku 1
                foreach ($m in @(@($r.result)[0].results)) {
                    # 2026-10-09 AIかおり fork 12：message_id の末尾＝相手。［取消］kumada-menu:ky:〈案件〉:〈相手〉／［発注を直す］kumada-menu:fx:〈画面の鍵〉:〈相手|相手〉。末尾が無い古い形＝相手なし（全部の相手を止める）
                    $mid = [string]$m.message_id; $aiteM = @(); if ($mid -like 'kumada-menu:*') { $t4 = ($mid -split ':', 4); if ($t4.Count -ge 4 -and $t4[3]) { $aiteM = @($t4[3] -split '\|' | Where-Object { $_ }) } }
                    $list += [pscustomobject]@{ Moto = ([datetime][string]$m.sent_at).ToLocalTime().ToString('yyyy-MM-dd HH:mm'); Aite = $aiteM }
                }
            } else { Note "熊田さんの直しの確かめ：D1 が読めない $cid" }
        } else { Kagi-Kiroku 0 }
    } catch { Note "熊田さんの直しの確かめ：D1 失敗 $cid $($_.Exception.Message)" }
    if (-not $d1ok) {
        $ex = $null; try { $ex = Get-Content (Join-Path $planDir '_LINEで1タップ.json') -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
        $exT = $null; try { $exT = [datetime][string]$ex.更新 } catch {}
        if (-not $ex -or -not $exT -or $exT -lt (Get-Date).AddMinutes(-90)) { Note "熊田さんの直しの確かめ：D1 も書き出しも使えない（書き出し $exT）$cid"; return '?' }
        foreach ($x in @($ex.行)) {
            if ([string]$x.案件ID -ne $cid -or [string]$x.種別 -notin @('取消', '数量変更', '取消・数量変更')) { continue }
            # 書き出しの「相手の一覧」（AIかおり fork 12・10/9）→ 無ければ「相手」→ どちらも無ければ相手なし（全部の相手を止める）
            $aiteX = @(@($x.相手の一覧) | Where-Object { $_ } | ForEach-Object { [string]$_ }); if (-not $aiteX.Count -and [string]$x.相手) { $aiteX = @([string]$x.相手) }
            $list += [pscustomobject]@{ Moto = [string]$x.もとの日時; Aite = $aiteX }
        }
    }
    if (-not $list.Count) { return '' }
    $ate = @(); $ng = @()
    try { $ate = @((Get-Content (Join-Path $planDir '_LINEの修正_当てた.json') -Raw -Encoding UTF8 | ConvertFrom-Json).行) } catch {}
    try { $ng = @((Get-Content (Join-Path $planDir '_LINEの修正_当てられない.json') -Raw -Encoding UTF8 | ConvertFrom-Json).行) } catch {}
    $koushin = $null; try { $koushin = [datetime][string]$doc.更新 } catch {}
    foreach ($m in $list) {
        if (@($m.Aite).Count -and $who -and (@($m.Aite) -notcontains $who)) { continue }
        $moto = $m.Moto
        # 2026-10-09 穴39②：品が1つでも当たらなかった直しは「当てた」にも載る（二重に当てないため）＝先に「当てられない」を見る
        #   人が窓で直して［窓で直した］を押した直しは止めない（_LINEの修正_人が直した.json・当てられない一覧は14日残るので、これが無いと14日止まる）
        $hito = @(); try { $hito = @((Get-Content (Join-Path $planDir '_LINEの修正_人が直した.json') -Raw -Encoding UTF8 | ConvertFrom-Json).行) } catch {}
        if (@($hito | Where-Object { [string]$_.案件ID -eq $cid -and [string]$_.もとの日時 -eq $moto }).Count) { continue }
        if (@($ng | Where-Object { [string]$_.案件ID -eq $cid -and [string]$_.もとの日時 -eq $moto }).Count) { return "NG:$moto|熊田さんの直し（$moto）に、自動で当てられなかった品があります。`r`n［予定を直す窓］で直してから送ってください。" }
        $hit = @($ate | Where-Object { [string]$_.案件ID -eq $cid -and [string]$_.もとの日時 -eq $moto }) | Select-Object -First 1
        if ($hit) {
            $ateT = $null; try { $ateT = [datetime][string]$hit.当てた日時 } catch {}
            if ($ateT -and $koushin -and $koushin -lt $ateT) { return "熊田さんの直し（$moto）は当てましたが、まだボードの中身に入っていません。`r`n少し待ってから開き直してください。" }
            continue
        }
        return "熊田さんの直し（$moto）がまだボードに入っていません。`r`n少し待ってから開き直してください。"
    }
    return ''
}
$NAOSHI_MOTO = @('担当者のLINE・電話', '玉井さんの指示', '仕入先からの返事', '倉庫の実数', '熊田さんの判断')   # 「何をもとに」の5択（必須）
switch ($Action) {
  'draft' {
    if (-not (Outlook-Open)) { Alert '先に Outlook を開いてから、もう一度押してください。'; Note "draft 中止（Outlookが開いていない）$caseId $aite"; break }
    $L = Load-Ledger $caseId; $d = $L.Doc
    if ($d.下書き可 -ne $true) { Alert ("この発注はまだ下書きを作れません（" + $d.状態 + "）"); break }
    # 2026-10-31 草案（発注チェーンの点検・本番未投入）：会期が終わった催事は下書きを作らない（画面のボタンを消すだけでは、開いたままの古い画面・ブラウザから呼べる＝裏でも止める）
    if (Test-KaikiOwatta $d) { Alert ("この催事は会期が終わっています（会期終了 " + [string]$d.会期終了 + "）。下書きは作りません。"); Note "draft 中止（会期が終わった）$caseId $aite"; break }
    # 2026-10-01 止め金（仕組み\止め金.json）：開いたままの古い画面から押されても、期限の内側は下書きを作らない
    $tome = $null
    #   相手つきの止め金はその相手だけ。期限なし＝外すまで（見直す日つき）。board_build.ps1 と同じ読み方
    try { $tome = @((Get-Content (Join-Path $PSScriptRoot '止め金.json') -Raw -Encoding UTF8 | ConvertFrom-Json).止め金) | Where-Object { [string]$_.案件ID -eq $caseId -and (-not [string]$_.相手 -or [string]$_.相手 -eq $aite) -and $(if ([string]$_.期限) { (Get-Date) -lt [datetime][string]$_.期限 } else { [bool][string]$_.見直す日 }) } | Select-Object -First 1 } catch {}
    # 2026-10-09 マニュアル係②：誰に聞くか・いつ押し直すかを書く（止め金を外すのは玉井さんの判断を受けた発注ボードの会話。熊田さんには外す道が無い＝聞き直させない）
    if ($tome) { Alert ("この発注は、いま送らないでください。`r`n`r`n" + [string]$tome.理由 + "`r`n（" + $(if ([string]$tome.期限) { [string]$tome.期限 + " まで" } else { "見直す日 " + [string]$tome.見直す日 }) + "）`r`n`r`n熊田さんがすること：なし（待つだけ）。`r`n" + $(if ([string]$tome.期限) { "期限を過ぎると自動で外れます。その後にもう一度押してください。" } else { "外すかどうかは玉井さんが決めます。見直す日を過ぎると、ボードのいちばん上の「仕組みの困りごと」に自動で載ります。外れると、この行のボタンがそのまま使えます。" })); Note "draft 中止（止め金）$caseId $aite"; break }
    $c = $d.候補 | Where-Object { $_.相手 -eq $aite } | Select-Object -First 1
    if (-not $c) { Add-Komarigoto '相手が台帳に無い' $caseId $aite '画面に出ている相手が台帳に無い（画面が古い・作り直しで消えた）'; Alert ("この相手（" + $aite + "）が台帳にありません。`r`nボードの画面が古いことがあります（取り消した相手は、作り直しで行が無くなります）。`r`n`r`n熊田さんがすること：ボードを閉じて開き直してください（ブラウザ版は読み直し）。開き直してもこの行が出るときは、仕組みの側の止まりです。ボードのいちばん上の「仕組みの困りごと」に載りました。熊田さんが直す必要はありません。"); Note "候補なし $caseId $aite"; break }   # 2026-10-09 マニュアル係（追加）
    # 2026-10-31 草案（発注チェーンの点検・本番未投入） 項目1・2：済み（送った・現場が発注済み など）と、現場の判定で止めた行は、裏でも下書きを作らない（今は画面のボタンを隠すだけ）
    if ($DONE -contains [string]$c.状態 -or $GENBA_HOLD -contains [string]$c.状態) { Alert ("この行は『" + [string]$c.状態 + "』です。下書きは作りません。" + $(if ([string]$c.現場の記録) { "`r`n（" + [string]$c.現場の記録 + "）" } else { '' })); Note "draft 中止（済み・現場の判定で止めた行 $($c.状態)）$caseId $aite"; break }
    if (-not (Kumada-Gate $caseId $aite $d 'draft')) { break }
    # 2026-09-23 点検役 57点⛔2：画面のボタンを消しただけでは、開いたままの古い画面から呼べてしまう。裏側でも止める
    # 2026-09-26：下書きを作る途中（Display）で時間切れになると、下書きは1通あるのに台帳は「まだ」のまま。
    #   make_order_drafts が Save の直後に置く『作りかけの印』を先に見て、2通目を作らない
    $tsukuriDir = Join-Path $planDir '_作りかけ'
    # 名前の作り方は make_order_drafts.ps1 に合わせる（空白も _ にする。合わせないと印を拾えない・2026-09-26）
    $tsukuriPath = Join-Path $tsukuriDir ((($caseId + '_' + $aite) -replace '[\\\\/:*?"<>|\\s　]', '_') + '.json')
    if ((Test-Path $tsukuriPath) -and ([string]$c.状態 -ne '下書き済')) {
        $tk = $null; try { $tk = Get-Content $tsukuriPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
        if ($tk -and $tk.EntryID) {
            $ikiteru2 = $false
            try { (Outlook-Item $tk.EntryID $tk.StoreID).Display(); $ikiteru2 = $true } catch {}
            if ($ikiteru2) {
                # 下書きはもうある。台帳に書き込んで、その1通を開くだけ（新しくは作らない）
                $c.状態 = '下書き済'; $c.日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm'); $c.EntryID = [string]$tk.EntryID; $c.StoreID = [string]$tk.StoreID; $c.件名 = [string]$tk.件名
                $c | Add-Member -NotePropertyName 作ったPC -NotePropertyValue $env:COMPUTERNAME -Force   # 2026-10-08 穴28
                Save-Ledger $L
                try { Remove-Item $tsukuriPath -Force } catch {}
                Alert "前に作りかけで止まった下書きが見つかりました。`r`n新しく作らず、その1通を開きました。中身を確かめて送ってください。"
                Note "draft 作りかけの下書きを拾った $caseId $aite"; break
            } else {
                # 印はあるが Outlook に無い＝送った可能性。止めて人に確かめてもらう
                try { Remove-Item $tsukuriPath -Force } catch {}
                $c.状態 = '送ったか確かめて'; $c.日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm'); Save-Ledger $L
                Alert "作りかけの下書きが見つかりません。すでに送った可能性があります。`r`nOutlook の［送信済みアイテム］を見て、送っていれば［送れていた］、送っていなければ［送れていない（やり直す）］を押してください。"
                Note "draft 中止（作りかけの印はあるが下書きが無い）$caseId $aite"; break
            }
        }
    }
    # 2026-09-28：数量限定などで「送る前に一声」が付いた行は、人が確かめるまで下書きを作らない
    if ($c.送る前に確認 -eq $true -and ([string]$c.確認しました.確かめた理由 -ne [string]$c.確認の理由)) {
        Alert ("この発注は、送る前に確かめることがあります。`r`n`r`n" + [string]$c.確認の理由 + "`r`n`r`n確かめたら［注意を確かめました］を押してください。そのあと下書きが作れます。")
        Note "draft 中止（送る前に確認がまだ）$caseId $aite"; break
    }
    if ($STUCK -contains [string]$c.状態) {
        Alert ("この行は『" + $c.状態 + "』で止まっています。`r`n先に［送ったか確かめる］を押すか、Outlook の［送信済みアイテム］を見てください。`r`n送っていれば［送れていた］、送っていなければ［送れていない（やり直す）］を押してください。")
        Note "draft 中止（止まっている状態）$caseId $aite $($c.状態)"; break
    }
    # 2026-10-08 穴28（9代目ボス）：下書きは作ったPCの Outlook にしか無い。別のPCで押すと「見つからない」→作り直し＝二重送付の入り口になる。作ったPCの名前で止める
    if ($c.状態 -eq '下書き済' -and [string]$c.作ったPC -and [string]$c.作ったPC -ne $env:COMPUTERNAME) {
        Add-Komarigoto '別のPCの下書き' $caseId $aite ('下書きは「' + [string]$c.作ったPC + '」のPCの Outlook にある・押したPC＝' + $env:COMPUTERNAME)   # 2026-10-09 マニュアル係⑬
        Alert ("この下書きは「" + [string]$c.作ったPC + "」のPCで作ってあります。`r`nそのPCの Outlook の［下書き］＞［発注ボード］を開いて送ってください。`r`nここでは作り直しません（二重に送らないため）。`r`n`r`n熊田さんがすること：そのPCが使えるときは、そのPCで送るだけです。使えないときは待ってください。`r`n`r`nこの件はボードのいちばん上の「仕組みの困りごと」に載り、玉井さんに届きます。熊田さんが伝える必要はありません。")
        Note "draft 中止（別のPCで作った下書き $($c.作ったPC)）$caseId $aite"; break
    }
    if ($c.状態 -eq '下書き済' -and $c.EntryID) {
        # 2026-09-23 点検役（Fable 5.1）⛔3：開けない＝送信して下書きが消えた可能性。作り直すと2通目を送る道になる → 止めて人に確かめてもらう
        try { (Outlook-Item $c.EntryID $c.StoreID).Display(); Note "open（下書き済のため開き直し）$caseId $aite"; break }
        catch {
            $c.状態 = '送ったか確かめて'; $c.日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm'); Save-Ledger $L
            Alert "下書きが見つかりません。すでに送った可能性があります。`r`nOutlook の［送信済みアイテム］を見て、送っていればボードの［送れていた］を押してください。まだなら［送れていない（やり直す）］を押すと作り直せます。"
            Note "draft 中止（下書きが開けない・作り直さない）$caseId $aite"; break
        }
    }
    # 古い下書き（中身が変わって候補に戻ったもの）に【旧】を付ける（消さない）
    $kieta = $false
    foreach ($o in @($c.旧下書き)) {
        if (-not $o -or -not $o.EntryID -or $o.印済み) { continue }
        # 2026-09-23 点検役 57点⛔2：前の版の下書きが下書きフォルダから消えている＝すでに送った可能性が高い。
        #   ここで新しい下書きを作ると、同じ発注の全量が2通届く。残っていれば送っていない＝そのまま進めてよい
        try { $it = Outlook-Item $o.EntryID $o.StoreID; if (-not $it.Subject.StartsWith('【旧】')) { $it.Subject = '【旧】' + $it.Subject; $it.Save() }; $o | Add-Member -NotePropertyName 印済み -NotePropertyValue $true -Force } catch { $kieta = $true; Note "旧下書きが開けない $($o.EntryID): $($_.Exception.Message)" }
    }
    if ($kieta) {
        $c.状態 = '送ったか確かめて'; $c.日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm'); Save-Ledger $L
        Alert "前の版の下書きが見つかりません。すでに前の版を送った可能性があります。`r`n［送ったか確かめる］を押して、送信済みを見てから進めてください。`r`n（このまま作ると、同じ発注が2通届きます）"
        Note "draft 中止（前の版の下書きが消えている）$caseId $aite"; break
    }
    $engine = Join-Path $PSScriptRoot 'make_order_drafts.ps1'
    $n = $d.納品
    $prm = @{ Budget = [double]$d.売上予算; Type = [string]$d.型; DeliveryDate = [string]$n.納品希望日; Address = [string]$n.住所; Venue = [string]$n.会場; Attn = [string]$n.宛名; Tel = [string]$n.TEL
              Days = [int]$n.営業日数; Brand = [string]$d.屋号; Account = [string]$cfg.Account; FaxAccount = [string]$cfg.FaxAccount; DraftFolder = [string]$cfg.DraftFolder
              CaseId = $caseId; Label = ''; Only = $aite; Open = $true }
    # 2026-10-03 玉井さん：件名は熊田さんが 10/2 に直した短い形（「2026.10.2発注書」・FAXは「発注書」）。
    #   頭の「[発注] 会場 日付｜相手」は仕入先に見えるので付けない（Label を渡さない）。照合は UserProperties と写しの宛先で行うので件名に頼らない
    # 2026-10-23 24代目ボス（AIかおり 31 の点検役）：学問の台帳の「型」は空（予算ファイルに型が無い屋号）。空のまま渡すと make_order_drafts の ValidateSet で止まる
    #   ＝process_budget_files.ps1:267 と同じく、屋号.json の「既定の型」（学問＝A）を渡す。AIかおりのだるまの割合（40〜65）が台帳に入れば、そのまま渡る
    if (-not $prm.Type) {
        try { $yc = Get-Content (Join-Path $PSScriptRoot '屋号.json') -Raw -Encoding UTF8 | ConvertFrom-Json
              if ($yc.($d.屋号) -and [string]$yc.($d.屋号).既定の型) { $prm.Type = [string]$yc.($d.屋号).既定の型; Note "型が空のため屋号の既定の型 $($prm.Type) を使う $caseId $aite" } } catch {}
    }
    # 2026-10-23 発注ボード（同じ点検で原本を読んで見つけた）：商品マスター（Workbook）を渡していなかった＝学問の下書きがクシローの表で組まれる。process_budget_files.ps1:210 と同じく屋号の表を渡す（無ければ今までどおり既定＝クシロー）
    $yagoBook = Join-Path $PSScriptRoot ('商品マスター_' + [string]$d.屋号 + '.xlsx')
    if ((Test-Path $yagoBook) -and -not $prm.ContainsKey('Workbook')) { $prm.Workbook = $yagoBook }
    if ($cfg.Test -eq $true) { $prm.Test = $true }
    # 2026-10-01：担当者の「修正あり」を下書きの本文に反映させる（process_budget_files.ps1 と同じ渡し方）。
    #   これを渡していなかったので、台帳の候補は直っているのに、下書きの本文だけ直す前の案で出ていた
    #   （阪神1週目のセニヤ＝台帳 2c/s・2c/s なのに、本文は くんあし 1c/s・炙りいわし 3c/s）
    $fixP = Join-Path (Join-Path $root '確認') ($caseId + '.json')
    if (Test-Path $fixP) { $prm.FixPath = $fixP }
    if ($d.修正の扱い) { $prm.ShuseiAtsukai = [string]$d.修正の扱い.扱い; $prm.ShuseiKagi = [string]$d.修正の扱い.答えた日時 }   # 2026-10-31 草案（発注チェーンの点検・本番未投入） 項目5（process_budget_files と同じ渡し方）
    if ($d.担当者の確認) { $prm.ShuseiZenkai = [string]$d.担当者の確認.反映; $prm.ShuseiZenkaiKagi = [string]$d.担当者の確認.答えた日時 }
    $prm.NaoshiDir = Join-Path $planDir '予定の直し'   # 2026-10-07 予定の直し（process_budget_files と同じ渡し方・点検役(3)。渡さないと台帳は直っているのに下書きの本文だけ直す前の案になる＝10/1 の確認と同じ事故）
    # 2026-10-15 週ごとの売上予算は渡さない（催事を週で分けない・玉井さん 10/15）
    # 2026-09-23 点検役 H4：一度［やり直す］を通った行＝前に何かを送っている可能性がある。相手が取り違えないよう【差し替え】と前書きを付ける
    # 2026-09-26 点検役6：【差し替え】が付くのが「止まった状態からやり直した」ときだけだった。
    #   ふつうに［戻す］→［下書きを作って開く］とやると無印の2通目が仕入先に届く。
    #   一度でも送った形跡（送信済みに見つかった・旧下書きがある）があれば必ず付ける。
    # 2026-10-07 玉井さん（井上のヒロツク）：9/30 に「このPCでは開けない箱」として片付けた旧下書きは、送っていない＝送った形跡に数えない
    #   （数えたので、何も送っていないヒロツクに【差し替え】が付いた）
    $atta = ($c.人が確かめた) -or ([int]$c.見つけた通数 -ge 1) -or (@(@($c.旧下書き) | Where-Object { $_ -and [string]$_.理由 -notmatch '開けない箱' }).Count -ge 1)
    # 2026-10-07 玉井さん：下書きを先に開いてから裏で件名・本文を書き換えて保存していたので、開いた窓が古いままになり、
    #   本文を消して送ろうとすると Outlook が「メッセージを変更できないため、操作を実行できません」で止まった。
    #   【差し替え】を付けるときは、書き換えて保存してから開く
    if ($atta) { $prm.Open = $false }
    $out = & $engine @prm
    $line = $out | Where-Object { $_ -is [string] -and $_.StartsWith('DRAFT') } | Select-Object -First 1
    # 2026-10-09 マニュアル係①：押し直してよいか・誰に届くかを書く。機械の返事は困りごとの一覧へ（熊田さんに読ませない）
    if (-not $line) { Add-Komarigoto '下書きができない' $caseId $aite (($out | Select-Object -First 5) -join ' / '); Alert ("下書きができませんでした。`r`n仕組みの側で止まっています。熊田さんが直す必要はありません。`r`nボードのいちばん上の「仕組みの困りごと」に自動で載りました（玉井さんも同じ画面で見ます）。`r`n`r`n熊田さんがすること：`r`n・もう一度押すのは1回まで（同じ下書きが2通できることはありません）。`r`n・急ぐときは、この相手にはいつもどおり手で送り、送った後にこの行の［送った］を押してください。`r`n・急がないときは待つだけです。直ると、この行の［下書きを作って開く］がまた使えます。"); Note "draft 失敗 $caseId $aite : $($out -join ' / ')"; break }
    $p = $line.Split("`t")
    if ($atta) {
        try {
            $mi = Outlook-Item $p[2] $p[3]
            if (-not $mi.Subject.StartsWith('【差し替え】')) { $mi.Subject = '【差し替え】' + $mi.Subject }
            # ヒロツクのFAXは本文を付けない（発注書PDFだけ）＝前書きも足さない。差し替えは件名で伝わる
            if ([string]$mi.Body.Trim()) { $mi.Body = "※さきにお送りした注文の差し替えです。前の注文は取り消して、こちらの数量でお願いいたします。`r`n`r`n" + $mi.Body }
            $mi.Save()
            $p[4] = [string]$mi.Subject
        } catch { Note "差し替えの印を付けられず $caseId $aite : $($_.Exception.Message)" }
        try { (Outlook-Item $p[2] $p[3]).Display() } catch { Note "差し替えの下書きを開けず $caseId $aite : $($_.Exception.Message)" }
        $c | Add-Member -NotePropertyName 人が確かめた -NotePropertyValue $null -Force
    }
    $c.状態 = '下書き済'; $c.日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm'); $c.EntryID = $p[2]; $c.StoreID = $p[3]; $c.件名 = $p[4]
    $c | Add-Member -NotePropertyName 作ったPC -NotePropertyValue $env:COMPUTERNAME -Force   # 2026-10-08 穴28：どのPCの Outlook にあるか
    try { if (Test-Path $tsukuriPath) { Remove-Item $tsukuriPath -Force } } catch {}   # 台帳に書けたので作りかけの印は要らない
    Save-Ledger $L
    # 2026-09-30：作った下書きが本当にこのPCで開けるかを確かめる。
    #   board_config の Account の箱（PST）がこのPCに無いと、下書きは作られても開けず、
    #   台帳だけ『下書き済』になって［下書きを開く］が無反応になる（玉井さん 9/30）。
    $hirakeru = $false
    try { $null = (Outlook-Item $p[2] $p[3]).Subject; $hirakeru = $true } catch { }
    if (-not $hirakeru) {
        Add-Komarigoto 'このPCでは下書きを開けない' $caseId $aite ('設定の宛先の箱（' + [string]$cfg.Account + '）がこのPC（' + $env:COMPUTERNAME + '）の Outlook に無い')   # 2026-10-09 マニュアル係⑬
        Alert ("下書きは作られましたが、<<このPCでは開けません>>。`r`n`r`n設定の宛先の箱（" + [string]$cfg.Account + "）が、このPCの Outlook にありません。`r`n発注ボードは<<熊田さんのPC>>で使ってください。`r`n`r`n台帳には書きません（『まだ送っていません』のままにします）。もう一度押しても同じです。`r`n`r`n熊田さんがすること：熊田さんのPCのボードで同じボタンを押してください。`r`n`r`nこの件はボードのいちばん上の「仕組みの困りごと」に載り、玉井さんに届きます。熊田さんが伝える必要はありません。").Replace('<<','「').Replace('>>','」')
        Note "draft 中止（作った下書きがこのPCで開けない・Account=$($cfg.Account)）$caseId $aite"
        break
    }
    # 2026-09-26 AIかおりと取り決め：下書きを作ったら「この内容で発注します」を担当者へ戻す材料を書き出す。
    #   読み違い（品目・数量）を本人が見つけられるようにするため。出す口（LINE）はAIかおり側。
    # 2026-09-26 玉井さん決定：出すのは「修正あり」だった件だけ。返事は求めない。
    #   ［OK］の件は数量を機械が持っていて人が1文字も打っていない＝読み違いが起きない。
    #   人が手で直す「修正あり」の経路だけが危ない。AIかおりの修正ページができたら、この戻しごと止める。
    $kakuninKotae = [string]$d.担当者の確認.答え
    $modosu = ($kakuninKotae -eq '修正あり')   # 担当者へLINEで返すのは「修正あり」の件だけ（玉井さん 2026-09-26）
    try {
        $modDir = Join-Path (Join-Path $root '確認') '_発注した中身'
        if (-not (Test-Path $modDir)) { New-Item -ItemType Directory -Path $modDir -Force | Out-Null }
        $hinmoku = @()
        foreach ($part in ([string]$c.中身 -split '／')) {
            $t = $part.Trim(); if (-not $t) { continue }
            $ryou = ''; $shina = $t
            if ($t -match '^(.*?)\s*([0-9０-９]+(?:\.[0-9]+)?\s*(?:c/s|ケース|kg|k|袋|枚|本|個))\s*$') { $shina = $Matches[1].Trim(); $ryou = $Matches[2].Trim() }
            $hinmoku += [pscustomobject]@{ 品名 = $shina; 量 = $ryou; 原文 = $t }
        }
        # 実際に送る本文を、作った下書きから読む（自分で作った下書きなので安全）
        $honbun = ''
        try { $mi2 = Outlook-Item $p[2] $p[3]; $honbun = [string]$mi2.Body } catch { Note "下書きの本文が読めず $caseId $aite" }
        $modName = (($caseId + '_' + $aite) -replace '[\\/:*?"<>|]', '_') + '.json'
        $modBody = [pscustomobject]@{
            説明 = '発注ボードが下書きを作った中身。担当者へ「この内容で発注します」と戻すための材料。送る口はAIかおり'
            出した理由 = '担当者が「修正あり」で直した件。熊田さんが手で数量を直しているので、読み違いがないかを本人に見てもらう'
            返事は要らない = $true
            修正リストの原文 = [string]$d.担当者の確認.修正リスト
            案件ID = $caseId
            会場 = [string]$d.会場
            担当者 = [string]$d.担当者
            相手 = [string]$c.相手
            方法 = [string]$c.方法
            品目 = @($hinmoku)
            中身の原文 = [string]$c.中身
            件名 = [string]$p[4]
            本文 = $honbun          # 実際の下書きの本文。台帳の「中身」は画面用に切り詰められている（末尾が…）ので使わない
            中身は省略あり = ([string]$c.中身).EndsWith([char]0x2026)
            下書きを作った日時 = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
            送る日 = [string]$c.送る日
            納品希望日 = [string]$d.納品.納品希望日
        }
        # 書きかけを読まれないよう、別名に書いてから差し替える
        # 2026-09-28：作り直しても前の本文を消さない。版を足していく（送ったのがどの版かを後から追えるように）
        $modPath = Join-Path $modDir $modName
        $ban = @()
        if (Test-Path $modPath) { try { $ban = @((Get-Content $modPath -Raw -Encoding UTF8 | ConvertFrom-Json).版) } catch { $ban = @() } }
        $ban = @(@($ban) | Where-Object { $_ })
        $modBody | Add-Member -NotePropertyName 版番号 -NotePropertyValue (@($ban).Count + 1) -Force
        $ban += $modBody
        $matome = [pscustomobject]@{
            説明 = '発注ボードが作った下書きの中身。版を足していく（消さない）。11月の答え合わせ（案の量／現場の量／使った量）に使う'
            案件ID = $caseId; 会場 = [string]$d.会場; 相手 = [string]$c.相手
            担当者へ戻す = $modosu   # true のときだけ AIかおりが担当者へ1通返す（修正ありの件だけ）
            版の数 = @($ban).Count
            最新の版 = @($ban)[-1].版番号
            版 = @($ban)
        }
        $modTmp = $modPath + '.tmp'
        [IO.File]::WriteAllText($modTmp, ($matome | ConvertTo-Json -Depth 8), $utf8bom)
        Move-Item $modTmp $modPath -Force
        Note "発注した中身を書き出した $caseId $aite（$(@($hinmoku).Count)品・第$(@($ban).Count)版・担当者へ戻す=$modosu）"
    } catch { Note "発注した中身の書き出しに失敗 $caseId $aite : $($_.Exception.Message)" }
    Note "draft $caseId $aite → $($p[4])"
  }
  'open' {
    $L = Load-Ledger $caseId
    $c = $L.Doc.候補 | Where-Object { $_.相手 -eq $aite } | Select-Object -First 1
    if (-not $c -or -not $c.EntryID) { Alert 'まだ下書きがありません。［下書きを作って開く］を押してください。'; break }
    if (Test-KaikiOwatta $L.Doc) { Alert ("この催事は会期が終わっています（会期終了 " + [string]$L.Doc.会期終了 + "）。残っている下書きは送らないでください。"); Note "open 中止（会期が終わった）$caseId $aite"; break }   # 2026-10-31 草案（発注チェーンの点検・本番未投入）
    if ([string]$c.作ったPC -and [string]$c.作ったPC -ne $env:COMPUTERNAME) { Add-Komarigoto '別のPCの下書き' $caseId $aite ('下書きは「' + [string]$c.作ったPC + '」のPCの Outlook にある・押したPC＝' + $env:COMPUTERNAME); Alert ("この下書きは「" + [string]$c.作ったPC + "」のPCで作ってあります。`r`nそのPCの Outlook の［下書き］＞［発注ボード］から開いてください。`r`n`r`n熊田さんがすること：そのPCが使えるときは、そのPCで開いて送るだけです。使えないときは待ってください。`r`n`r`nこの件はボードのいちばん上の「仕組みの困りごと」に載り、玉井さんに届きます。熊田さんが伝える必要はありません。"); Note "open 中止（別のPC $($c.作ったPC)）$caseId $aite"; break }   # 2026-10-08 穴28
    if (-not (Kumada-Gate $caseId $aite $L.Doc 'open')) { break }
    try { (Outlook-Item $c.EntryID $c.StoreID).Display(); Note "open $caseId $aite" }
    catch { Add-Komarigoto '下書きが開けない' $caseId $aite $_.Exception.Message; Alert "下書きが見つかりません（送信済みか、削除された可能性）。`r`n送っていれば30分ほどで自動で「送った」になります（確かめるのは朝8:15〜夜9:45。夜に送った分は翌朝）。`r`n`r`n熊田さんがすること：Outlook の［送信済みアイテム］を見て、送っていればこの行の［送った］を押してください。送っていなければ、この行の［戻す］を押すと作り直せます。`r`n（この件はボードの上の「仕組みの困りごと」にも載りました）"; Note "open 失敗 $caseId $aite : $($_.Exception.Message)" }
  }
  'mark' {
    if (-not $State) { throw '状態がありません' }
    $L = Load-Ledger $caseId
    $c = $L.Doc.候補 | Where-Object { $_.相手 -eq $aite } | Select-Object -First 1
    if (-not $c) { Add-Komarigoto '相手が台帳に無い' $caseId $aite '画面に出ている相手が台帳に無い（画面が古い・作り直しで消えた）'; Alert ("この相手（" + $aite + "）が台帳にありません。`r`nボードの画面が古いことがあります（取り消した相手は、作り直しで行が無くなります）。`r`n`r`n熊田さんがすること：ボードを閉じて開き直してください（ブラウザ版は読み直し）。開き直してもこの行が出るときは、仕組みの側の止まりです。ボードのいちばん上の「仕組みの困りごと」に載りました。熊田さんが直す必要はありません。"); Note "候補なし $caseId $aite"; break }   # 2026-10-09 マニュアル係（追加）
    # 2026-10-08 人が［送った］を押す時だけ止める（定期実行の自動の「送った」＝もう送った事実の記録は止めない。ブラウザ版は押した人＝HACCHU_WHO がある）
    # 2026-10-09 マニュアル係⑰：⚠二重・⚠古い中身の行の［相手に伝えた］は送信ではなく「電話・メールで伝えた事実」の記録＝熊田さんの直し待ちで止めない
    if ($State -eq '送った' -and ($env:HACCHU_NO_ALERT -ne '1' -or $env:HACCHU_WHO) -and [string]$c.状態 -notin @('⚠二重に送っています', '⚠古い中身で送っています')) { if (-not (Kumada-Gate $caseId $aite $L.Doc 'mark')) { break } }
    $prevState = [string]$c.状態
    # 2026-10-31 草案（発注チェーンの点検・本番未投入） 項目1：［数を確かめた］は状態を変えない。現場の照合に「数も確認済み」と、押した人・時刻を書くだけ
    if ($State -eq '数を確かめた') {
        $shD = [ordered]@{}; if ($c.現場の照合) { foreach ($pp in $c.現場の照合.PSObject.Properties) { $shD[$pp.Name] = $pp.Value } }
        $shD.数 = '確認済み'; $shD.数を確かめた人 = $(if ($env:HACCHU_WHO) { $env:HACCHU_WHO } else { $env:USERNAME }); $shD.数を確かめた日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm')
        $c | Add-Member -NotePropertyName 現場の照合 -NotePropertyValue ([pscustomobject]$shD) -Force
        Save-Ledger $L; Note "数を確かめた $caseId $aite"; break
    }
    # 2026-10-31 草案（発注チェーンの点検・本番未投入） 項目2：自動の現場の判定（現場が発注済み・一部・取消の確かめ待ち）を人が［戻す］で外した＝その時までの根拠では当て直さない（誤って成立した完了の訂正）
    if ($State -eq '候補' -and ($prevState -eq '現場が発注済み' -or $GENBA_HOLD -contains $prevState)) {
        $c | Add-Member -NotePropertyName 現場の判定を外した -NotePropertyValue ([pscustomobject][ordered]@{ 日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm'); 押した人 = $(if ($env:HACCHU_WHO) { $env:HACCHU_WHO } else { $env:USERNAME }); 前の状態 = $prevState; 前の記録 = [string]$c.現場の記録 }) -Force
    }
    if ($State -eq '現場が発注済み' -and $GENBA_HOLD -contains $prevState) {
        $c | Add-Member -NotePropertyName 現場の照合 -NotePropertyValue ([pscustomobject][ordered]@{ 区分 = '人が決めた（全部 現場で発注済み）'; 数 = '未確認'; 前の照合 = $c.現場の照合; 決めた日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm') }) -Force
    }
    # 2026-09-23 点検役 2-①：人が状態を決めた時点の「送信済みの通数」を覚える。次の verify はここから増えた時だけ赤にする
    if ($State -in @('送った', '候補', '不要')) { $c | Add-Member -NotePropertyName 確かめた通数 -NotePropertyValue ([int]$c.見つけた通数) -Force }
    $c.状態 = $State; $c.日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm')
    # 2026-10-08 ブラウザ版：押した人とどこで（出荷の板の条件＝PCの名前でなくブラウザで入った人）。PCのボードから押した時は PC の利用者名とPC名
    $c | Add-Member -NotePropertyName 押した人 -NotePropertyValue $(if ($env:HACCHU_WHO) { $env:HACCHU_WHO } else { $env:USERNAME }) -Force
    $c | Add-Member -NotePropertyName どこで -NotePropertyValue $(if ($env:HACCHU_WHO) { 'ブラウザ' } else { $env:COMPUTERNAME }) -Force
    # 2026-10-08 穴21：⚠古い中身 から［相手に今の数を伝えた］＝人が相手へ直した。古い下書きを確認済みにしないと、次の verify でまた⚠古い中身に戻る
    if ($State -eq '送った' -and $prevState -eq '⚠古い中身で送っています') {
        foreach ($o in @($c.旧下書き)) { if ($o) { $o | Add-Member -NotePropertyName 印済み -NotePropertyValue $true -Force } }
        $c | Add-Member -NotePropertyName 相手に今の数を伝えた -NotePropertyValue (Get-Date -Format 'yyyy-MM-dd HH:mm') -Force
    }
    # 2026-10-12 マニュアル係 続き6-1：下書き済の相手を［不要］にすると、Outlook の下書きが送れる形のまま残り【旧】も付かなかった＝後で送ってしまう芽。
    #   不要にした時点で、その下書きの件名に【旧・不要】を付ける（消さない）。作ったPCが別なら付けられないので、困りごとに載せる
    if ($State -eq '不要' -and $prevState -eq '下書き済' -and [string]$c.EntryID) {
        if ([string]$c.作ったPC -and [string]$c.作ったPC -ne $env:COMPUTERNAME) { Add-Komarigoto '不要にした下書きが残っている' $caseId $aite ('下書きは「' + [string]$c.作ったPC + '」のPCの Outlook にある＝そのPCで件名に【旧・不要】を付けるか消す') }
        else { try { $itF = Outlook-Item ([string]$c.EntryID) ([string]$c.StoreID); if (-not ([string]$itF.Subject).StartsWith('【旧')) { $itF.Subject = '【旧・不要】' + [string]$itF.Subject; $itF.Save() }; Note "不要：下書きに【旧・不要】を付けた $caseId $aite" } catch { Note "不要：下書きに印を付けられず（Outlookが閉じている・下書きが無い）$caseId $aite : $($_.Exception.Message)" } }
        $c | Add-Member -NotePropertyName 旧下書き -NotePropertyValue @(@(@($c.旧下書き) | Where-Object { $_ }) + [pscustomobject]@{ EntryID = $c.EntryID; StoreID = $c.StoreID; 件名 = $c.件名; 戻した日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm'); 理由 = '不要にした'; 印済み = $true }) -Force
    }
    if ($State -eq '候補') {
        # 2026-09-23 点検役 H3：EntryID を消すだけだと、Outlook の下書きフォルダに前の1通が残ったまま2通目を作れてしまう。
        #   旧下書きとして覚えておき、次に draft したときに件名へ【旧】を付ける（消さない）
        if ($c.EntryID) {
            $old = @(@($c.旧下書き) | Where-Object { $_ })
            if (-not (@($old | Where-Object { [string]$_.EntryID -eq [string]$c.EntryID }).Count)) {
                $old += [pscustomobject]@{ EntryID = $c.EntryID; StoreID = $c.StoreID; 件名 = $c.件名; 戻した日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm') }
            }
            $c | Add-Member -NotePropertyName 旧下書き -NotePropertyValue @($old) -Force
        }
        # 2026-09-23 点検役 H4：止まっている状態から［やり直す］を押したときは、人が送信済みを見て『送っていない』と決めたということ。
        #   旧下書きを確認済みにして、次の draft が通るようにする（これが無いと永久に新しい下書きを作れない行き止まりになる）
        if ($STUCK -contains $prevState) {
            # 2026-09-23 点検役 2-⑤：まだ Outlook に残っている古い便には【旧】を付けてから確認済みにする（無印のまま2通出るのを防ぐ）
            foreach ($o in @($c.旧下書き)) {
                if (-not $o) { continue }
                if ($o.EntryID) { try { $it2 = Outlook-Item $o.EntryID $o.StoreID; if (-not $it2.Subject.StartsWith('【旧】')) { $it2.Subject = '【旧】' + $it2.Subject; $it2.Save() } } catch {} }
                $o | Add-Member -NotePropertyName 印済み -NotePropertyValue $true -Force
            }
            $c | Add-Member -NotePropertyName 人が確かめた -NotePropertyValue (Get-Date -Format 'yyyy-MM-dd HH:mm') -Force
            if ($prevState -eq '送信トレイで止まっています') {
                Alert "注意：前の便が Outlook の［送信トレイ］に残っています。`r`nそのままだと、Outlook がつながった時にその便も相手に届きます。`r`n先に送信トレイを開いて、その便を削除するか下書きに戻してから、新しい下書きを作ってください。"
            }
            Note "やり直す：$caseId $aite（$prevState → 候補・人が確かめた）"
        }
        $c.EntryID = ''; $c.StoreID = ''; $c.件名 = ''
        $c | Add-Member -NotePropertyName 作ったPC -NotePropertyValue '' -Force   # 2026-10-08 穴28：候補に戻したら、次はどのPCで作ってもよい
    }
    Save-Ledger $L
    # 2026-10-30 穴-104（26代目ボスの裁定 (b)・設計図 v2 602 の確定＝5代目ボス 10/6）：倉庫出しの行を「倉庫から出した」にした時と、そこから戻した時に、
    #   発注\記録\倉庫出し_出した.json に1行足す（足すだけ・消さない・書き換えない）。key＝「案件ID|倉庫出し」。戻した時は同じ key で 取り消し＝true の1行。
    #   読む側（出荷の板・AIかおり）は key ごとに最後の行だけを見る。AIかおりの［倉庫から持っていった］から当てた時は、どこで・押した人をその記録から入れる
    if ($c.方法 -eq '倉庫出し' -and $State -ne $prevState -and ($State -eq '倉庫から出した' -or $prevState -eq '倉庫から出した') -and -not $DryRun) {
        try {
            $dp = Join-Path $root '記録\倉庫出し_出した.json'
            $dj = $null; if (Test-Path $dp) { for ($try = 1; $try -le 3; $try++) { try { $dj = Get-Content $dp -Raw -Encoding UTF8 | ConvertFrom-Json; break } catch { Start-Sleep -Milliseconds 700 } }; if (-not $dj) { throw '倉庫出し_出した.json が読めない（書かずに止めた）' } }
            $drows = @(); if ($dj) { $drows = @(@($dj.行) | Where-Object { $_ }) }
            $dNew = [ordered]@{ key = ($caseId + '|倉庫出し'); 案件ID = $caseId }
            if ($State -eq '倉庫から出した') { $dNew.状態 = '出した' } else { $dNew.取り消し = $true }
            $dNew.押した人 = $(if ($env:HACCHU_OSHITA) { $env:HACCHU_OSHITA } else { '発注ボードを使った人（' + $env:COMPUTERNAME + '）' })
            $dNew.時刻 = (Get-Date -Format 'yyyy-MM-dd HH:mm')
            $dNew.どこで = $(if ($env:HACCHU_DOKODE) { $env:HACCHU_DOKODE } else { '発注ボード' })
            $drows += [pscustomobject]$dNew
            $dTmp = $dp + '.tmp'
            [IO.File]::WriteAllText($dTmp, ([ordered]@{ 説明 = '倉庫出しを出した記録（足すだけ・消さない）。key＝案件ID|倉庫出し。key ごとに最後の行が正。最後が 取り消し＝true なら出していない。状態＝出した／今日は出せない。書く側＝発注ボード（board_action.ps1）と AIかおり'; 行 = @($drows) } | ConvertTo-Json -Depth 5), $utf8bom)
            Move-Item $dTmp $dp -Force
            Note "倉庫出し_出した $caseId → $(if ($dNew.Contains('取り消し')) { '取り消し' } else { '出した' })"
        } catch { Note "倉庫出し_出した を書けず：$($_.Exception.Message)"; try { Add-Komarigoto '倉庫出し_出した を書けない' $caseId '倉庫出し' ([string]$_.Exception.Message) } catch {} }
    }
    # 2026-09-22 倉庫出し：［倉庫から出した］で倉庫ストック品.json の在庫を減らす（動き＝マイナス）。［戻す］で取り消す（動きを消す）
    # 2026-10-09 在庫の会話の依頼（設計 柱4-1）：ここで動きを書くのをやめた。在庫側が発注案 json の状態（倉庫から出した）を読んで出庫にしている＝2か所に書くとずれる
    if ($false -and $c.方法 -eq '倉庫出し' -and ($State -eq '倉庫から出した' -or $prevState -eq '倉庫から出した')) {
        $sp = Join-Path $PSScriptRoot '倉庫ストック品.json'
        $st = $null
        for ($try = 1; $try -le 3; $try++) { try { $st = Get-Content $sp -Raw -Encoding UTF8 | ConvertFrom-Json; break } catch { Start-Sleep -Milliseconds 700 } }
        if (-not $st) { Alert '倉庫の在庫の表が読めませんでした。少し待って、もう一度押してください。'; Note "倉庫ストック品が読めない"; break }
        $moves = @(@($st.動き) | Where-Object { $_ -and -not ($_.案件ID -eq $caseId -and $_.理由 -eq '倉庫出し') })
        if ($State -eq '倉庫から出した') {
            # 2026-10-06 ロット品は袋（1kg）で出す＝字は「Nkg（1kg×N袋）」。古い「Nc/s」は N×1ケースkg。中身は「…」で切れるので中身全文を読む
            $zen = $(if ([string]$c.中身全文) { [string]$c.中身全文 } else { [string]$c.中身 })
            foreach ($part in ($zen -split '／')) {
                foreach ($p in $st.品目.PSObject.Properties) {
                    $names = @([string]$p.Value.品名) + @($p.Value.別名) + $(if ($p.Name -eq 'K015') { @('しそ味ひじき') } else { @() })
                    if (-not @($names | Where-Object { $_ -and $part.Contains($_) }).Count) { continue }
                    $ck = [double]$p.Value.'1ケースkg'; if ($ck -le 0) { $ck = [double]$p.Value.最小単位kg }
                    $q = $(if ($part -match '(\d+(?:\.\d+)?)\s*kg（1kg') { [double]$Matches[1] } elseif ($part -match '(\d+(?:\.\d+)?)\s*c/s') { [double]$Matches[1] * $ck } else { 0 })
                    if ($q -gt 0) { $moves += [pscustomobject]@{ 日付 = (Get-Date -Format 'yyyy-MM-dd'); 品目コード = $p.Name; kg = -$q; 案件ID = $caseId; 理由 = '倉庫出し'; 中身 = $part.Trim() } }
                }
            }
        }
        $st.動き = $moves
        [IO.File]::WriteAllText($sp, ($st | ConvertTo-Json -Depth 8), $utf8bom)
        Note "倉庫の在庫 $caseId → $State（動き $(@($moves).Count)件）"
    }
    if ($DONE -contains $State) { Add-OkuttaKiroku $caseId $aite $State ([string]$c.件名) }
    Note "mark $caseId $aite → $State"
  }
  'verify' {
    # 2026-09-23：送信済み・送信トレイを「目印だけ」で照合する（本文・宛先は読まない＝Outlook の安全警告を出さない）
    if (-not (Outlook-Open)) {
        Note 'verify 中止（Outlookが開いていない）'
        [IO.File]::WriteAllText((Join-Path $planDir '_確かめた結果.txt'), ((Get-Date -Format 'yyyy-MM-dd HH:mm') + ' 確かめられませんでした：Outlook が開いていません。Outlook を開いてから、もう一度［送ったか確かめる］を押してください'), $utf8bom)
        Alert 'Outlook が開いていません。Outlook を開いてから、もう一度［送ったか確かめる］を押してください。'
        break
    }
    $ol = New-Object -ComObject Outlook.Application; $ns = $ol.GetNamespace('MAPI')
    $since = (Get-Date).AddDays(-45)
    $found = @{}; $outbox = @{}
    function Scan($folder, [bool]$isOutbox) {
        try { $items = $folder.Items } catch { return }
        foreach ($it in $items) {
            try {
                if (-not $isOutbox -and $it.SentOn -lt $since) { continue }
                $cid = $null; $aid = $null
                try { $cid = $it.UserProperties.Find('発注案件ID') } catch {}
                try { $aid = $it.UserProperties.Find('発注相手') } catch {}
                if (-not $cid -or -not $aid) { continue }
                $k = [string]$cid.Value + '|' + [string]$aid.Value
                if ($isOutbox) { $outbox[$k] = $true }
                else { if ($found.ContainsKey($k)) { $found[$k] = [int]$found[$k] + 1 } else { $found[$k] = 1 } }
            } catch {}
        }
    }
    foreach ($st in $ns.Stores) {
        try { Scan $st.GetDefaultFolder(5) $false } catch {}    # 送信済みアイテム
        try { Scan $st.GetDefaultFolder(4) $true } catch {}     # 送信トレイ（滞留＝まだ送れていない）
    }
    # 2026-09-23：戻ってきたメール（配信不能の通知）を受信トレイ・迷惑メールから拾う。**件名だけ**を見る（本文・宛先は読まない＝Outlook の安全警告を避ける）
    #   送ったこと自体は取り消さない。CCの1人だけが戻ることがあるため（9/22・9/23 佐川急便の例）、行には赤い印を付けて人に確かめてもらう
    $bouncePat = @('undeliverable', 'undelivered', 'returned mail', 'returned to sender', 'delivery status notification', 'failure notice', 'mail delivery', 'delivery has failed', 'delivery incomplete', '配信不能', '送信できませんでした', '不達')
    $bounces = @(); $usedB = @{}
    $sinceStr = $since.ToString('yyyy/MM/dd HH:mm')
    foreach ($st in $ns.Stores) {
        foreach ($fid in @(6, 23)) {
            try {
                $its = $st.GetDefaultFolder($fid).Items.Restrict("[ReceivedTime] >= '" + $sinceStr + "'")
                foreach ($it in $its) {
                    $sj = ''; try { $sj = [string]$it.Subject } catch { continue }
                    if (-not $sj) { continue }
                    $low = $sj.ToLower()
                    if (-not (@($bouncePat | Where-Object { $low.Contains($_) }).Count)) { continue }
                    $rt = $null; try { $rt = $it.ReceivedTime } catch {}
                    # 戻りの件名は『Undelivered Mail Returned to Sender』で、元の件名が入らない。
                    #   元のメールは添付として付いており、その**表示名が元の件名**（本文・宛先は読まない＝安全警告を出さない）
                    $titles = @($sj); $atesaki = ''; $riyuu = ''
                    try { $na = [int]$it.Attachments.Count; for ($ai = 1; $ai -le $na; $ai++) {
                        $at = $it.Attachments.Item($ai); $dn = ''; try { $dn = [string]$at.DisplayName } catch {}
                        if (-not $dn) { continue }
                        if ($dn -eq 'details.txt') {
                            $dt = Get-BounceDetail $at
                            if ($dt.宛先) { $atesaki = $dt.宛先 }
                            if ($dt.理由) { $riyuu = $dt.理由 }
                            continue
                        }
                        if ($dn -like '*Message Headers*') {
                            # ヘッダの写しがあるとき＝ここから元の件名と、届かなかった宛先が分かる（いちばん確か）
                            $h = Get-BounceHeader $at
                            if ($h.件名) { $titles += $h.件名 }
                            if ($h.宛先 -and -not $atesaki) { $atesaki = $h.宛先 }   # ヘッダの To は元のあて先ぜんぶ。details.txt で分かったときはそちらが正しい
                            continue
                        }
                        # 元のメールがそのまま添付されているとき＝添付の表示名が元の件名
                        $titles += ($dn -replace '\s*\(\d+(\.\d+)?\s*[KMG]B\)$', '')
                    } } catch {}
                    $bounces += [pscustomobject]@{ 件名 = $sj; 元の件名 = @($titles); 届かなかった宛先 = $atesaki; 理由 = $riyuu; 受信 = $(if ($rt) { $rt.ToString('yyyy-MM-dd HH:mm') } else { '' }); 入った所 = [string]$st.DisplayName }
                }
            } catch {}
        }
    }
    $changed = @()
    # 2026-10-03：件名が短くなった（「発注書」など）ので、同じ件名の行が複数ありうる。件名ごとの行の数を先に数える
    $subjCount = @{}
    foreach ($f0 in (Get-ChildItem $planDir -Filter *.json -ErrorAction SilentlyContinue | Where-Object { $_.BaseName -notlike '_*' })) {
        try { foreach ($c0 in @((Get-Content $f0.FullName -Raw -Encoding UTF8 | ConvertFrom-Json).候補)) { $s0 = [string]$c0.件名; if ($s0) { $subjCount[$s0] = [int]$subjCount[$s0] + 1 } } } catch {}
    }
    foreach ($f in (Get-ChildItem $planDir -Filter *.json -ErrorAction SilentlyContinue | Where-Object { $_.BaseName -notlike '_*' })) {
        # 2026-09-26：1件が書きかけでも、残りの確かめを止めない（この回だけ飛ばす）
        $L2 = $null
        for ($try = 1; $try -le 3; $try++) {
            try { $L2 = @{ Path = $f.FullName; Doc = (Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json) }; break }
            catch { Start-Sleep -Milliseconds 700 }
        }
        if (-not $L2) { $changed += "$($f.BaseName)：台帳が読めなかったので飛ばしました（次の回で確かめます）"; continue }
        $id = [string]$L2.Doc.案件ID; $touched = $false
        foreach ($c2 in @($L2.Doc.候補)) {
            if ($c2.方法 -in @('電話メモ', '倉庫出し')) { continue }
            $k = $id + '|' + [string]$c2.相手
            # 戻ってきたメールの照合。状態は変えない（送った事実は消さない）。印だけ付けて、宛先を確かめてもらう
            $mySub = [string]$c2.件名
            $hit = $null
            $myTo = ([string]$c2.宛先).ToLower()
            if ($mySub) {
                $candB = @($bounces | Where-Object { @($_.元の件名 | Where-Object { $_ -and $_.Contains($mySub) }).Count })
                # 2026-10-03：届かなかった宛先が分かる戻りは、宛先で当てる（短い件名は同じ日の別の発注と同じになる）
                $hit = @($candB | Where-Object { $myTo -and ([string]$_.届かなかった宛先).ToLower().Contains($myTo) }) | Select-Object -First 1
                # 宛先が分からない戻り・CCの1人だけが戻った戻りは、同じ件名の行がこの1行だけのときに限って当てる（当たらなければ画面の上に出る）
                if (-not $hit -and [int]$subjCount[$mySub] -eq 1) { $hit = $candB | Select-Object -First 1 }
            }
            if ($hit) {
                $usedB[$hit.受信 + '|' + $hit.入った所] = $true
                if (-not $c2.戻り -or [string]$c2.戻り.受信 -ne [string]$hit.受信) {
                    $c2 | Add-Member -NotePropertyName 戻り -NotePropertyValue $hit -Force
                    $touched = $true; $changed += "$id $($c2.相手)：⚠メールが戻ってきています（$($hit.受信)）"
                }
            } elseif ($c2.戻り) { $c2 | Add-Member -NotePropertyName 戻り -NotePropertyValue $null -Force; $touched = $true }
            if ($outbox.ContainsKey($k)) {
                if ($c2.状態 -ne '送信トレイで止まっています') { $c2.状態 = '送信トレイで止まっています'; $c2.日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm'); $touched = $true; $changed += "$id $($c2.相手)：送信トレイで止まっている" }
                continue
            }
            if (-not $found.ContainsKey($k)) {
                # 2026-09-23 点検役 H9：送信済みにも送信トレイにも無いのに、下書きも消えている＝未達の穴。
                #   熊田さんは「下書き済」のまま止まり、誰も気づかない。ここで拾って人に確かめてもらう
                if ([string]$c2.状態 -eq '下書き済' -and $c2.EntryID) {
                    $ikiteru = $false
                    try { $null = (Outlook-Item $c2.EntryID $c2.StoreID).Subject; $ikiteru = $true } catch {}
                    if (-not $ikiteru) {
                        if ($c2.状態 -ne '送ったか確かめて') { $c2.状態 = '送ったか確かめて'; $c2.日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm'); $touched = $true; $changed += "$id $($c2.相手)：下書きが消えていて、送信済みにも見当たりません（確かめてください）" }
                    }
                }
                continue
            }
            $n = [int]$found[$k]
            # 2026-09-23 点検役 2-①：人が一度「確かめた」通数は覚えておき、増えた時だけ赤にする。
            #   これが無いと、正しく差し替えを送った行が verify のたびに赤に戻り、赤の信用が落ちる（＝本物の二重を見過ごす）
            if ([int]$c2.見つけた通数 -ne $n) { $c2 | Add-Member -NotePropertyName 見つけた通数 -NotePropertyValue $n -Force; $touched = $true }
            $sumi = [int]$c2.確かめた通数
            $furui = @(@($c2.旧下書き) | Where-Object { $_ -and -not $_.印済み }).Count   # 人がまだ確かめていない古い下書きだけ
            if ($n -ge 2 -and $n -gt $sumi) { if ($c2.状態 -ne '⚠二重に送っています') { $c2.状態 = '⚠二重に送っています'; $c2.日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm'); $touched = $true; $changed += "$id $($c2.相手)：送信済みに $n 通（二重）" } }
            elseif ($furui) {
                # 中身が変わって候補に戻った行。送信済みに残る1通は「古い中身」なので「送った」にしない
                if ($c2.状態 -ne '⚠古い中身で送っています') { $c2.状態 = '⚠古い中身で送っています'; $c2.日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm'); $touched = $true; $changed += "$id $($c2.相手)：古い中身で送っている（新しい数量で出し直しが要る）" }
            }
            elseif ($c2.状態 -ne '送った' -and $DONE -notcontains [string]$c2.状態) { $c2.状態 = '送った'; $c2.日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm'); $touched = $true; $changed += "$id $($c2.相手)：送信済みで確認→送った"; Add-OkuttaKiroku $id ([string]$c2.相手) '送った（確かめて）' ([string]$c2.件名) }
        }
        if ($touched) { Save-Ledger $L2 }
    }
    # どの発注のものか分からなかった戻り（件名が合わない通知）は、件数と件名を画面の上に出す
    $nokori = @($bounces | Where-Object { -not $usedB.ContainsKey($_.受信 + '|' + $_.入った所) } | ForEach-Object {
        $moto = @($_.元の件名 | Where-Object { $_ -and $_ -ne $_.件名 }) | Select-Object -Last 1
        [pscustomobject]@{ 件名 = $(if ($moto) { [string]$moto } else { [string]$_.件名 }); 届かなかった宛先 = [string]$_.届かなかった宛先; 理由 = [string]$_.理由; 受信 = $_.受信; 入った所 = $_.入った所 } })
    $mp = Join-Path $planDir '_戻ってきたメール.json'
    [IO.File]::WriteAllText($mp, (@{ 確かめた日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm'); 行 = @($nokori) } | ConvertTo-Json -Depth 5), $utf8bom)
    if (@($nokori).Count) { $changed += "⚠どの発注か分からない戻りが $(@($nokori).Count) 通あります（受信トレイを見てください）" }
    if ($changed.Count) { Note ('verify: ' + ($changed -join ' / ')) } else { Note 'verify: 変わりなし' }
    # 結果を画面に出すためファイルへ（board_build が上に出す）
    $vp = Join-Path $planDir '_確かめた結果.txt'
    [IO.File]::WriteAllText($vp, ((Get-Date -Format 'yyyy-MM-dd HH:mm') + " 確かめました：" + $(if ($changed.Count) { ($changed -join ' ／ ') } else { '変わりはありません' })), $utf8bom)
  }
  'verifycopy' {
    # 2026-10-23 穴A：実物と台帳の中身の比べ方＝行ごとに最後の量（数＋単位・㎏→kg・ケース→c/s）と行の数だけ比べる。品名の書き方の違い（「わさび昆布 2c/s（発注書PDF）」と「わさび昆布 1kg×12 2c/s」）は同じと読む
    function Same-Nakami([string]$a, [string]$b) {
        function Q([string]$s) { $out = @(); foreach ($pt in ($s -split '／')) { $t = $pt.Trim(); if (-not $t) { continue }; $ms = [regex]::Matches($t, '(\d+(?:\.\d+)?)\s*(c/s|ｃ/ｓ|ケース|㎏|kg|k|袋|枚|本|個)'); if ($ms.Count) { $m1 = $ms[$ms.Count - 1]; $u = (([string]$m1.Groups[2].Value) -replace '㎏', 'kg' -replace 'ケース', 'c/s' -replace 'ｃ/ｓ', 'c/s'); if ($u -eq 'k') { $u = 'kg' }; $out += ([string]$m1.Groups[1].Value + $u) } else { $out += '?' } }; return ($out -join '|') }
        return ((Q $a) -eq (Q $b))
    }
    # 2026-10-03 玉井さん「送信したら自動で完了。［送った］［送ったか確かめる］を押す必要はない」。
    #   熊田さんのPCから送ったメール（CC に info@）と eFax（送信元 info@）は、倉庫メインPCの info@ の箱に写しが届く。
    #   その写しを 宛先＋納品希望日＋会場 で照合して、下書き済の行を「送った」にする。件名は人が直すので見ない。
    #   熊田さんのPCの送信済みに目印（UserProperties）が残るかは未確認（IMAP の箱）。こちらを本筋にする。
    #   定期実行から呼ぶので画面（Alert）は出さない。本文・宛先を読む＝倉庫メインPCでは安全警告が出ないことを 10/3 に確かめた
    # 2026-10-08 担当者がAIかおりで押した［倉庫から持っていった］を先に当てる（Outlook が閉じていても動く）
    try { $env:HACCHU_NO_ALERT = '1'; & $PSCommandPath -Action mottekitta -Config $Config | Out-Null } catch { Note "mottekitta 失敗 $($_.Exception.Message)" } finally { $env:HACCHU_NO_ALERT = '' }
    if (-not (Get-Process OUTLOOK -ErrorAction SilentlyContinue)) { Note 'verifycopy 中止（Outlookが起動していない）'; break }
    # 2026-10-13 相手先の返事（出荷日・欠品・遅れ・FAXの成否）も同じ回で読む（aite_henji.py・読むだけ）。返事が変わった時だけボードを書き直す
    if (-not $DryRun) {
        try {
            $ahOut = Join-Path $planDir '_相手の返事.json'
            $ah0 = $(if (Test-Path $ahOut) { (Get-Item $ahOut).LastWriteTime } else { $null })
            $ahMsg = (& python -X utf8 (Join-Path $PSScriptRoot 'aite_henji.py') 2>&1 | Select-Object -First 1)
            $ah1 = $(if (Test-Path $ahOut) { (Get-Item $ahOut).LastWriteTime } else { $null })
            if ($ah1 -and $ah1 -ne $ah0) {
                Note ('aite_henji: ' + [string]$ahMsg)
                try { & (Join-Path $PSScriptRoot 'board_build.ps1') -Config (Join-Path $PSScriptRoot 'board_config.json') | Out-Null } catch { Note "aite_henji：ボードの書き直しに失敗 $($_.Exception.Message)" }
            }
        } catch { Note "aite_henji 失敗 $($_.Exception.Message)" }
    }
    # 2026-10-16 メール移行 B2：写しの箱を並びにできる（CopyStores）。無ければ CopyStore（1つ）→ 既定 info@gokaku.company
    $csList = $(if ($cfg.CopyStores) { @($cfg.CopyStores | ForEach-Object { [string]$_ }) } elseif ($cfg.CopyStore) { @([string]$cfg.CopyStore) } else { @('info@gokaku.company') })
    # B1：受信トレイも見る（co.jp から送った写しは かおりん へ振り分けられない）。取引先の返信は下の宛先の照合で元から外れる
    $cfNames = $(if ($cfg.CopyFolders) { @($cfg.CopyFolders) } else { @('かおりん', '送信記録', '送信済みアイテム') })
    # 1) 確かめる行を集める（下書き済・送ったか確かめて の メール／FAX／新木さん）
    $rows = @()
    foreach ($f in (Get-ChildItem $planDir -Filter *.json -ErrorAction SilentlyContinue | Where-Object { $_.BaseName -notlike '_*' })) {
        $L3 = $null
        for ($try = 1; $try -le 3; $try++) { try { $L3 = @{ Path = $f.FullName; Doc = (Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json) }; break } catch { Start-Sleep -Milliseconds 700 } }
        if (-not $L3) { Note "verifycopy：台帳が読めず飛ばした $($f.BaseName)"; continue }
        $nd = [string]$L3.Doc.納品.納品希望日
        $vk = ([string]$L3.Doc.納品.会場) -replace '\s', ''
        if ($vk.Length -gt 15) { $vk = $vk.Substring(0, 15) }
        foreach ($c3 in @($L3.Doc.候補)) {
            if ($c3.方法 -notin @('メール', 'FAX', '新木さん')) { continue }
            # 2026-10-08 穴10：ボードの下書きを使わず手で送った分（状態は「候補」のまま）も、写しが届いていれば「送った」にする。
            #   照合は同じ（宛先＋納品希望日＋会場）。下書きが無いので、ボードが作った件名・中身とは比べない＝写しの「手で送った」の印を残す
            if ([string]$c3.状態 -notin @('下書き済', '送ったか確かめて', '候補')) { continue }
            if (-not [string]$c3.宛先 -or -not $nd -or -not $vk) { continue }
            $rows += [pscustomobject]@{ L = $L3; C = $c3; To = ([string]$c3.宛先).ToLower(); Date = $nd; Venue = $vk }
        }
    }
    if (-not $rows.Count) { Note 'verifycopy: 確かめる行なし'; break }
    $wantTo = @($rows | ForEach-Object { $_.To } | Select-Object -Unique)
    # 2) 写しを集める（宛先が確かめる行のどれかに当たるものだけ本文を読む）
    $ol = New-Object -ComObject Outlook.Application; $ns = $ol.GetNamespace('MAPI')
    # 同じ名前の箱が2つある PC がある（キャンセルした追加の残り）＝名前の当たる箱は全部読む。同じ1通は下の 3) で送信秒で1通に畳む
    $csStores = @()
    foreach ($csn in $csList) {
        $hitS = @(foreach ($st in $ns.Stores) { if ([string]$st.DisplayName -eq $csn) { $st } })
        if ($hitS.Count) { $csStores += $hitS; continue }
        Note "verifycopy：写しの箱 $csn が無い"
        # 静かに空振りさせない＝困りごとに1行（同じ鍵の「未」があれば日時だけ直る）
        if (-not $DryRun) { Add-Komarigoto '写しの箱が無い' '' $csn ('［送ったか確かめる］が読む箱 ' + $csn + ' が、このPC（' + $env:COMPUTERNAME + '）の Outlook に無い。この箱からの写しは「送った」にならない') }
    }
    if (-not $csStores.Count) { Note "verifycopy 中止（写しの箱が1つも無い：$($csList -join '・')）"; break }
    $sinceStr = (Get-Date).AddDays(-45).ToString('yyyy/MM/dd HH:mm')
    $copies = @()
    function WalkF($fd) { $fd; foreach ($ch in $fd.Folders) { WalkF $ch } }
    foreach ($fd in @(foreach ($store in $csStores) { WalkF $store.GetRootFolder() })) {
        if ($cfNames -notcontains [string]$fd.Name) { continue }
        $its = $null; try { $its = $fd.Items.Restrict("[ReceivedTime] >= '" + $sinceStr + "'") } catch { continue }
        foreach ($it in $its) {
            try {
                if ($it.Class -ne 43) { continue }
                $to = ([string]$it.To).ToLower()
                try { foreach ($r in $it.Recipients) { if ($r.Type -eq 1) { $to += ';' + ([string]$r.Address).ToLower() } } } catch {}
                if (-not @($wantTo | Where-Object { $to.Contains($_) }).Count) { continue }
                $so = $null; try { $so = [datetime]$it.SentOn } catch {}
                # 2026-10-07 ヒロツクは本文なし＝発注書PDFのファイル名（納品日・会場入り）も本文と同じに見る
                $atn = ''; try { foreach ($at in $it.Attachments) { $atn += '|' + [string]$at.FileName } } catch {}
                $copies += [pscustomobject]@{ To = $to; Body = ((([string]$it.Body) + $atn) -replace '[\s\\/:\*\?"<>\|]', ''); Raw = [string]$it.Body; Sent = $so; Folder = [string]$fd.Name }   # 2026-10-23 穴A：本文そのもの（Raw）も持つ＝送った時の中身を実物から写す
            } catch {}
        }
    }
    # 3) 照合して状態を変える
    $changed = @(); $touchedL = @{}
    foreach ($w in $rows) {
        $c3 = $w.C
        $lo = (Get-Date).AddDays(-45); try { if ([string]$c3.日時) { $lo = ([datetime][string]$c3.日時).AddDays(-7) } } catch {}
        $wd = ($w.Date -replace '/', ''); $wd2 = ''; try { $wd2 = ([datetime]$w.Date).ToString('yyyy-MM-dd') } catch {}
        $wv = ($w.Venue -replace '[\s\\/:\*\?"<>\|]', '')
        $m = @($copies | Where-Object { $_.To.Contains($w.To) -and ($_.Body.Contains($wd) -or ($wd2 -and $_.Body.Contains($wd2))) -and $_.Body.Contains($wv) -and (-not $_.Sent -or $_.Sent -ge $lo) })
        # 2026-10-12 頼み直しの便は宛先・納品日・会場が元の便と同じ＝本文の「頼み直し」の字で分ける（make_order_drafts の $yariMark）。元の便の行は頼み直しの写しを数えない
        # 2026-10-23 24代目ボスの裁定：頭の文は「（頼み直し）」（取消の記録あり）と「（追加）」（取消の記録の無い追加）の2つ＝目印は両方を読む（make_order_drafts の $yariMarkTorikeshi・$yariMarkTsuika）
        if (([string]$c3.相手).EndsWith('〈頼み直し〉')) { $m = @($m | Where-Object { $_.Body.Contains('頼み直し') -or $_.Body.Contains('（追加）') }) } else { $m = @($m | Where-Object { -not ($_.Body.Contains('頼み直し') -or $_.Body.Contains('（追加）')) }) }
        if (-not $m.Count) { continue }
        # 同じ1通が「かおりん」と「送信済み」の両方にあることがある＝送った時刻（秒）で数える
        $n = @($m | ForEach-Object { if ($_.Sent) { $_.Sent.ToString('yyyyMMddHHmmss') } else { 'x' } } | Select-Object -Unique).Count
        $id3 = [string]$w.L.Doc.案件ID
        $sentAt = (@($m | Where-Object { $_.Sent } | Sort-Object Sent | ForEach-Object { $_.Sent.ToString('M/d HH:mm') }) -join '・')
        $c3 | Add-Member -NotePropertyName 見つけた通数 -NotePropertyValue $n -Force
        if ($n -ge 2 -and $n -gt [int]$c3.確かめた通数) {
            $c3.状態 = '⚠二重に送っています'; $changed += "$id3 $($c3.相手)：写しが $n 通（$sentAt）＝二重"
        } else {
            $tede = ([string]$c3.状態 -eq '候補')
            $c3.状態 = '送った'; $changed += "$id3 $($c3.相手)：写しで確認→送った（$sentAt）" + $(if ($tede) { '・手で送った分' } else { '' })
            if ($tede) { $c3 | Add-Member -NotePropertyName 手で送った -NotePropertyValue $true -Force }
            # 2026-10-23 穴A（ボス 10/16 22:51 の依頼・玉井さん「1」・24代目ボスの裁定 10/23 17時台）：送った時の中身を、写し（実物のメール本文）の「・」で始まる行から写す。
            #   台帳の中身・中身全文は書き換えない（★10/11）。送った時の台帳の中身を控え、実物と違えば「手で直して送った」（注・⚠ではない）。
            #   PDF だけの便（ヒロツク＝本文に品の行なし）は送った時の中身を空のまま＝読み手（process_budget_files）は台帳の数を出し注「PDFで送った」。読み手の規則は process_budget_files の「送った中身の読み」1か所
            try {
                $mBest = @($m | Sort-Object Sent | Select-Object -Last 1)[0]
                $jLines = @(([string]$mBest.Raw -split "`r?`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[・･]' } | ForEach-Object { ($_ -replace '^[・･]\s*', '') -replace '\s{2,}', ' ' })
                $daicho3 = $(if ([string]$c3.中身全文) { [string]$c3.中身全文 } else { [string]$c3.中身 })
                $c3 | Add-Member -NotePropertyName 送った時の台帳の中身 -NotePropertyValue $daicho3 -Force
                if ($mBest.Sent) { $c3 | Add-Member -NotePropertyName 実際に送った日時 -NotePropertyValue $mBest.Sent.ToString('yyyy-MM-dd HH:mm') -Force }
                if ($jLines.Count) {
                    $jitsu3 = ($jLines -join '／')
                    $c3 | Add-Member -NotePropertyName 送った時の中身 -NotePropertyValue $jitsu3 -Force
                    $c3 | Add-Member -NotePropertyName 送った時の中身の出どころ -NotePropertyValue '実物のメール' -Force
                    $c3 | Add-Member -NotePropertyName 手で直して送った -NotePropertyValue (-not (Same-Nakami $jitsu3 $daicho3)) -Force
                } else {
                    $c3 | Add-Member -NotePropertyName 送った時の中身 -NotePropertyValue '' -Force
                    $c3 | Add-Member -NotePropertyName 送った時の中身の出どころ -NotePropertyValue 'PDFで送った（本文に品の行なし）' -Force
                    $c3 | Add-Member -NotePropertyName 手で直して送った -NotePropertyValue $false -Force
                }
            } catch { Note "送った時の中身を写せず $id3 $($c3.相手)：$($_.Exception.Message)" }
            if (-not $DryRun) { Add-OkuttaKiroku $id3 ([string]$c3.相手) $(if ($tede) { '送った（手で送った写しで確かめた）' } else { '送った（写しで確かめた）' }) ([string]$c3.件名) }
        }
        $c3.日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm')
        $touchedL[$w.L.Path] = $w.L
    }
    if ($DryRun) { "DRYRUN 行=$($rows.Count) 写し=$($copies.Count)"; $changed; break }
    foreach ($k in $touchedL.Keys) { Save-Ledger $touchedL[$k] }
    if ($changed.Count) {
        Note ('verifycopy: ' + ($changed -join ' / '))
        [IO.File]::WriteAllText((Join-Path $planDir '_確かめた結果.txt'), ((Get-Date -Format 'yyyy-MM-dd HH:mm') + " 自動で確かめました：" + ($changed -join ' ／ ')), $utf8bom)
        # 熊田さんのPCが開くボードを書き直す（board_config.json＝熊田さんのPCの設定）
        try { & (Join-Path $PSScriptRoot 'board_build.ps1') -Config (Join-Path $PSScriptRoot 'board_config.json') | Out-Null } catch { Note "verifycopy：ボードの書き直しに失敗 $($_.Exception.Message)" }
    } else { Note "verifycopy: 変わりなし（行 $($rows.Count)・写し $($copies.Count)）" }
  }
  'naoshi' {
    # 2026-10-07 玉井さん「発注の予定＝鍵のかかった箱」。鍵を持つPCの窓から、送る前の発注を足す・量を変える・外す／もう頼んである分を記録する。
    #   1直し＝1ファイル（発注案\予定の直し\〈案件ID〉_〈時刻〉_〈PC〉.json・点検役(5)）。台帳は process_budget_files が作り直す（指紋にこのファイルが入る・点検役(3)）。
    #   行の形は 確認\〈案件ID〉.json の候補の品目と同じ（点検役(2)）。当てる順は make_order_drafts の中（担当者の修正→直し→供給上限・点検役(1)）
    $kagi = Read-Kagi
    if (-not $kagi) { Alert "このPCには、発注の予定を直す鍵がありません。`r`n鍵のあるPC＝熊田さんのPC（倉庫サブPC）・倉庫メインPC・自宅メインPC（玉井さん 10/7）。`r`n鍵を置くには、そのPCで 仕組み\鍵を置く.ps1 を動かします。"; Note "naoshi 中止（鍵なし）$caseId"; break }
    $row = $null; try { $row = (FromHex $RowHex) | ConvertFrom-Json } catch {}
    if (-not $row) { Alert '直しの中身が読めませんでした。窓を閉じて、もう一度開いてください。'; Note "naoshi 中止（RowHexが読めない）$caseId"; break }
    $shubetsu = [string]$row.種別; $gyo = $row.行; $moto = [string]$row.何をもとに; $memo = [string]$row.メモ
    if ($shubetsu -notin @('これから頼む', 'もう頼んである', '頼んだ分を減らした')) { Alert ('種別がおかしいです：' + $shubetsu); Note "naoshi 中止（種別）$caseId $shubetsu"; break }
    if ($NAOSHI_MOTO -notcontains $moto) { Alert '「何をもとに」を1つ選んでください。'; Note "naoshi 中止（何をもとに が無い）$caseId"; break }
    if (-not $gyo) { Alert '直す行がありません。'; break }
    $cd = [string]$gyo.品目コード; $hito = ($gyo.人が読む -eq $true); $ji = [string]$gyo.本文の字; $saki = [string]$gyo.頼む先
    if (-not $cd -and -not ($hito -and $ji)) { Alert '品を選ぶか、一覧に無い品は字で書いてください。'; break }
    if (-not $saki) { Alert '頼む先を選んでください。'; break }
    $cs = $null; try { $cs = [double]([string]$gyo.ケース) } catch {}
    if (-not $hito -and $null -eq $cs) { Alert 'ケースの数が読めません。'; break }
    # 2026-10-08 穴23：減らした記録は一覧の品だけ・1ケース以上（字の行や0は、何をどれだけ減らしたか分からない）
    if ($shubetsu -eq '頼んだ分を減らした' -and ($hito -or -not $cd -or $cs -le 0)) { Alert '減らした記録は、一覧の品を選び、減らしたケースの数を＋で入れてください。'; Note "naoshi 中止（減らした・品か量なし）$caseId"; break }
    $L = Load-Ledger $caseId; $d = $L.Doc
    if ($d.対象外 -eq $true) { Alert ('この催事は仕組みの対象外です（' + [string]$d.対象外の理由 + '）。別の経路で頼んでいる間は、ここでは直せません。'); Note "naoshi 中止（対象外）$caseId"; break }
    # 2026-10-09 マニュアル係⑨：送った後の取消は、スマホ（LINEの［取消］→［応じた］）と、この窓の2つの道から入る＝同じ取消が2回引かれ得た。
    #   同じ品・同じ相手の「頼んだ分を減らした」が生きていれば止める。本当に2回目の取消なら、メモの頭に「2回目」と書けば通す
    if ($shubetsu -eq '頼んだ分を減らした' -and -not $memo.StartsWith('2回目')) {
        $ndir0 = Join-Path $planDir '予定の直し'; $dead0 = @{}; $live0 = @()
        foreach ($nf in @(Get-ChildItem $ndir0 -Filter ($caseId + '_*.json') -ErrorAction SilentlyContinue)) {
            try { $nj0 = Get-Content $nf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
            if ([string]$nj0.種別 -eq '取り消し' -and [string]$nj0.取り消すファイル) { $dead0[[string]$nj0.取り消すファイル] = $true }
            elseif ([string]$nj0.種別 -eq '頼んだ分を減らした') { $live0 += [pscustomobject]@{ F = $nf.Name; J = $nj0 } }
        }
        $c4n = $(if ($cd.Length -ge 4) { $cd.Substring(0, 4) } else { $cd })
        $dup0 = $live0 | Where-Object { -not $dead0.ContainsKey($_.F) -and ([string]$_.J.行.品目コード).StartsWith($c4n) -and [string]$_.J.行.頼む先 -eq $saki } | Select-Object -First 1
        if ($dup0) { Alert ("この品は、もう「頼んだ分を減らした」で記録されています（" + [string]$dup0.J.いつ + "・" + [string]$dup0.J.誰が + "・" + [string]$dup0.J.行.ケース + "c/s）。`r`n同じ取消なら、ここで入れる必要はありません（台帳の量はもう減っています）。`r`n`r`n別の取消（2回目）のときだけ、メモの頭に「2回目」と書いて、もう一度押してください。"); Note "naoshi 中止（減らした・二重の恐れ）$caseId $cd $saki"; break }
    }
    $target = $d.候補 | Where-Object { [string]$_.相手 -eq $saki -and $_.候補外 -ne $true } | Select-Object -First 1
    # 2026-10-12 頼み直し（11代目ボスの裁定）：もう送った相手（全部取り消して候補外になった相手を含む）に、あらためて頼む＝新しい便「〈相手〉〈頼み直し〉」
    #   窓は送った相手を選ぶと頼む先の名前の後ろに〈頼み直し〉を付けて渡す。元の相手が送った後であること・頼み直しの便がまだ送っていないことだけ確かめる
    if ($shubetsu -eq 'これから頼む' -and $saki.EndsWith('〈頼み直し〉')) {
        $base0 = $saki -replace '〈頼み直し〉$', ''
        $bt0 = $d.候補 | Where-Object { [string]$_.相手 -eq $base0 } | Select-Object -First 1
        if (-not $bt0 -or [string]$bt0.状態 -notmatch '^(送った|電話した)') { Alert ('頼み直しは、もう送った相手にだけ使えます（「' + $base0 + '」は ' + $(if ($bt0) { [string]$bt0.状態 } else { 'この催事の相手にありません' }) + '）。'); Note "naoshi 中止（頼み直しの元が送った後でない）$caseId $saki"; break }
        if ($target -and [string]$target.状態 -notin @('候補', '下書き済')) { Alert ('「' + $saki + '」の便も、もう送っています（' + [string]$target.状態 + '）。' + "`r`n" + 'その後の分は、相手にメールか電話で伝えて「もう頼んである（記録だけ）」で入れてください。'); Note "naoshi 中止（頼み直しも送った後）$caseId $saki"; break }
    } elseif ($shubetsu -eq 'これから頼む') {
        # 点検役(4)：直せるのは「候補」「下書き済」だけ。送った後の相手は、相手に伝えてから「もう頼んである」で記録する
        if ($saki -ne '倉庫出し') {
            if (-not $target) { Alert ('頼む先「' + $saki + '」は、この催事の発注の相手にありません。相手の一覧から選んでください。'); Note "naoshi 中止（頼む先が候補にない）$caseId $saki"; break }
            if ([string]$target.状態 -notin @('候補', '下書き済')) { Alert ('「' + $saki + '」には、もう送っています（' + [string]$target.状態 + '）。' + "`r`n" + '送った後の変更は、相手にメールか電話で伝えてください。' + "`r`n" + 'その分は「もう頼んである（記録だけ）」で入れると、台帳の量に残ります。'); Note "naoshi 中止（送った後）$caseId $saki $($target.状態)"; break }
        } elseif ($target -and [string]$target.状態 -eq '倉庫から出した') { Alert '倉庫出しは、もう出しています。出した後の分は「もう頼んである（記録だけ）」で入れてください。'; Note "naoshi 中止（倉庫から出した後）$caseId"; break }
    }
    # 2026-10-08 穴7：「誰が」＝鍵の持ち主（PCの持ち主）ではなく、直している人。倉庫メインPCの鍵は玉井さん名義でも、熊田さんが押すことがある。
    #   順＝ブラウザ版の押した人（合言葉で分かる）→ 窓の⑦で選んだ人 → 鍵の持ち主（⑦の無い古い窓から押された時だけ）
    $dare = $(if ($env:HACCHU_WHO) { $env:HACCHU_WHO } elseif ([string]$row.誰が -in @('熊田さん', '玉井さん')) { [string]$row.誰が } else { [string]$kagi.持ち主 })
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $naoshiDir = Join-Path $planDir '予定の直し'; New-Item -ItemType Directory -Force $naoshiDir | Out-Null
    $fname = ($caseId + '_' + $stamp + '_' + $env:COMPUTERNAME + '.json')
    $doc = [ordered]@{ schema = 1; 案件ID = $caseId; 種別 = $shubetsu
        行 = [ordered]@{ 品目コード = $cd; 商品 = [string]$gyo.商品; 発注量kg = [string]$gyo.発注量kg; ケース = [string]$gyo.ケース; 人が読む = $hito; 本文の字 = $ji; 頼む先 = $saki; 注意 = [string]$gyo.注意 }
        何をもとに = $moto; メモ = $memo; 誰が = $dare; PC = $(if ($env:HACCHU_WHO) { 'ブラウザ' } else { [string]$kagi.PC }); ホスト名 = $env:COMPUTERNAME; いつ = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz') }
    [IO.File]::WriteAllText((Join-Path $naoshiDir $fname), ($doc | ConvertTo-Json -Depth 5), $utf8bom)
    Note ("naoshi 書いた $fname 種別=$shubetsu 品=$cd/$ji ケース=$([string]$gyo.ケース) 頼む先=$saki もとに=$moto 誰が=$dare")
    # 点検役(4)：下書き済の相手を直したら、既存の mark 候補 を呼び、古い下書きに【旧】を付ける（消さない）
    if ($shubetsu -eq 'これから頼む' -and $target -and [string]$target.状態 -eq '下書き済') {
        $eid0 = [string]$target.EntryID; $sid0 = [string]$target.StoreID
        try { & $PSCommandPath -Action mark -CaseHex $CaseHex -AiteHex (ToHex $saki) -StateHex (ToHex '候補') -Config $Config | Out-Null } catch { Note "naoshi：mark 候補 に失敗 $saki : $($_.Exception.Message)" }
        if ($eid0) { try { $it = Outlook-Item $eid0 $sid0; if (-not $it.Subject.StartsWith('【旧】')) { $it.Subject = '【旧】' + $it.Subject; $it.Save() }; Note "naoshi：旧下書きに【旧】を付けた $saki" } catch { Note "naoshi：【旧】を付けられず（Outlookが閉じている・下書きが無い）$saki : $($_.Exception.Message)" } }
    }
    # 台帳を作り直す（指紋に直しのファイルが入っているので、この催事だけ作り直される）
    $prm = @{ Account = [string]$cfg.Account }; if ($cfg.Test -eq $true) { $prm.Test = $true }
    $r = & (Join-Path $PSScriptRoot 'process_budget_files.ps1') @prm
    Note ("naoshi refresh: " + (($r | Select-Object -First 3) -join ' / '))
    # 反映できなかったら、その場で知らせる（台帳の 予定の直し.状態）
    try { $L2 = Load-Ledger $caseId; $nd = $L2.Doc.予定の直し; if ([string]$nd.状態 -eq '反映できない') { Add-Komarigoto '予定の直しを反映できない' $caseId '' ((@($nd.できない理由) | Select-Object -First 3) -join ' / '); Alert ("直しは記録しましたが、下書きには反映できませんでした。`r`n`r`n" + ((@($nd.できない理由) | Select-Object -First 3) -join "`r`n") + "`r`n`r`n仕組みの側で止まっています。熊田さんが直す必要はありません。`r`nボードのいちばん上の「仕組みの困りごと」に自動で載りました（玉井さんも同じ画面で見ます）。`r`n熊田さんがすること：急ぐときは、いま押した直しを窓の一覧で［取り消す］と、直す前の下書きが作れます（その後は相手にメールか電話で直した数を伝えてください）。急がないときは待つだけです。") } } catch {}
  }
  'naoshicancel' {
    # 2026-10-07 直しの取り消し。元のファイルは消さず、種別「取り消し」のファイルを足す（消えない記録・点検役(5)）
    $kagi = Read-Kagi
    if (-not $kagi) { Alert "このPCには、発注の予定を直す鍵がありません。"; Note "naoshicancel 中止（鍵なし）$caseId"; break }
    $fn = FromHex $FileHex
    $naoshiDir = Join-Path $planDir '予定の直し'
    if (-not $fn -or $fn.Contains('\') -or $fn.Contains('/') -or -not $fn.StartsWith($caseId + '_') -or -not (Test-Path (Join-Path $naoshiDir $fn))) { Alert ('取り消す直しが見つかりません：' + $fn); Note "naoshicancel 中止（ファイルなし）$caseId $fn"; break }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $doc = [ordered]@{ schema = 1; 案件ID = $caseId; 種別 = '取り消し'; 取り消すファイル = $fn; 何をもとに = ''; メモ = ''; 誰が = $(if ($env:HACCHU_WHO) { $env:HACCHU_WHO } else { [string]$kagi.持ち主 }); PC = $(if ($env:HACCHU_WHO) { 'ブラウザ' } else { [string]$kagi.PC }); ホスト名 = $env:COMPUTERNAME; いつ = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz') }
    [IO.File]::WriteAllText((Join-Path $naoshiDir ($caseId + '_' + $stamp + '_' + $env:COMPUTERNAME + '.json')), ($doc | ConvertTo-Json -Depth 5), $utf8bom)
    Note "naoshicancel 取り消した $fn（$($kagi.持ち主)）"
    $prm = @{ Account = [string]$cfg.Account }; if ($cfg.Test -eq $true) { $prm.Test = $true }
    $r = & (Join-Path $PSScriptRoot 'process_budget_files.ps1') @prm
    Note ("naoshicancel refresh: " + (($r | Select-Object -First 3) -join ' / '))
  }
  'refresh' {
    $prm = @{ Account = [string]$cfg.Account }
    if ($cfg.Test -eq $true) { $prm.Test = $true }
    $r = & (Join-Path $PSScriptRoot 'process_budget_files.ps1') @prm
    Note ("refresh: " + (($r | Select-Object -First 3) -join ' / '))
  }
  'lineok' {
    # 2026-09-23 点検役：LINEの依頼の帯を消す手段が無かった。人が「先に送っていないか確かめた」と押したら、その依頼を畳む。
    #   消すのではなく「確かめた」の記録を足すだけ（後から誰がいつ確かめたか分かる）
    $kagi = $caseId   # ここには「日時|会場」が入っている
    $okPath = Join-Path $planDir '_LINE依頼の確認済み.json'
    $ok = $null; if (Test-Path $okPath) { try { $ok = Get-Content $okPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {} }
    $rows = @(); if ($ok) { $rows = @(@($ok.確認済み) | Where-Object { $_ -and $_.鍵 }) }
    if (-not (@($rows | Where-Object { [string]$_.鍵 -eq $kagi }).Count)) {
        $rows += [pscustomobject]@{ 鍵 = $kagi; 確かめた日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm') }
    }
    # 2026-10-23 b6②（玉井さんのハンコ 10/22）：鍵が「FAX外|〈送信完了の鍵〉|〈案件ID〉|〈相手〉」の物＝熊田さんが「この手送りFAXはこの行の分ではない」と押した記録（board_build がその組を二度と出さない）
    # 2026-10-23 穴A（24代目ボスの裁定）：鍵が「送った中身|〈案件ID〉|〈相手〉|メール／ボード」の物＝熊田さんが「仕入先に届いているのは送ったメールの数／発注ボードの数」と押した記録。読むのは process_budget_files（送った中身の読み）
    [IO.File]::WriteAllText($okPath, (@{ 説明 = 'LINEの依頼のうち、人が「先に送っていないか確かめた」もの。発注ボードの帯から畳むために使う。鍵が「FAX外|」で始まる物は、手で送ったFAXを「この行の分ではない」と押した記録（2026-10-23 b6）'; 確認済み = @($rows) } | ConvertTo-Json -Depth 5), $utf8bom)
    Note "LINEの依頼を確かめた：$kagi"
  }
  'okcheck' {
    # 2026-09-28：数量限定などで「送る前に一声」が付いた行を、人が確かめたと記録する。
    #   ここを押しても何も送らない。下書きが作れるようになるだけ
    $L = Load-Ledger $caseId; $d = $L.Doc
    $c = $d.候補 | Where-Object { $_.相手 -eq $aite } | Select-Object -First 1
    if (-not $c) { Alert ("この相手（" + $aite + "）が台帳にありません。`r`nボードの画面が古いことがあります（取り消した相手は、作り直しで行が無くなります）。`r`n`r`n熊田さんがすること：ボードを閉じて開き直してください（ブラウザ版は読み直し）。開き直してもこの行が出るときは、仕組みの側の止まりです。熊田さんが直す必要はありません。"); break }
    $c | Add-Member -NotePropertyName 確認しました -NotePropertyValue ([pscustomobject]@{
        日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm'); だれが = $(if ($env:HACCHU_WHO) { $env:HACCHU_WHO } else { $env:USERNAME }); 確かめた理由 = [string]$c.確認の理由 }) -Force
    Save-Ledger $L
    Add-OkuttaKiroku $caseId $aite '送る前の確認をした' ([string]$c.確認の理由)
    Alert "確かめたことを記録しました。`r`nこの行の［下書きを作って開く］が出ます。"
    Note "okcheck $caseId $aite"
  }
  'shusei' {
    # 2026-10-31 草案（発注チェーンの点検・本番未投入） 項目5：修正の字に出庫の語があって「確かめ待ち」になった催事で、人が［注文として当てる］［報告なので当てない］を押す。どの答えに対する決めかを答えた日時で結ぶ
    if ($State -notin @('注文', '報告')) { throw '注文か報告を選んでください' }
    $L = Load-Ledger $caseId
    $kagiS = [string]$L.Doc.担当者の確認.答えた日時
    $L.Doc | Add-Member -NotePropertyName 修正の扱い -NotePropertyValue ([pscustomobject][ordered]@{ 扱い = $State; 答えた日時 = $kagiS; 押した人 = $(if ($env:HACCHU_WHO) { $env:HACCHU_WHO } else { $env:USERNAME }); どこで = $(if ($env:HACCHU_WHO) { 'ブラウザ' } else { $env:COMPUTERNAME }); 日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm') }) -Force
    Save-Ledger $L
    Note "修正の扱い $State $caseId（答えた日時 $kagiS）"
    Alert ("記録しました（" + $State + "）。次の更新で台帳に反映します。")
  }
  'henkook' {
    # 2026-10-08 送った後に中身が変わった⚠（process_budget_files が立てる）を、人が「相手に伝えた／問題なし」と確かめた記録。
    #   送った時の中身を今の中身に置き換える＝次にまた変わった時だけ⚠が出る。何も送らない
    $L = Load-Ledger $caseId; $d = $L.Doc
    $c = $d.候補 | Where-Object { $_.相手 -eq $aite } | Select-Object -First 1
    if (-not $c) { Alert ("この相手（" + $aite + "）が台帳にありません。`r`nボードの画面が古いことがあります（取り消した相手は、作り直しで行が無くなります）。`r`n`r`n熊田さんがすること：ボードを閉じて開き直してください（ブラウザ版は読み直し）。開き直してもこの行が出るときは、仕組みの側の止まりです。熊田さんが直す必要はありません。"); break }
    $mae = [string]$c.送った時の中身; $ima = $(if ([string]$c.中身全文) { [string]$c.中身全文 } else { [string]$c.中身 })
    $c | Add-Member -NotePropertyName 送った時の中身 -NotePropertyValue $ima -Force
    $c | Add-Member -NotePropertyName 送った後に変わった -NotePropertyValue $false -Force
    Save-Ledger $L
    Add-OkuttaKiroku $caseId $aite '送った後の変更を確かめた' ('前：' + $mae + '／今：' + $ima)
    Note "henkook $caseId $aite"
  }
  'mottekitta' {
    # 2026-10-08 仕組みの穴22（ボス裁定）：担当者がAIかおりの［倉庫から持っていった］を押す → AIかおりが 記録\倉庫出し_持っていった.json に足す（持ち主＝AIかおり・足すだけ）
    #   → ここで読み、「全部」なら倉庫出しの行を mark で「倉庫から出した」（在庫の出庫も mark の中で同じに書く）。「一部」は行を変えずボードに出す。
    #   同じ key の 取り消し は、ここで当てた時だけ戻す。当てた記録＝発注案\_持っていった_当てた.json（この会話が持ち主）
    $src = Join-Path $root '記録\倉庫出し_持っていった.json'
    if (-not (Test-Path $src)) { break }
    $sj = $null; for ($try = 1; $try -le 3; $try++) { try { $sj = Get-Content $src -Raw -Encoding UTF8 | ConvertFrom-Json; break } catch { Start-Sleep -Milliseconds 700 } }
    if (-not $sj) { Note 'mottekitta：写しが読めない'; break }
    $ap = Join-Path $planDir '_持っていった_当てた.json'
    $ad = [ordered]@{ 説明 = 'AIかおりの［倉庫から持っていった］をボードに当てた記録（発注ボードの会話が書く）'; 当てた = @(); 一部 = @(); 当てられない = @() }
    if (Test-Path $ap) { try { $x0 = Get-Content $ap -Raw -Encoding UTF8 | ConvertFrom-Json; $ad.当てた = @($x0.当てた | Where-Object { $_ }); $ad.一部 = @($x0.一部 | Where-Object { $_ }); $ad.当てられない = @($x0.当てられない | Where-Object { $_ }) } catch {} }
    $doneKeys = @{}; foreach ($a in $ad.当てた) { $doneKeys[[string]$a.key] = $a }
    $seenKeys = @{}; foreach ($a in @($ad.一部) + @($ad.当てられない)) { $seenKeys[[string]$a.key] = $true }
    $changed = $false
    foreach ($r in @($sj.行)) {
        if (-not $r -or -not [string]$r.key) { continue }
        $k = [string]$r.key; $cid2 = [string]$r.案件ID
        if ($r.取り消し -eq $true) {
            $a = $doneKeys[$k]
            if ($a -and -not $a.戻した) {
                $L4 = $null; try { $L4 = Load-Ledger $cid2 } catch {}
                $c4 = $(if ($L4) { $L4.Doc.候補 | Where-Object { $_.方法 -eq '倉庫出し' -and $_.候補外 -ne $true } | Select-Object -First 1 } else { $null })
                if ($c4 -and [string]$c4.状態 -eq '倉庫から出した') { $env:HACCHU_DOKODE = 'AIかおり（倉庫から持っていった・取り消し）'; $env:HACCHU_OSHITA = [string]$r.担当者; try { & $PSCommandPath -Action mark -CaseHex (ToHex $cid2) -AiteHex (ToHex ([string]$c4.相手)) -StateHex (ToHex '候補') -Config $Config | Out-Null } finally { $env:HACCHU_DOKODE = ''; $env:HACCHU_OSHITA = '' } }
                $a | Add-Member -NotePropertyName 戻した -NotePropertyValue (Get-Date -Format 'yyyy-MM-dd HH:mm') -Force; $changed = $true
                Note "mottekitta 取り消し $k"
            }
            continue
        }
        if ($doneKeys.ContainsKey($k) -or $seenKeys.ContainsKey($k)) { continue }
        $kiroku = [ordered]@{ key = $k; 案件ID = $cid2; 担当者 = [string]$r.担当者; 品 = @(@($r.品) | ForEach-Object { [string]$_.字 }); 時刻 = [string]$r.時刻; 当てた日時 = (Get-Date -Format 'yyyy-MM-dd HH:mm') }
        $L4 = $null; if (Test-Path (Join-Path $planDir ($cid2 + '.json'))) { try { $L4 = Load-Ledger $cid2 } catch {} }
        $c4 = $(if ($L4) { $L4.Doc.候補 | Where-Object { $_.方法 -eq '倉庫出し' -and $_.候補外 -ne $true } | Select-Object -First 1 } else { $null })
        if (-not $c4) { $kiroku.理由 = '台帳に倉庫出しの行が無い'; $ad.当てられない = @($ad.当てられない) + [pscustomobject]$kiroku; $changed = $true; continue }
        if ($r.全部 -ne $true) { $ad.一部 = @($ad.一部) + [pscustomobject]$kiroku; $changed = $true; Note "mottekitta 一部 $k"; continue }
        if ([string]$c4.状態 -in @('倉庫から出した', '不要')) { $kiroku.理由 = ('行はもう「' + [string]$c4.状態 + '」'); $ad.当てられない = @($ad.当てられない) + [pscustomobject]$kiroku; $changed = $true; continue }
        if ([string]$r.押した時の中身全文) {
            $ima = $(if ([string]$c4.中身全文) { [string]$c4.中身全文 } else { [string]$c4.中身 })
            if ([string]$r.押した時の中身全文 -ne $ima) { $kiroku.理由 = '押した後に倉庫出しの中身が変わった（熊田さんがボードで締める）'; $ad.一部 = @($ad.一部) + [pscustomobject]$kiroku; $changed = $true; continue }
        }
        $env:HACCHU_DOKODE = 'AIかおり（倉庫から持っていった）'; $env:HACCHU_OSHITA = [string]$r.担当者   # 2026-10-30 穴-104：倉庫出し_出した.json の行に入れる
        try { & $PSCommandPath -Action mark -CaseHex (ToHex $cid2) -AiteHex (ToHex ([string]$c4.相手)) -StateHex (ToHex '倉庫から出した') -Config $Config | Out-Null } finally { $env:HACCHU_DOKODE = ''; $env:HACCHU_OSHITA = '' }
        $ad.当てた = @($ad.当てた) + [pscustomobject]$kiroku; $doneKeys[$k] = $kiroku; $changed = $true
        Note "mottekitta 当てた $k（$cid2 倉庫出し → 倉庫から出した）"
    }
    if ($changed -and -not $DryRun) {
        [IO.File]::WriteAllText($ap, ($ad | ConvertTo-Json -Depth 6), $utf8bom)
        try { & (Join-Path $PSScriptRoot 'board_build.ps1') -Config (Join-Path $PSScriptRoot 'board_config.json') | Out-Null } catch {}
    }
  }
  'manq' {
    # 2026-10-09 玉井さん「1」（申し送り 14-24）：マネキンは発注ボードで管理する。熊田さんが電話で頼んだか・マネキン会社の返事（日ごとに誰が何時）を記録する。
    #   記録＝発注\マネキン\〈案件ID〉.json（持ち主＝発注ボードの会話）。D1 の board_manq・board_manq_days へは web_push.ps1 が写す（AIかおりが読む）
    #   State＝JSON：{op:irai|tanomanai|modosu|add|del, 会社, 人, 日:[yyyy-mm-dd], 入, 終}
    $o = $null; try { $o = $State | ConvertFrom-Json } catch {}
    if (-not $o -or -not [string]$o.op) { Alert 'マネキンの操作が読めませんでした。もう一度押してください。'; break }
    $mdir = Join-Path $root 'マネキン'; if (-not (Test-Path $mdir)) { New-Item -ItemType Directory $mdir | Out-Null }
    $mp = Join-Path $mdir ($caseId + '.json')
    $m = $null; if (Test-Path $mp) { try { $m = Get-Content $mp -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Alert 'マネキンの記録が読めませんでした。少し待って、もう一度押してください。'; break } }
    if (-not $m) { $m = [pscustomobject][ordered]@{ schema = 1; 案件ID = $caseId; 状態 = 'まだ'; 頼んだ = $null; 返事 = @(); 記録 = @() } }
    $dare = $(if ($env:HACCHU_WHO) { $env:HACCHU_WHO } else { $env:COMPUTERNAME + 'のボード' })
    $ima = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $hen = @(@($m.返事) | Where-Object { $_ })
    $nani = ''
    switch ([string]$o.op) {
      'irai'      { $m.状態 = '頼んだ'; $m.頼んだ = [pscustomobject][ordered]@{ 日時 = $ima; 誰が = $dare; 会社 = [string]$o.会社 }; $nani = '電話で頼んだ' + $(if ([string]$o.会社) { '（' + [string]$o.会社 + '）' } else { '' }) }
      'tanomanai' { $m.状態 = '頼まない'; $m.頼んだ = [pscustomobject][ordered]@{ 日時 = $ima; 誰が = $dare; 会社 = '' }; $nani = '頼まない（社員だけ）' }
      'modosu'    { $m.状態 = 'まだ'; $m.頼んだ = $null; $nani = 'まだ頼んでいないに戻した' }
      'add' {
        $hito = ([string]$o.人).Trim(); $days = @(@($o.日) | ForEach-Object { [string]$_ } | Where-Object { $_ -match '^\d{4}-\d{2}-\d{2}$' })
        if (-not $hito -or -not $days.Count) { Alert '来る人の名前と、来る日を選んでください。'; break }
        $hen = @($hen | Where-Object { -not ([string]$_.人 -eq $hito -and $days -contains [string]$_.日) })
        foreach ($dy in $days) { $hen += [pscustomobject][ordered]@{ 日 = $dy; 人 = $hito; 会社 = [string]$o.会社; 入 = [string]$o.入; 終 = [string]$o.終; 入れた人 = $dare; 入れた日時 = $ima } }
        if ($m.状態 -eq 'まだ') { $m.状態 = '頼んだ'; $m.頼んだ = [pscustomobject][ordered]@{ 日時 = $ima; 誰が = $dare; 会社 = [string]$o.会社 } }
        $nani = '返事：' + $hito + '（' + [string]$o.会社 + '）' + ($days -join '・') + ' ' + [string]$o.入 + '〜' + [string]$o.終
      }
      'del' { $hen = @($hen | Where-Object { -not ([string]$_.人 -eq [string]$o.人 -and [string]$_.日 -eq [string]$o.日) }); $nani = '返事を消した：' + [string]$o.日 + ' ' + [string]$o.人 }
      default { Alert ('知らないマネキンの操作です：' + [string]$o.op) }
    }
    if (-not $nani) { break }
    $m.返事 = @($hen | Sort-Object 日, 入, 人)
    $m.記録 = @(@($m.記録) | Where-Object { $_ }) + [pscustomobject][ordered]@{ 日時 = $ima; 誰が = $dare; 何を = $nani }
    if (-not $DryRun) { [IO.File]::WriteAllText($mp, ($m | ConvertTo-Json -Depth 6), $utf8bom) }
    Note "manq $caseId $nani（$dare）"
  }
  'build' { }
}
# 最後に必ずボードを書き直す
& (Join-Path $PSScriptRoot 'board_build.ps1') -Config $Config | Out-Null
