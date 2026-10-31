# genba_hantei.ps1 — 現場の発注（LINE の1タップ・まとめ）を、台帳の行の「品ごと」に当てる。第12版 2章（社内グループの発言＝品×出来事ごと）・決10（受付と成立を分ける）
# 2026-10-31 草案（発注チェーンの点検・本番未投入）。ここには関数だけを置く：ファイルを読まない・書かない・時計は引数で受ける。
#   使う所＝process_budget_files.ps1（判定）・board_action.ps1（下書きの裏の歯止め・人の［戻す］）・board_build.ps1（画面のボタン）
$GENBA_HOLD = @('一部は現場が発注済み', '現場の発注が取り消された・確かめ待ち')   # 下書きを作らない止まり。DONE（済み）でも候補でもない＝「残り」に数える

function Norm-VenueG([string]$s) { return ([string]$s -replace '[\s　㈱株式会社（）\(\)]', '') }
function Get-HinCore([string]$part) { return ((([string]$part -replace '[【】（）\(\)○◎●・※\s　]', '') -split '[0-9０-９]')[0]) }
function Get-NichijiG([string]$s) { if ([string]$s -match '(\d{4}-\d{2}-\d{2} \d{2}:\d{2})') { return [datetime]$Matches[1] } return $null }

# 1品の根拠を探す。当て方は今の Ittap-Done／Genba-Done と同じ（案件IDがあればその催事だけ・無ければ会場名・1タップは相手の欄があればその相手だけ）
function Get-GenbaKonkyo {
    param([string]$Id, [string]$Venue, [string]$Aite, [string]$Core, $Ittap, $Genba)
    $v = Norm-VenueG $Venue
    foreach ($t in @($Ittap)) {
        if (-not $t -or [string]$t.種別 -ne '発注完了') { continue }
        if ([string]$t.相手 -and $Aite -and [string]$t.相手 -ne $Aite) { continue }
        $same = $false
        if ([string]$t.案件ID) { $same = ([string]$t.案件ID -eq $Id) }
        elseif ($t.会場) { $tv = Norm-VenueG ([string]$t.会場); if ($tv -and $v -and ($v.Contains($tv) -or $tv.Contains($v))) { $same = $true } }
        if (-not $same) { continue }
        $body = ([string]$t.もとの発言 -replace '[【】（）\(\)○◎●・※\s　]', '')
        if ($body.Contains($Core)) { return [pscustomobject]@{ 種類 = '1タップ'; 決め方 = [string]$(if ($t.決め方) { $t.決め方 } else { 'ボタン' }); 日時 = [string]$t.日時; だれが = [string]$t.だれが; 鍵 = ('1タップ|' + [string]$t.id) } }
    }
    if (-not $v) { return $null }   # 今の Genba-Done と同じ（会場が空なら当てない）
    foreach ($g in @($Genba)) {
        if (-not $g) { continue }
        if ([string]$g.案件ID) { if ([string]$g.案件ID -ne $Id) { continue } }
        else { $gv = Norm-VenueG ([string]$g.会場); if (-not $gv -or -not ($v.Contains($gv) -or $gv.Contains($v))) { continue } }
        $honbun = $(if ($g.照合用) { [string]$g.照合用 } else { [string]$g.本文 })
        $bodyC = ($honbun -replace '[【】（）\(\)○◎●・※\s　]', '')
        if ($bodyC.Contains($Core)) { return [pscustomobject]@{ 種類 = 'まとめ'; 決め方 = '本文から読み取り'; 日時 = [string]$g.日時; だれが = [string]$g.だれが; 鍵 = ('まとめ|' + [string]$g.日時 + '|' + [string]$g.会場) } }
    }
    return $null
}

# 行の品ごとに当てる。区分＝全品／一部／無し。品名の核が3文字に満たない品は当てない（今と同じ）＝「当たらない」に数える
function Get-GenbaHantei {
    param([string]$Id, [string]$Venue, [string]$Naka, [string]$Aite, $Ittap, $Genba)
    $atari = @(); $hazure = @()
    foreach ($part in ([string]$Naka -split '／')) {
        $p = $part.Trim(); if (-not $p) { continue }
        $core = Get-HinCore $p
        $k = $null
        if ($core.Length -ge 3) { $k = Get-GenbaKonkyo -Id $Id -Venue $Venue -Aite $Aite -Core $core -Ittap $Ittap -Genba $Genba }
        if ($k) { $atari += [pscustomobject]@{ 品 = $p; 核 = $core; 根拠 = $k } } else { $hazure += $p }
    }
    $kubun = $(if (-not $atari.Count) { '無し' } elseif (-not $hazure.Count) { '全品' } else { '一部' })
    return [pscustomobject]@{ 区分 = $kubun; 当たった = @($atari); 当たらない = @($hazure) }
}

