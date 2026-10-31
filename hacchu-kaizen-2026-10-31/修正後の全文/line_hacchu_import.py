# -*- coding: utf-8 -*-
r"""LINEのやりとりから「もう発注した／発注を頼まれた」を拾って、発注ボードに出す。

なぜ要るか（2026-09-23 点検役 H1・H2）：
  担当者（新木さんなど）がLINEで熊田さんに直接「これを発注して」と頼み、熊田さんが手で送っている。
  発注ボードはそれを知らないので、あとから同じ品をもう一度「送る」と出す＝二重発注になる。

作り：
  倉庫メインPCにあるLINEのまとめ（ai-kaori の group-digest）を読み、
  G:\...\発注\発注案\_LINEで発注済み.json を書く。熊田さんのPCのボードはこのファイルを読むだけ。
  ※LINEのまとめは倉庫メインPCにしか無いので、この台本は倉庫メインPCで動かす。

使い方： python line_hacchu_import.py
"""
import io
import json
import os
import re
import sys
from datetime import datetime, date

LOG_DIR = r"C:\Users\info\projects\ai-kaori\data\group-digest\log"
SIKUMI = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SIKUMI)
PLAN = os.path.join(ROOT, "発注案")
OUT = os.path.join(PLAN, "_LINEで発注済み.json")
ALIAS = os.path.join(SIKUMI, "LINEの会場の言い方.json")

KUMADA = "合格"          # 熊田さんのLINEの表示名
# LINEの表示名 → 社内での呼び方。分からない人はそのまま出す（勝手に当てない）
NAMES = {"合格": "熊田さん", "氷下魚": "新木さん", "アッキー": "田中さん"}
# ↑ 分かったら足す。間違っていたらここを直す（画面の表示だけに使う。判断には使わない）
DONE_WORDS = ("発注完了", "発注しました", "発注済")
ASK_WORDS = ("発注お願い", "発注願い", "発注します", "仕入お願い", "注文お願い", "発注通して")
# 品物と数量が並んでいる形（・いろりいか54k ／ ・青山ダルマ13kx8 など）。
#   「発注」という言葉が無い頼み方があるので、数量の形でも拾う（2026-09-23 点検役 H1・H2）
# 2026-10-23 発注ボード：掛け算の記号に「✕」（U+2715）「✖」（U+2716）を足す。10/23 15:51 尾崎さんの補填「わさびさきいか 大袋 50✕2」が依頼として拾えず、
#   16:45 の熊田さんの「@尾崎　正俊 発注完了。」も当たらなかった（ひらかたの補填がボードに出なかった）
#   「✖️」は U+2716 の後ろに異体字選択子 U+FE0F が付く（10/15 08:46「13✖️2」・10/16 15:40「50✖️2」）＝記号の後に \ufe0f? を置く（点検役 10/23）
QTY_RE = re.compile(r"(\d+\s*(kg|ｋｇ|k[gxｘ×✕✖]\ufe0f?|ｋ))|(\d+\s*[xX×ｘ✕✖]\ufe0f?\s*\d+)|(c/s)|(\d+\s*(ケース|袋|枚|本|c/s))")
DAYS = 21                # 何日前までを見るか

LINE_RE = re.compile(r"^- (\d{2})/(\d{2}) (\d{2}):(\d{2})【([^】]*)】([^：]*)：(.*)$")


def norm(s):
    """会場名を短くして比べやすくする"""
    for w in ("百貨店", "本店", "スクエア", "店", "　", " "):
        s = s.replace(w, "")
    return s


def load_places():
    """台帳とボード外から、会場の一覧と言い換えを作る"""
    places = {}
    for fn in sorted(os.listdir(PLAN)):
        if not fn.endswith(".json") or fn.startswith("_"):
            continue
        try:
            d = json.load(io.open(os.path.join(PLAN, fn), encoding="utf-8-sig"))
        except Exception:
            continue
        if d.get("会場"):
            # 2026-10-09 調査（10代目ボス）：同じ会場の催事が複数あると最後の1件（2027/2/16）に当たっていた（大介さんの阪神ザンギ 10/1）。
            #   会場ごとに催事を全部持ち、発言の日で選ぶ（会期中→その催事／前→次に始まる催事／全部終わっていれば最後の催事）
            v = places.setdefault(d["会場"], {"案件ID": "", "別名": [], "催事": []})
            v["催事"].append((d.get("会期開始", ""), d.get("会期終了", ""), d.get("案件ID", "")))
    gp = os.path.join(PLAN, "_ボード外.json")
    if os.path.exists(gp):
        try:
            g = json.load(io.open(gp, encoding="utf-8-sig"))
            for r in g.get("行", []):
                places.setdefault(r.get("会場", ""), {"案件ID": "", "別名": []})
        except Exception:
            pass
    places.pop("", None)
    # 手で足した言い換え（無ければ作る）
    al = {}
    if os.path.exists(ALIAS):
        try:
            al = json.load(io.open(ALIAS, encoding="utf-8-sig")).get("言い換え", {})
        except Exception:
            al = {}
    for k, v in places.items():
        v["別名"] = sorted(set([k, norm(k)] + al.get(k, [])), key=len, reverse=True)
    if not os.path.exists(ALIAS):
        io.open(ALIAS, "w", encoding="utf-8-sig").write(json.dumps({
            "説明": "LINEでの会場の言い方。台帳の会場名だけでは拾えないときに、ここへ言い方を足す",
            "言い換え": {k: [] for k in places},
        }, ensure_ascii=False, indent=2))
    return places


