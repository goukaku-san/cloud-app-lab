# 発注チェーン 修正案の回帰テスト（2026-10-31・本番から隔離）。書く場所は /tmp/w/kaizen/sandbox だけ。Gドライブ・本番の台帳には触れない
$ErrorActionPreference = 'Stop'
$KZ = '/tmp/w/kaizen'; $NEW = "$KZ/new"; $ORIG = "$KZ/orig"; $FX = "$KZ/tests/fx"; $SB = "$KZ/sandbox"
if (Test-Path $SB) { Remove-Item $SB -Recurse -Force }; New-Item -ItemType Directory $SB | Out-Null
$global:KEKKA = @()
function T([string]$id, [string]$name, [bool]$ok, [string]$detail = '') { $global:KEKKA += [pscustomobject]@{ id = $id; ok = $ok; name = $name; detail = $detail }; '{0} {1} {2}{3}' -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $id, $name, $(if ($detail) { ' — ' + $detail } else { '' }) }
function J($o) { $o | ConvertTo-Json -Depth 10 }
function WJ([string]$p, $o) { [IO.File]::WriteAllText($p, (J $o), (New-Object Text.UTF8Encoding $true)) }
function Hx([string]$s) { (([Text.Encoding]::UTF8.GetBytes($s)) | ForEach-Object { $_.ToString('x2') }) -join '' }
function FuncsFrom([string]$path) { $e = $null; $ast = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$e); @($ast.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.FunctionDefinitionAst] } | ForEach-Object { $_.Extent.Text }) -join "`n" }
function AstFind([string]$path, [scriptblock]$pred) { $e = $null; $ast = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$e); $ast.FindAll($pred, $true) }

# ---------- 実データ ----------
$naka = (Get-Content "$FX/seniya_naka.txt" -Raw -Encoding UTF8).Trim()
$genbaReal = @((Get-Content '/tmp/w/genba.json' -Raw -Encoding UTF8 | ConvertFrom-Json).発注完了)
$ID = '20261029-尾崎-京阪百貨店ひ'; $VEN = '京阪百貨店ひらかた店'
. "$NEW/genba_hantei.ps1"; . "$NEW/shusei_hantei.ps1"

# ===== 項目1：一部発注済みの行を丸ごと完了にしない・数量は未確認 =====
# 今のコード（元の Genba-Done）を元のファイルから取り出してそのまま動かす
$oldSb = [scriptblock]::Create((FuncsFrom "$ORIG/process_budget_files.ps1") + "`n`$genba = `$args[0]; `$ittap = @(); Genba-Done `$args[1] `$args[2] `$args[3]")
$oldRes = & $oldSb $genbaReal $VEN $naka $ID
T 'T01' '【今のコード】実データ セニヤ12品：1品の名前一致で行ごと「現場が発注済み」になる（再現）' ([bool]$oldRes) ("返り値=" + [string]$oldRes)
$h = Get-GenbaHantei -Id $ID -Venue $VEN -Naka $naka -Aite 'セニヤ' -Ittap @() -Genba $genbaReal
T 'T02' '【案】同じ実データ：品ごとに当てると「一部」（当たった4品・当たらない8品）' ($h.区分 -eq '一部' -and $h.当たった.Count -eq 4 -and $h.当たらない.Count -eq 8) ("当たった=" + (($h.当たった | ForEach-Object 品) -join '・'))
$g = Resolve-GenbaState -State '候補' -Old $null -Hantei $h -Naka $naka -Ima '2026-10-31 10:00'
$DONE = @('送った', '電話した', '不要', '倉庫から出した', '現場が発注済み')
T 'T03' '【案】候補＋一部 → 「一部は現場が発注済み」（完了でも候補でもない＝下書きを作らない止まり）' ($g.状態 -eq '一部は現場が発注済み' -and -not ($DONE -contains $g.状態) -and ($GENBA_HOLD -contains $g.状態)) $g.状態