# 明示的な取消・訂正だけを拾う。①1タップの記録の「取消」「数量変更」（熊田さんの公式の修正）②予定の直しの「頼んだ分を減らした」。どちらも根拠の日時より後の物だけ
function Get-GenbaTorikeshi {
    param([string]$Id, [string]$Aite, $Ittap, $Naoshi, $Old)
    $konkyoAt = $null
    if ($Old -and $Old.現場の照合) { foreach ($a in @($Old.現場の照合.当たった品)) { $d0 = Get-NichijiG ([string]$a.根拠.日時); if ($d0 -and (-not $konkyoAt -or $d0 -gt $konkyoAt)) { $konkyoAt = $d0 } } }
    if (-not $konkyoAt -and $Old) { $konkyoAt = Get-NichijiG ([string]$Old.現場の記録) }
    if (-not $konkyoAt -and $Old) { $konkyoAt = Get-NichijiG ([string]$Old.日時) }
    foreach ($t in @($Ittap)) {
        if (-not $t -or [string]$t.種別 -notin @('取消', '数量変更')) { continue }
        if ([string]$t.案件ID -ne $Id) { continue }
        if ([string]$t.相手 -and [string]$t.相手 -ne $Aite) { continue }
        $tAt = Get-NichijiG ([string]$t.日時)
        if ($konkyoAt -and $tAt -and $tAt -le $konkyoAt) { continue }
        return [pscustomobject]@{ 種類 = [string]$t.種別; 日時 = [string]$t.日時; だれが = [string]$t.だれが; もとの発言 = [string]$t.もとの発言 }
    }
    foreach ($n in @($Naoshi)) {
        if (-not $n -or [string]$n.種別 -ne '頼んだ分を減らした') { continue }
        if ([string]$n.行.頼む先 -ne $Aite) { continue }
        $nAt = $null; try { $nAt = [datetime]([string]$n.いつ) } catch {}
        if ($konkyoAt -and $nAt -and $nAt -le $konkyoAt) { continue }
        return [pscustomobject]@{ 種類 = '頼んだ分を減らした'; 日時 = [string]$n.いつ; だれが = [string]$n.誰が; もとの発言 = [string]$n.ファイル }
    }
    return $null
}