def pick_case(info, when):
    kai = sorted(info.get("催事") or [])
    if not kai:
        return info.get("案件ID", "")
    day = when.strftime("%Y-%m-%d")
    for s0, e0, cid in kai:
        if s0 <= day <= (e0 or s0):
            return cid
    for s0, e0, cid in kai:
        if s0 > day:
            return cid
    return kai[-1][2]


def main():
    today = date.today()
    places = load_places()
    rows_done, rows_ask = [], []

    for fn in sorted(os.listdir(LOG_DIR)):
        if not fn.endswith(".md"):
            continue
        year = int(fn.split("-")[0])
        for ln in io.open(os.path.join(LOG_DIR, fn), encoding="utf-8").read().split("\n"):
            m = LINE_RE.match(ln.rstrip())
            if not m:
                continue
            mm, dd, hh, mi, group, who, body = m.groups()
            try:
                when = datetime(year, int(mm), int(dd), int(hh), int(mi))
            except ValueError:
                continue
            if (today - when.date()).days > DAYS or when.date() > today:
                continue
            hits = [(p, i) for p, i in places.items() if any(a and a in body for a in i["別名"])]
            kumada = who.strip() == KUMADA
            is_done = kumada and any(w in body for w in DONE_WORDS)
            suitei = ""
            # 外れを防ぐ2つ（試しで 10/2「近鉄あべの本店 発注完了」が井上に、10/7「@玉井宏生 焼貝ひも（倉庫宛）」が八木橋に当たった）：
            #   ①本文に会場らしい語（百貨店・店名）があるのに一覧に無い＝追っていない会場 → 当てない
            #   ②本文の「@名前」が依頼した人のLINE名と違う → 当てない
            kaijou_rashii = bool(re.search(r"百貨店|本店|高島屋|阪急|阪神|近鉄|大丸|そごう|京阪|イオン|アピタ|倉庫", body))
            at = re.findall(r"@(\S+)", body)
            if not hits and is_done and not kaijou_rashii:
                # 2026-10-09 調査（10代目ボス）：熊田さんの「発注完了。」は会場名が無いことがある（10/1 15:35・10/5 11:02・10/7 11:29ㅻ10/8 15:04）。
                #   同じグループで48時間以内の、いちばん新しい依頼の会場に当てる（推定＝「会場の推定」に印・台帳の側は推測として扱う）
                mae = [a for a in rows_ask if a["グループ"] == group and a["日時"] <= when.strftime("%Y-%m-%d %H:%M")
                       and (when - datetime.strptime(a["日時"], "%Y-%m-%d %H:%M")).total_seconds() <= 48 * 3600
                       # 2026-10-23 発注ボード：「@尾崎　正俊」は全角空白で切れて「尾崎」になる＝依頼者の LINE名の空白を取って先頭一致で当てる（「@氷下魚」はそのまま当たる）
                       and (not at or any(re.sub(r"[\s\u3000]", "", a.get("LINE名", "")).startswith(x) for x in at))]
                if mae:
                    last = max(a["日時"] for a in mae)
                    hits = [(a["会場"], places.get(a["会場"], {"案件ID": a["案件ID"]})) for a in mae if a["日時"] == last]
                    suitei = "会場名が無いので、同じグループの直前の依頼（" + last + "）の会場に当てた"
            if not hits:
                continue
            # 担当者からの依頼：品物と数量が並んでいるか、頼む言葉が入っている
            is_ask = (not kumada) and (bool(QTY_RE.search(body)) or any(w in body for w in ASK_WORDS))
            if not is_done and not is_ask:
                continue
            for place, info in hits:
                rec = {
                    "会場": place,
                    "案件ID": pick_case(info, when),
                    "日時": when.strftime("%Y-%m-%d %H:%M"),
                    "だれが": NAMES.get(who.strip(), who.strip()),
                    "LINE名": who.strip(),
                    "グループ": group,
                    "本文": body[:300],
                }
                if suitei:
                    rec["会場の推定"] = suitei
                (rows_done if is_done else rows_ask).append(rec)

    # 依頼のうち、そのあとに「発注完了」が出ていないものだけを残す（＝まだ送っていないかもしれない分）
    machi = []
    for a in rows_ask:
        later = [d for d in rows_done if d["会場"] == a["会場"] and d["日時"] >= a["日時"]]
        if not later:
            machi.append(a)

    # 「発注完了」の本文には品名が入らない（例：「@氷下魚 岡山高島屋 ／ 発注完了。」）。
    #   その直前の、同じ会場の依頼（品名が並んでいる投稿）を結び付けて、照合できる文を作る。
    #   台帳の側（process_budget_files.ps1）は「照合用」を見れば品名で当てられる。数量は使わない。
    for dn in rows_done:
        mae = [a for a in rows_ask if a["会場"] == dn["会場"] and a["日時"] <= dn["日時"]]
        mae.sort(key=lambda r: r["日時"])
        moto = mae[-3:]                      # 直前の依頼を最大3件まで
        dn["もとの依頼"] = [{"日時": m["日時"], "だれが": m["だれが"], "本文": m["本文"]} for m in moto]
        dn["照合用"] = dn["本文"] + "".join(" ／ " + m["本文"] for m in moto)
        # 品名らしきもの（・や◎で始まる行の、数量より前の部分）
        hin = []
        for src in [dn["照合用"]]:
            for part in src.split("／"):
                t = part.strip().lstrip("・◎○●※ 　")
                t = re.split(r"[0-9０-９]", t)[0].strip()
                if 2 <= len(t) <= 20 and t not in hin:
                    hin.append(t)
        dn["品名"] = hin

    # 2026-09-28：AIかおりが「LINEの発注完了を1タップで案件に紐づける」を実装する。
    #   その分がこのファイルに入る場合、こちらが丸ごと書き直すと消えてしまう。
    #   自分が作っていない行（出どころが「まとめ」でない行）は、そのまま残す。
    hoka = []
    if os.path.exists(OUT):
        try:
            mae = json.load(io.open(OUT, encoding="utf-8-sig"))
            if not isinstance(mae, dict) or "発注完了" not in mae:
                raise ValueError("発注完了の欄が無い")
            for r in (mae.get("発注完了") or []):
                if r.get("出どころ") and r.get("出どころ") != "まとめ":
                    hoka.append(r)
        except Exception as e:
            # 2026-10-31 草案（発注チェーンの点検 項目3）：前回の記録が読めない時は上書きしない（1タップ由来の行を黙って消さない）。止めて人に上げる
            print("⛔ 前回の記録が読めないので書き換えません：%s（%s）" % (OUT, e))
            return 3
    for r in rows_done:
        r["出どころ"] = "まとめ"          # LINEのまとめから拾った＝写し。数量は使わない
    rows_done = hoka + rows_done

    out = {
        "説明": "LINEで担当者が直接お願いした発注と、熊田さんの『発注完了』。ボードが同じ品をもう一度出さないための見張り",
        "出どころの意味": {"まとめ": "LINEのまとめから拾った写し（推測）", "1タップ": "AIかおりで担当者が押した事実"},
        "更新": datetime.now().strftime("%Y-%m-%d %H:%M"),
        "元": "倉庫メインPCのLINEのまとめ（" + LOG_DIR + "）",
        "何日分": DAYS,
        "使い方": "『発注完了』の行の『照合用』に品名が入っている（本文＋直前の依頼）。台帳の側はこれで品名を当てる。数量は使わない",
        "発注完了": sorted(rows_done, key=lambda r: r["日時"], reverse=True),
        "返事待ちの依頼": sorted(machi, key=lambda r: r["日時"], reverse=True),
    }
    io.open(OUT, "w", encoding="utf-8-sig").write(json.dumps(out, ensure_ascii=False, indent=2))
    print("発注完了 %d件 / 返事待ちの依頼 %d件 → %s" % (len(rows_done), len(machi), OUT))
    for r in out["発注完了"][:8]:
        print("  [完了] %s %s %s" % (r["日時"], r["会場"], r["だれが"]))
    for r in out["返事待ちの依頼"][:8]:
        print("  [待ち] %s %s %s" % (r["日時"], r["会場"], r["だれが"]))


def run_shusei():
    """2026-10-08 熊田さん（合格）の取消・数量変更を発注案へ当てる（line_shusei_import.py）。同じ回の process_budget_files に乗せるためここで呼ぶ。失敗してもこの台本は止めない"""
    import subprocess
    try:
        r = subprocess.run([sys.executable, "-X", "utf8", os.path.join(os.path.dirname(os.path.abspath(__file__)), "line_shusei_import.py")], capture_output=True, text=True, encoding="utf-8", timeout=300)
        msg = (r.stdout or "").strip() or ("LINEの修正：失敗 " + (r.stderr or "")[:300])
        try:
            print(msg)
        except UnicodeEncodeError:
            print(msg.encode(sys.stdout.encoding or "utf-8", "replace").decode(sys.stdout.encoding or "utf-8"))
    except Exception as e:
        print("LINEの修正：呼べず", e)


if __name__ == "__main__":
    rc = main()
    run_shusei()
    sys.exit(rc)