# 全品が当たる（1タップのボタン）＝品名は全部一致。数は未確認
$items = @($naka -split '／' | ForEach-Object { $_.Trim() })
$ittapAll = @([pscustomobject]@{ id = 'a1'; 種別 = '発注完了'; 案件ID = $ID; 相手 = 'セニヤ'; 決め方 = 'ボタン'; 日時 = '2026-10-29 14:40'; だれが = '尾崎'; もとの発言 = ($items -join ' ') })
$hAll = Get-GenbaHantei -Id $ID -Venue $VEN -Naka $naka -Aite 'セニヤ' -Ittap $ittapAll -Genba @()
$gAll = Resolve-GenbaState -State '候補' -Old $null -Hantei $hAll -Naka $naka -Ima '2026-10-31 10:00'
T 'T04' '【案】全品の品名が一致 → 現場が発注済み・照合の数は「未確認」（品名一致と数量確認を分ける）' ($gAll.状態 -eq '現場が発注済み' -and $gAll.現場の照合.数 -eq '未確認' -and $gAll.現場の照合.区分 -like '*数は未確認*') ($gAll.現場の照合.区分 + ' / 数=' + $gAll.現場の照合.数)
# 数量違い：実データの LINE は「わさびさきいか 大袋 50✕3」、台帳は 75g（50袋入） 2c/s。名前が当たっても数は確かめていない
$ittapQty = @([pscustomobject]@{ id = 'q1'; 種別 = '発注完了'; 案件ID = $ID; 相手 = 'セニヤ'; 決め方 = 'ボタン'; 日時 = '2026-10-29 14:40'; だれが = '尾崎'; もとの発言 = 'わさびさきいか 大袋 50✕3' })
$nakaW = 'わさびさきいか 75g（50袋入） 2c/s'
$gQ = Resolve-GenbaState -State '候補' -Old $null -Hantei (Get-GenbaHantei -Id $ID -Venue $VEN -Naka $nakaW -Aite 'セニヤ' -Ittap $ittapQty -Genba @()) -Naka $nakaW -Ima '2026-10-31 10:00'
T 'T05' '【案】数量違い（LINE 3箱・台帳 2c/s）：品名一致でも「数は未確認」のまま（確認済みにしない）' ($gQ.状態 -eq '現場が発注済み' -and $gQ.現場の照合.数 -eq '未確認') ('数=' + $gQ.現場の照合.数)

# 一部 → 根拠が消えても止めたまま／済んだ品を予定から外した時だけ候補へ
$oldPart = [pscustomobject]@{ 状態 = '一部は現場が発注済み'; 現場の記録 = $g.現場の記録; 現場の照合 = $g.現場の照合 }
$hNone = Get-GenbaHantei -Id $ID -Venue $VEN -Naka $naka -Aite 'セニヤ' -Ittap @() -Genba @()
$g9 = Resolve-GenbaState -State '一部は現場が発注済み' -Old $oldPart -Hantei $hNone -Naka $naka
T 'T06' '【案】一部 → LINE の記録が21日を過ぎて消えても止めたまま（候補へ戻して済んだ品を再発注しない）' ($g9.状態 -eq '一部は現場が発注済み') $g9.理由
$nakaRest = (@($items | Where-Object { $_ -notlike 'わさびさきいか*' -and $_ -notlike '黒ごま炙りいわし*' }) -join '／')
$g10 = Resolve-GenbaState -State '一部は現場が発注済み' -Old $oldPart -Hantei (Get-GenbaHantei -Id $ID -Venue $VEN -Naka $nakaRest -Aite 'セニヤ' -Ittap @() -Genba $genbaReal) -Naka $nakaRest
T 'T07' '【案】済んだ品（わさびさきいか・黒ごま炙りいわし 計4品）を「もう頼んである」で予定から外す → 候補（残り8品だけ下書きにできる）' ($g10.状態 -eq '候補') $g10.理由
$nakaHalf = (@($items | Where-Object { $_ -notlike 'わさびさきいか 75g*' }) -join '／')
$g11 = Resolve-GenbaState -State '一部は現場が発注済み' -Old $oldPart -Hantei (Get-GenbaHantei -Id $ID -Venue $VEN -Naka $nakaHalf -Aite 'セニヤ' -Ittap @() -Genba $genbaReal) -Naka $nakaHalf
T 'T08' '【案】済んだ品の片方だけ外した → まだ止めたまま（済んだ品が1つでも残れば下書きを作らない）' ($g11.状態 -eq '一部は現場が発注済み') $g11.理由