# 状態を決める。戻すのは取消・訂正の記録と人の［戻す］だけ。根拠が消えた・読めない・取り込み漏れでは完了を戻さない
function Resolve-GenbaState {
    param([string]$State, $Old, $Hantei, $Torikeshi = $null, [string]$Naka = '', [bool]$NyuuguchiOK = $true, [string]$Ima = '')
    if (-not $Ima) { $Ima = (Get-Date -Format 'yyyy-MM-dd HH:mm') }
    $sh = $(if ($Old) { $Old.現場の照合 } else { $null })
    $res = [ordered]@{ 状態 = $State; 現場の記録 = [string]$(if ($Old) { $Old.現場の記録 } else { '' }); 現場の照合 = $sh; 理由 = '' }
    if (-not $NyuuguchiOK) { $res.理由 = '入口が読めない回＝変えない'; return [pscustomobject]$res }
    $hz = $(if ($Old) { $Old.現場の判定を外した } else { $null })
    $hzAt = $(if ($hz) { Get-NichijiG ([string]$hz.日時) } else { $null })
    $mk = {
        param($h, [string]$kubun)
        [pscustomobject][ordered]@{ 区分 = $kubun; 数 = '未確認'; 当たった品 = @($h.当たった | ForEach-Object { [pscustomobject][ordered]@{ 品 = $_.品; 核 = $_.核; 根拠 = $_.根拠 } }); 当たらない品 = @($h.当たらない); 決めた日時 = $Ima }
    }
    $kirokuOf = {
        param($h)
        $k0 = @($h.当たった | Select-Object -First 1)[0].根拠
        $atama = $(if ($k0.種類 -eq '1タップ' -and $k0.決め方 -eq 'ボタン') { '本人が押しました ' } elseif ($k0.種類 -eq '1タップ') { '本人の発言から読み取り・押されていません ' } else { 'LINE ' })
        '現場が発注済み（' + $atama + [string]$k0.日時 + '・' + [string]$k0.だれが + '）'
    }
    switch ($State) {
        '候補' {
            if ($Hantei.区分 -eq '無し') { $res.理由 = '当たる記録なし'; break }
            if ($hzAt) {
                # 人が［戻す］で外した後は、その時までの根拠では当て直さない。外した後に来た根拠だけを数える
                $shin = @($Hantei.当たった | Where-Object { $d1 = Get-NichijiG ([string]$_.根拠.日時); $d1 -and $d1 -gt $hzAt })
                if (-not $shin.Count) { $res.理由 = '人が外した時までの根拠だけ＝当て直さない'; break }
            }
            if ($Hantei.区分 -eq '全品') { $res.状態 = '現場が発注済み'; $res.現場の照合 = (& $mk $Hantei '全品の品名が一致（数は未確認）'); $res.現場の記録 = (& $kirokuOf $Hantei); $res.理由 = '全品の品名が一致' }
            else { $res.状態 = '一部は現場が発注済み'; $res.現場の照合 = (& $mk $Hantei '一部の品名が一致'); $res.現場の記録 = ('一部は' + (& $kirokuOf $Hantei)); $res.理由 = '一部の品名が一致＝下書きを作らない' }
        }
        '現場が発注済み' {
            if ($Torikeshi) { $res.状態 = '現場の発注が取り消された・確かめ待ち'; $res.現場の記録 = ('取消・訂正が届いた（' + $Torikeshi.種類 + ' ' + $Torikeshi.日時 + '・' + $Torikeshi.だれが + '）＝前の記録：' + [string]$res.現場の記録); $res.理由 = '明示的な取消・訂正'; break }
            $res.理由 = '完了のまま（根拠が見えなくても戻さない）'
            if (-not $sh -and $Hantei.区分 -eq '全品') { $res.現場の照合 = (& $mk $Hantei '全品の品名が一致（数は未確認）') }   # 今までの行に照合を足すだけ。状態は変えない
        }
        '一部は現場が発注済み' {
            if ($Torikeshi) { $res.状態 = '現場の発注が取り消された・確かめ待ち'; $res.理由 = '明示的な取消・訂正'; break }
            if ($Hantei.区分 -eq '全品') { $res.状態 = '現場が発注済み'; $res.現場の照合 = (& $mk $Hantei '全品の品名が一致（数は未確認）'); $res.現場の記録 = (& $kirokuOf $Hantei); $res.理由 = '残りの品も当たった'; break }
            # 済んだ品（前に当たった品）が予定から全部外れた時だけ、残りを下書きにできる候補へ戻す。根拠が消えただけ（期間経過など）では戻さない
            $flat = ([string]$Naka -replace '[【】（）\(\)○◎●・※\s　]', '')
            $mae = @(if ($sh) { @($sh.当たった品 | ForEach-Object { [string]$_.核 } | Where-Object { $_ }) })
            $nokori = @($mae | Where-Object { $flat.Contains($_) })
            if ($mae.Count -and -not $nokori.Count) { $res.状態 = '候補'; $res.現場の記録 = ('済んだ品は予定から外した（' + (@($sh.当たった品 | ForEach-Object { [string]$_.品 }) -join '・') + '）'); $res.理由 = '済んだ品が予定から外れた＝残りだけ下書きにできる' }
            else { $res.理由 = '済んだ品がまだ予定に残っている＝止めたまま' }
        }
        default { $res.理由 = '触らない状態' }   # 送った・電話した・不要・倉庫から出した・下書き済・取消の確かめ待ち・止まっている状態＝今と同じく触らない
    }
    return [pscustomobject]$res
}

# 会期が終わった催事か（会期終了の日の翌日から）。会期終了が読めない時は false（今までどおり）
function Test-KaikiOwatta {
    param($Doc, [datetime]$Today = (Get-Date).Date)
    $e = $null; try { $e = ([datetime][string]$Doc.会期終了).Date } catch { return $false }
    return ($e -lt $Today.Date)
}