# ===== 項目2：根拠が消えても完了を戻さない・明示の取消／訂正だけに反応 =====
$oldDone = [pscustomobject]@{ 状態 = '現場が発注済み'; 日時 = '2026-10-29 20:30'; 現場の記録 = '現場が発注済み（LINE 2026-10-29 14:32・熊田さん）'; 現場の照合 = $gAll.現場の照合 }
$oldSb2 = [scriptblock]::Create((FuncsFrom "$ORIG/process_budget_files.ps1") + "`n`$genba = @(); `$ittap = @(); [bool](Genba-Done `$args[0] `$args[1] `$args[2])")
T 'T09' '【今のコード】記録が21日を過ぎて消えると根拠なし → 元のコードは完了を候補へ戻す（再現の前提）' (-not (& $oldSb2 $VEN $naka $ID)) '根拠なし＝元のコードは「候補に戻す」へ進む'
$r = Resolve-GenbaState -State '現場が発注済み' -Old $oldDone -Hantei $hNone -Naka $naka
T 'T10' '【案】期間経過で根拠が消えた → 完了のまま' ($r.状態 -eq '現場が発注済み') $r.理由
$r = Resolve-GenbaState -State '現場が発注済み' -Old $oldDone -Hantei $hNone -Naka $naka -NyuuguchiOK $false
T 'T11' '【案】読み込み失敗の回 → 何も変えない' ($r.状態 -eq '現場が発注済み' -and $r.理由 -like '入口が読めない*') $r.理由
$otherOnly = @($genbaReal | Where-Object { $_.会場 -notlike '*ひらかた*' })
$r = Resolve-GenbaState -State '現場が発注済み' -Old $oldDone -Hantei (Get-GenbaHantei -Id $ID -Venue $VEN -Naka $naka -Aite 'セニヤ' -Ittap @() -Genba $otherOnly) -Naka $naka
T 'T12' '【案】取り込み漏れ（ひらかたの記録だけ抜けた実データ）→ 完了のまま' ($r.状態 -eq '現場が発注済み') $r.理由
$tk = Get-GenbaTorikeshi -Id $ID -Aite 'セニヤ' -Ittap @([pscustomobject]@{ 種別 = '取消'; 案件ID = $ID; 相手 = 'セニヤ'; 日時 = '2026-10-30 09:00'; だれが = '熊田'; もとの発言 = 'セニヤ取消' }) -Naoshi @() -Old $oldDone
$r = Resolve-GenbaState -State '現場が発注済み' -Old $oldDone -Hantei $hAll -Torikeshi $tk -Naka $naka
T 'T13' '【案】根拠より後の1タップ「取消」→ 「取消・確かめ待ち」（下書きは作らず人へ）' ($r.状態 -eq '現場の発注が取り消された・確かめ待ち' -and $GENBA_HOLD -contains $r.状態) $r.現場の記録
$tk = Get-GenbaTorikeshi -Id $ID -Aite 'セニヤ' -Ittap @([pscustomobject]@{ 種別 = '取消'; 案件ID = $ID; 相手 = 'セニヤ'; 日時 = '2026-10-29 10:00'; だれが = '熊田' }) -Naoshi @() -Old $oldDone
T 'T14' '【案】根拠より前の取消は数えない → 完了のまま' ($null -eq $tk) ''
$tk = Get-GenbaTorikeshi -Id $ID -Aite 'セニヤ' -Ittap @([pscustomobject]@{ 種別 = '数量変更'; 案件ID = $ID; 相手 = 'セニヤ'; 日時 = '2026-10-30 09:00'; だれが = '熊田' }) -Naoshi @() -Old $oldDone
T 'T15' '【案】根拠より後の1タップ「数量変更」→ 取消・確かめ待ちへ' ([bool]$tk -and $tk.種類 -eq '数量変更') ''
$tk = Get-GenbaTorikeshi -Id $ID -Aite 'セニヤ' -Ittap @() -Naoshi @([pscustomobject]@{ 種別 = '頼んだ分を減らした'; 行 = [pscustomobject]@{ 頼む先 = 'セニヤ' }; いつ = '2026-10-30T23:03:00+09:00'; 誰が = '蔵人'; ファイル = 'x.json' }) -Old $oldDone
T 'T16' '【案】予定の直し「頼んだ分を減らした」（後）→ 取消・確かめ待ちへ' ([bool]$tk) ''
# 人の［戻す］の後は同じ根拠で当て直さない
$oldHz = [pscustomobject]@{ 状態 = '候補'; 現場の判定を外した = [pscustomobject]@{ 日時 = '2026-10-30 12:00'; 押した人 = '熊田' } }
$r = Resolve-GenbaState -State '候補' -Old $oldHz -Hantei $hAll -Naka $naka
T 'T17' '【案】人が［戻す］で外した後 → それまでの根拠では当て直さない（今は次の回に上書きされる）' ($r.状態 -eq '候補') $r.理由
$ittapNew = @([pscustomobject]@{ id = 'n1'; 種別 = '発注完了'; 案件ID = $ID; 相手 = 'セニヤ'; 決め方 = 'ボタン'; 日時 = '2026-10-31 08:00'; だれが = '尾崎'; もとの発言 = ($items -join ' ') })
$r = Resolve-GenbaState -State '候補' -Old $oldHz -Hantei (Get-GenbaHantei -Id $ID -Venue $VEN -Naka $naka -Aite 'セニヤ' -Ittap $ittapNew -Genba @()) -Naka $naka
T 'T18' '【案】［戻す］の後に来た新しい根拠 → 当て直す' ($r.状態 -eq '現場が発注済み') $r.理由

# ===== 項目3：入口の読み込み失敗＝その回は台帳を書かない =====
$rnSb = [scriptblock]::Create(((AstFind "$NEW/process_budget_files.ps1" { param($a) $a -is [Management.Automation.Language.FunctionDefinitionAst] -and $a.Name -eq 'Read-Nyuuguchi' }) | Select-Object -First 1).Extent.Text + "`nRead-Nyuuguchi `$args[0] `$args[1]")
$tdir = "$SB/rn"; New-Item -ItemType Directory $tdir | Out-Null
[IO.File]::WriteAllText("$tdir/zero.json", ''); [IO.File]::WriteAllText("$tdir/nokey.json", '{"説明":"x"}'); [IO.File]::WriteAllText("$tdir/broken.json", '{"行":[{"a":'); [IO.File]::WriteAllText("$tdir/ok.json", '{"行":[{"種別":"発注完了"}]}'); [IO.File]::WriteAllText("$tdir/empty.json", '{"行":[]}')
$a = & $rnSb "$tdir/none.json" '行'; $b = & $rnSb "$tdir/zero.json" '行'; $c0 = & $rnSb "$tdir/nokey.json" '行'; $d0 = & $rnSb "$tdir/broken.json" '行'; $e0 = & $rnSb "$tdir/ok.json" '行'; $f0 = & $rnSb "$tdir/empty.json" '行'
T 'T19' '【案】入口の読み方：無い＝読めた(空)／0バイト・欄なし・壊れ＝読めない／正常・空の一覧＝読めた' ($a.ok -and -not $a.aru -and -not $b.ok -and -not $c0.ok -and -not $d0.ok -and $e0.ok -and @($e0.v).Count -eq 1 -and $f0.ok) ("無い=$($a.ok) 0バイト=$($b.ok) 欄なし=$($c0.ok) 壊れ=$($d0.ok) 正常=$($e0.ok) 空=$($f0.ok)")

function New-Sandbox([string]$name) {
    $r0 = "$SB/$name/発注"; foreach ($d in '仕組み', '発注案', '予算と型', '確認') { New-Item -ItemType Directory "$r0/$d" -Force | Out-Null }
    foreach ($f in 'process_budget_files.ps1', 'make_order_drafts.ps1', 'board_action.ps1', 'board_build.ps1', 'genba_hantei.ps1', 'shusei_hantei.ps1') { Copy-Item "$NEW/$f" "$r0/仕組み/$f" }
    [IO.File]::WriteAllText("$r0/仕組み/納品先.json", '{"納品先":[]}'); [IO.File]::WriteAllText("$r0/仕組み/board_config.json", '{}'); [IO.File]::WriteAllText("$r0/仕組み/送る日の日数.json", '{}')
    [IO.File]::WriteAllText("$r0/仕組み/add_usage_to_plans.ps1", "'（試験用の空の add_usage_to_plans）'")
    # 試験だけの置き換え：Linux に Outlook が無いので「Outlook が開いている」とみなす（下書きを作る処理そのものは呼ばれる前に止まるかを見る）
    $ba = Get-Content "$r0/仕組み/board_action.ps1" -Raw -Encoding UTF8; $ba = $ba.Replace('    return [bool]$p', '    return $true   # 試験用'); [IO.File]::WriteAllText("$r0/仕組み/board_action.ps1", $ba, (New-Object Text.UTF8Encoding $true))
    WJ "$r0/予算と型/$ID.json" ([ordered]@{ 案件ID = $ID; 会場 = $VEN; 会期開始 = '2026-10-29'; 会期終了 = '2026-11-04'; 担当者 = '尾崎正俊'; 売上予算 = 850000; 型 = $null; 仮置き = $false; 屋号 = '学問のするめ' })
    WJ "$r0/発注案/$ID.json" ([ordered]@{ 案件ID = $ID; 会場 = $VEN; 会期終了 = '2026-11-04'; 下書き可 = $true; 状態 = '完了'; 指紋 = 'old'; 更新 = '2026-10-31 07:30'; 候補 = @([ordered]@{ 相手 = 'セニヤ'; 方法 = 'FAX'; 中身 = $naka.Substring(0, 90); 中身全文 = $naka; 状態 = '現場が発注済み'; 日時 = '2026-10-23 22:01'; 現場の記録 = '現場が発注済み（LINE 2026-10-29 14:32・熊田さん）'; EntryID = ''; StoreID = ''; 件名 = ''; 旧下書き = @(); 引き当て = @() }) })
    Copy-Item '/tmp/w/genba.json' "$r0/発注案/_LINEで発注済み.json"
    WJ "$r0/発注案/_LINEで1タップ.json" ([ordered]@{ 行 = @() })
    WJ "$r0/発注案/_LINE依頼の確認済み.json" ([ordered]@{ 確認済み = @() })
    return $r0
}
function Run-Pbf([string]$r0) { $o = & pwsh -NoProfile -File "$r0/仕組み/process_budget_files.ps1" 2>&1 | Out-String; return $o }
function HashOf([string]$p) { (Get-FileHash $p -Algorithm SHA256).Hash }
foreach ($cs in @(
    @{ id = 'T20'; nm = '1タップの記録が0バイト'; f = '_LINEで1タップ.json'; body = '' },
    @{ id = 'T21'; nm = 'LINEで発注済み に「発注完了」の欄が無い'; f = '_LINEで発注済み.json'; body = '{"説明":"書きかけ"}' },
    @{ id = 'T22'; nm = '確認済み の JSON が壊れている'; f = '_LINE依頼の確認済み.json'; body = '{"確認済み":[{"鍵":' })) {
    $r0 = New-Sandbox ('pbf_' + $cs.id); [IO.File]::WriteAllText("$r0/発注案/$($cs.f)", $cs.body)
    $before = HashOf "$r0/発注案/$ID.json"; $out = Run-Pbf $r0; $after = HashOf "$r0/発注案/$ID.json"
    T $cs.id ("【案・実行】" + $cs.nm + " → 台帳は1つも書き換わらない（保留）・⛔を記録") ($before -eq $after -and $out -match '⛔ 入口のファイルが読めない') ("台帳 " + $(if ($before -eq $after) { '同じ' } else { '変わった' }) + ' / ' + (($out -split "`n" | Where-Object { $_ -match '⛔' } | Select-Object -First 1) -replace '\s+$', ''))
}
$r0 = New-Sandbox 'pbf_T23'; $out = Run-Pbf $r0
T 'T23' '【案・実行・陽性対照】入口が全部読める → 保留せず予算ファイルの処理に入る（この箱には計算の道具が無いので、その先で止まる）' ($out -notmatch '⛔ 入口' -and $out -match 'この予算ファイルで止まりました|対象外|台帳') ((($out -split "`n" | Where-Object { $_ -match '止まりました|⛔|台帳' } | Select-Object -First 1)) -replace '\s+$', '')
$pbfNew = Get-Content "$NEW/process_budget_files.ps1" -Raw -Encoding UTF8
T 'T24' '【案】作り直しの判定（指紋）に 1タップ・確認済み の更新時刻が入る' ($pbfNew -match "\`$finger \+= '\|1タップ'" -and $pbfNew -match "\`$finger \+= '\|確認済み'") ''

# ===== 項目5：出庫の語＝数を変えず確かめ待ち =====
$k = Get-ShuseiKubun '焼き貝ひも30K…倉庫から出庫しました！'
T 'T25' '【案】フレスト天満の字（末尾「倉庫から出庫しました！」）→ 確かめ待ち' ($k.区分 -eq '確かめ待ち') ('出庫の語=' + ($k.出庫の語 -join '・'))
$k = Get-ShuseiKubun '倉庫から出庫したので、わさびさきいか 大袋を追加注文お願いします'
T 'T26' '【案】「出庫したので追加注文」→ 却下しない・確かめ待ち（注文の語も記録）' ($k.区分 -eq '確かめ待ち' -and $k.注文の語.Count -ge 1) ('注文の語=' + ($k.注文の語 -join '・'))
$k = Get-ShuseiKubun 'わさびさきいか 大袋 3c/s に増やしてください'
T 'T27' '【案】出庫の語が無い修正 → 今までどおり反映する' ($k.区分 -eq '通常') ''
$ifAst = (AstFind "$NEW/make_order_drafts.ps1" { param($a) $a -is [Management.Automation.Language.IfStatementAst] -and $a.Clauses[0].Item1.Extent.Text -like "*候補の答え*-eq '修正あり'*" }) | Select-Object -First 1
function Run-Fix($fx, [string]$at = '', [string]$ak = '', [string]$zk = '', [string]$zkk = '') {
    $code = "param(`$fx,`$ShuseiAtsukai,`$ShuseiKagi,`$ShuseiZenkai,`$ShuseiZenkaiKagi)`n`$fixState='対象外'; `$fixDone=@(); `$fixNote=@(); `$mojiChumon=@(); `$global:KEKKAEFL=0`nfunction Reflect-Rows(`$rows,`$src){ `$global:KEKKAEFL++; Set-Variable -Name fixDone -Scope 1 -Value (@((Get-Variable fixDone -Scope 1).Value) + '直した') }`n. '$NEW/shusei_hantei.ps1'`n" + $ifAst.Extent.Text + "`n[pscustomobject]@{ 状態=`$fixState; 反映=`$global:KEKKAEFL; 理由=(`$fixNote -join '／') }"
    & ([scriptblock]::Create($code)) $fx $at $ak $zk $zkk
}
$fxF = [pscustomobject]@{ 候補の答え = '修正あり'; 確認の段階 = '済'; 修正リスト原文 = '焼き貝ひも30K…倉庫から出庫しました！'; 答えた日時 = '2026-10-29T10:00:00+09:00'; 候補の品目 = @() }
$x = Run-Fix $fxF
T 'T28' '【案】出庫の語・人の決め無し → 数を当てない（反映0回）・「確かめ待ち（報告か注文か）」' ($x.反映 -eq 0 -and $x.状態 -eq '確かめ待ち（報告か注文か）') $x.状態
$x = Run-Fix $fxF '報告' '2026-10-29T10:00:00+09:00'
T 'T29' '【案】人が［報告なので当てない］→ 数を当てない・「反映しない（報告と確かめた）」' ($x.反映 -eq 0 -and $x.状態 -eq '反映しない（報告と確かめた）') $x.状態
$x = Run-Fix $fxF '注文' '2026-10-29T10:00:00+09:00'
T 'T30' '【案】人が［注文として当てる］→ 今までどおり当てる（反映1回・反映した）' ($x.反映 -eq 1 -and $x.状態 -eq '反映した') $x.状態
$x = Run-Fix $fxF '注文' '2026-10-20T10:00:00+09:00'
T 'T31' '【案】決めが古い答えに対するもの → 効かない＝確かめ待ち' ($x.反映 -eq 0 -and $x.状態 -like '確かめ待ち*') $x.状態
$x = Run-Fix $fxF '' '' '反映した' '2026-10-29T10:00:00+09:00'
T 'T32' '【案】フレストの移り変わり：前の回に当て済み（送った後）→ 今の数のまま止める（数を元へ戻さない）' ($x.反映 -eq 1 -and $x.状態 -eq '確かめ待ち（報告か注文か・反映済みの数のまま）') $x.状態
$fxN = [pscustomobject]@{ 候補の答え = '修正あり'; 確認の段階 = '済'; 修正リスト原文 = 'わさびさきいか 3c/s に増やして'; 答えた日時 = '2026-10-29T10:00:00+09:00'; 候補の品目 = @() }
$x = Run-Fix $fxN
T 'T33' '【案】出庫の語が無い → 今までどおり反映（反映1回）' ($x.反映 -eq 1 -and $x.状態 -eq '反映した') $x.状態
$thAst = (AstFind "$NEW/make_order_drafts.ps1" { param($a) $a -is [Management.Automation.Language.IfStatementAst] -and $a.Clauses[0].Item1.Extent.Text -like "*確かめ待ち*NoDrafts*" }) | Select-Object -First 1
$thr = $false; try { & ([scriptblock]::Create("`$fixState='確かめ待ち（報告か注文か）'; `$NoDrafts=`$false; `$fixNote=@('x')`n" + $thAst.Extent.Text)) } catch { $thr = $true }
T 'T34' '【案】確かめ待ちの催事で下書きを作ろうとすると止まる' $thr ''

# ===== 会期終了後の制御 =====
$dd = [pscustomobject]@{ 会期終了 = '2026-11-04' }
T 'T35' '【案】会期が終わったかの判定：11/04終了で 10/31・11/04 は「まだ」、11/05 は「終わった」、日付が読めない時は「まだ」' (-not (Test-KaikiOwatta $dd ([datetime]'2026-10-31')) -and -not (Test-KaikiOwatta $dd ([datetime]'2026-11-04')) -and (Test-KaikiOwatta $dd ([datetime]'2026-11-05')) -and -not (Test-KaikiOwatta ([pscustomobject]@{ 会期終了 = '未定' }) ([datetime]'2026-11-05'))) ''
$baOrig = Get-Content "$ORIG/board_action.ps1" -Raw -Encoding UTF8; $bbOrig = Get-Content "$ORIG/board_build.ps1" -Raw -Encoding UTF8; $pbfOrig = Get-Content "$ORIG/process_budget_files.ps1" -Raw -Encoding UTF8
T 'T36' '【今のコード】会期終了で下書き・送信を止める処理は3ファイルのどこにも無い（確認）' (-not ($baOrig + $bbOrig + $pbfOrig -match '会期終了\s*-lt|会期終了.*Get-Date|会期が終わ')) '会期終了を今日と比べる行が0'

function Run-Ba([string]$r0, [string]$act, [string]$aite, [string]$st = '') {
    $af = "$r0/alert.txt"; if (Test-Path $af) { Remove-Item $af }; if (Test-Path "$r0/発注案/発注ボード_操作記録.txt") { Remove-Item "$r0/発注案/発注ボード_操作記録.txt" }
    $env:HACCHU_NO_ALERT = '1'; $env:HACCHU_ALERT_FILE = $af
    $o = & pwsh -NoProfile -File "$r0/仕組み/board_action.ps1" -Action $act -CaseHex (Hx $ID) -AiteHex (Hx $aite) -State $st -Config "$r0/仕組み/board_config.json" 2>&1 | Out-String
    $env:HACCHU_NO_ALERT = $null; $env:HACCHU_ALERT_FILE = $null
    $al = $(if (Test-Path $af) { Get-Content $af -Raw -Encoding UTF8 } else { '' })
    $lg = $(if (Test-Path "$r0/発注案/発注ボード_操作記録.txt") { Get-Content "$r0/発注案/発注ボード_操作記録.txt" -Raw -Encoding UTF8 } else { '' })
    return [pscustomobject]@{ out = $o; alert = $al; log = $lg }
}
function Set-Row([string]$r0, [hashtable]$row, [string]$kaiki = '2026-11-04') {
    $L = Get-Content "$r0/発注案/$ID.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    $c = $L.候補[0]; foreach ($k in $row.Keys) { $c | Add-Member -NotePropertyName $k -NotePropertyValue $row[$k] -Force }
    $L.会期終了 = $kaiki; WJ "$r0/発注案/$ID.json" $L
}
$r0 = New-Sandbox 'ba'
Set-Row $r0 @{ 状態 = '一部は現場が発注済み' }; $b = Run-Ba $r0 'draft' 'セニヤ'
T 'T37' '【案・実行】ba draft：「一部は現場が発注済み」の行 → 下書きを作らない（熊田さんの関門・Outlook の前で止まる）' ($b.log -match 'draft 中止（済み・現場の判定で止めた行 一部は現場が発注済み）') (($b.alert -split "`r?`n")[0])
Set-Row $r0 @{ 状態 = '現場が発注済み' }; $b = Run-Ba $r0 'draft' 'セニヤ'
T 'T38' '【案・実行】ba draft：完了（現場が発注済み）の行 → 下書きを作らない（今は画面のボタンを隠すだけ）' ($b.log -match 'draft 中止（済み・現場の判定で止めた行 現場が発注済み）') ''
Set-Row $r0 @{ 状態 = '送った' }; $b = Run-Ba $r0 'draft' 'セニヤ'
T 'T39' '【案・実行】ba draft：送った の行 → 下書きを作らない' ($b.log -match 'draft 中止（済み・現場の判定で止めた行 送った）') ''
Set-Row $r0 @{ 状態 = '候補' }; $b = Run-Ba $r0 'draft' 'セニヤ'
T 'T40' '【案・実行・陽性対照】ba draft：候補の行・会期中 → 歯止めを通って次へ進む' ($b.log -notmatch 'draft 中止（済み|draft 中止（会期') (('進んだ先：' + (($b.log + $b.alert + $b.out) -split "`r?`n" | Where-Object { $_ } | Select-Object -Last 1)) -replace '\s+$', '').Substring(0, [Math]::Min(80, ('進んだ先：' + (($b.log + $b.alert + $b.out) -split "`r?`n" | Where-Object { $_ } | Select-Object -Last 1)).Length))
Set-Row $r0 @{ 状態 = '候補' } '2026-10-30'; $b = Run-Ba $r0 'draft' 'セニヤ'
T 'T41' '【案・実行】ba draft：会期が終わった催事（10/30終了）→ 下書きを作らない' ($b.log -match 'draft 中止（会期が終わった）') (($b.alert -split "`r?`n")[0])
Set-Row $r0 @{ 状態 = '下書き済'; EntryID = 'X1'; StoreID = 'S1' } '2026-10-30'; $b = Run-Ba $r0 'open' 'セニヤ'
T 'T42' '【案・実行】ba open：会期が終わった催事の残った下書き → 開かせない' ($b.log -match 'open 中止（会期が終わった）') ''
# 数を確かめた・戻す
Set-Row $r0 @{ 状態 = '現場が発注済み'; EntryID = ''; 現場の照合 = $gAll.現場の照合 }; $b = Run-Ba $r0 'mark' 'セニヤ' '数を確かめた'
$L = Get-Content "$r0/発注案/$ID.json" -Raw -Encoding UTF8 | ConvertFrom-Json
T 'T43' '【案・実行】ba mark［数を確かめた］→ 照合の数＝確認済み・状態は現場が発注済みのまま' ($L.候補[0].現場の照合.数 -eq '確認済み' -and $L.候補[0].状態 -eq '現場が発注済み') ('数=' + $L.候補[0].現場の照合.数 + ' 状態=' + $L.候補[0].状態)
Set-Row $r0 @{ 状態 = '現場が発注済み' }; $b = Run-Ba $r0 'mark' 'セニヤ' '候補'
$L = Get-Content "$r0/発注案/$ID.json" -Raw -Encoding UTF8 | ConvertFrom-Json
T 'T44' '【案・実行】誤って成立した完了の訂正：ba mark［戻す］→ 候補・「現場の判定を外した」（時刻・前の状態・前の記録）が残る' ($L.候補[0].状態 -eq '候補' -and $L.候補[0].現場の判定を外した.前の状態 -eq '現場が発注済み' -and [bool]$L.候補[0].現場の判定を外した.日時) ('外した日時=' + $L.候補[0].現場の判定を外した.日時)
$r = Resolve-GenbaState -State '候補' -Old $L.候補[0] -Hantei $hAll -Naka $naka
T 'T45' '【案】訂正した行に、次の回で同じ根拠が来ても完了に戻らない（つながりの確認）' ($r.状態 -eq '候補') $r.理由
Set-Row $r0 @{ 状態 = '一部は現場が発注済み'; 現場の照合 = $g.現場の照合 }; $b = Run-Ba $r0 'mark' 'セニヤ' '現場が発注済み'
$L = Get-Content "$r0/発注案/$ID.json" -Raw -Encoding UTF8 | ConvertFrom-Json
T 'T46' '【案・実行】一部の行で人が［全部 現場で発注済み］→ 完了・照合は「人が決めた」・数は未確認' ($L.候補[0].状態 -eq '現場が発注済み' -and $L.候補[0].現場の照合.区分 -like '人が決めた*' -and $L.候補[0].現場の照合.数 -eq '未確認') $L.候補[0].現場の照合.区分

# 画面（board_build の Btn-For）
$bbSb = [scriptblock]::Create(". '$NEW/genba_hantei.ps1'`n`$DONE=@('送った','電話した','不要','倉庫から出した','現場が発注済み'); `$STUCK=@('送ったか確かめて','⚠二重に送っています','送信トレイで止まっています','⚠古い中身で送っています')`n" + (FuncsFrom "$NEW/board_build.ps1") + "`nBtn-For `$args[0] `$args[1]")
$h1 = & $bbSb ([pscustomobject]@{ 案件ID = $ID; 会期終了 = '2026-10-30'; 下書き可 = $true }) ([pscustomobject]@{ 相手 = 'セニヤ'; 状態 = '候補'; 方法 = 'FAX' })
$h2 = & $bbSb ([pscustomobject]@{ 案件ID = $ID; 会期終了 = '2026-11-04'; 下書き可 = $true }) ([pscustomobject]@{ 相手 = 'セニヤ'; 状態 = '一部は現場が発注済み'; 方法 = 'FAX'; 現場の照合 = $g.現場の照合 })
$h3 = & $bbSb ([pscustomobject]@{ 案件ID = $ID; 会期終了 = '2026-11-04'; 下書き可 = $true }) ([pscustomobject]@{ 相手 = 'セニヤ'; 状態 = '候補'; 方法 = 'FAX' })
T 'T47' '【案】画面：会期が終わった催事は下書きボタンを出さない／一部の行は止めたボタン／会期中の候補は今までどおり' ($h1 -notmatch "act\('draft'" -and $h1 -match '会期が終わった' -and $h2 -match '全部 現場で発注済み' -and $h2 -notmatch "act\('draft'" -and $h3 -match "act\('draft'") ''

''
$ng = @($global:KEKKA | Where-Object { -not $_.ok })
"合計 {0} 件／通った {1} 件／落ちた {2} 件" -f $global:KEKKA.Count, ($global:KEKKA.Count - $ng.Count), $ng.Count
[IO.File]::WriteAllText("$KZ/tests/result_ps.json", ($global:KEKKA | ConvertTo-Json -Depth 3))
