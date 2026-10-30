#!/usr/bin/env python3
"""実質財務状況（実態BS）計算スクリプト

freee会計の貸借対照表API（GET /api/1/reports/trial_bs）のレスポンスJSONに、
finance/adjustments.json の評価替えルールを適用し、実質純資産を算出して
Markdownレポートを標準出力に出す。

使い方:
  python3 finance/actual_net_assets.py --trial-bs trial_bs.json --rules finance/adjustments.json
オプション:
  --riot-price-jpy 1234.5      RIOT 1株あたりの円換算価格（ルールに shares がある場合のみ有効）
  --history finance/history.csv 履歴CSVに1行追記する
  --json result.json           計算結果をJSONでも保存する
  --as-of 2026-10-30           基準日（省略時は今日）
"""
import argparse
import csv
import datetime as dt
import json
import os
import sys


def load_trial_bs(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if "trial_bs" in data:
        data = data["trial_bs"]
    accounts = {}
    totals = {}
    for b in data["balances"]:
        if b.get("total_line"):
            totals[b["account_category_name"]] = b["closing_balance"]
        elif "account_item_name" in b:
            name = b["account_item_name"]
            accounts[name] = accounts.get(name, 0) + b["closing_balance"]
    return accounts, totals, data


def yen(n):
    return f"{n:,}"


def signed(n):
    return f"+{n:,}" if n >= 0 else f"{n:,}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--trial-bs", required=True)
    ap.add_argument("--rules", required=True)
    ap.add_argument("--riot-price-jpy", type=float, default=None)
    ap.add_argument("--history", default=None)
    ap.add_argument("--json", dest="json_out", default=None)
    ap.add_argument("--as-of", default=None)
    args = ap.parse_args()

    as_of = dt.date.fromisoformat(args.as_of) if args.as_of else dt.date.today()
    accounts, totals, meta = load_trial_bs(args.trial_bs)
    with open(args.rules, encoding="utf-8") as f:
        rules = json.load(f)

    book_assets = totals.get("資産")
    book_liabilities = totals.get("負債")
    book_na = totals.get("純資産")
    if book_na is None:
        book_na = book_assets - book_liabilities
    current_profit = totals.get("当期純損益金額", 0)

    stale_days = rules.get("policy", {}).get("stale_days", 90)
    rows = []
    warnings = []
    total_delta = 0
    for r in rules["adjustments"]:
        missing = [a for a in r["accounts"] if a not in accounts]
        if missing:
            warnings.append(f"科目が見つからない: {', '.join(missing)}（ルール {r['id']}）")
        book = sum(accounts.get(a, 0) for a in r["accounts"])
        value = r["value"]
        status = ""
        market = r.get("market")
        if market and market.get("shares") and args.riot_price_jpy:
            value = round(market["shares"] * args.riot_price_jpy)
            status = f"時価計算 {market['shares']}株×{args.riot_price_jpy:,.2f}円"
        elif market and market.get("shares") and not args.riot_price_jpy:
            warnings.append(f"{r['label']}: 株数は設定済みだが --riot-price-jpy 未指定のため固定値を使用")
        if r["mode"] == "fair_value":
            fair = value
            delta = fair - book
        elif r["mode"] == "delta":
            delta = value
            fair = book + delta
        else:
            raise SystemExit(f"unknown mode: {r['mode']}")
        age = (as_of - dt.date.fromisoformat(r["as_of"])).days
        if age > stale_days and not status:
            status = f"要更新（基準日から{age}日）"
            warnings.append(f"{r['label']}: 評価の基準日 {r['as_of']} から{age}日経過。更新が必要。")
        total_delta += delta
        rows.append({
            "id": r["id"], "label": r["label"], "accounts": r["accounts"],
            "mode": r["mode"], "book": book, "fair": fair, "delta": delta,
            "as_of": r["as_of"], "source": r.get("source", ""), "status": status,
            "note": r.get("note", ""),
        })

    adj_na = book_na + total_delta
    adj_assets = book_assets + total_delta
    verdict = "資産超過" if adj_na >= 0 else "債務超過"

    out = []
    out.append(f"# 実質財務状況（実態BS） 基準日 {as_of.isoformat()}")
    out.append("")
    out.append(f"**結論：{yen(abs(adj_na))}円の{verdict}**（帳簿純資産 {yen(book_na)}円 に評価替え {signed(total_delta)}円）")
    out.append("")
    out.append("## データの出所")
    out.append(f"- freee 事業所ID {meta.get('company_id')}、会計年度 {meta.get('fiscal_year')}、取得時刻 {meta.get('created_at')}")
    out.append("- 貸借対照表の本日時点残高（当期の未確定利益を含む）")
    out.append("")
    out.append("## 前提（評価替えルール）")
    out.append("| 項目 | 対象科目 | 方式 | 評価額／増減 | 基準日 | 出典 | 状態 |")
    out.append("|---|---|---|---:|---|---|---|")
    for r in rows:
        v = yen(r["fair"]) if r["mode"] == "fair_value" else signed(r["delta"])
        out.append(f"| {r['label']} | {'＋'.join(r['accounts'])} | {'評価額で置換' if r['mode']=='fair_value' else '固定増減'} | {v} | {r['as_of']} | {r['source']} | {r['status']} |")
    out.append("")
    out.append("## 計算式")
    out.append(rules.get("policy", {}).get("formula", "実質純資産 = 帳簿純資産 + Σ(評価額 − 簿価)"))
    out.append("")
    out.append("## 調整明細")
    out.append("| 項目 | 簿価 | 実質評価額 | 差額 |")
    out.append("|---|---:|---:|---:|")
    for r in rows:
        out.append(f"| {r['label']} | {yen(r['book'])} | {yen(r['fair'])} | {signed(r['delta'])} |")
    out.append(f"| **調整合計** | | | **{signed(total_delta)}** |")
    out.append("")
    out.append("## 要約")
    out.append("| 区分 | 帳簿 | 実質 |")
    out.append("|---|---:|---:|")
    out.append(f"| 資産合計 | {yen(book_assets)} | {yen(adj_assets)} |")
    out.append(f"| 負債合計 | {yen(book_liabilities)} | {yen(book_liabilities)} |")
    out.append(f"| **純資産** | **{yen(book_na)}** | **{yen(adj_na)}** |")
    out.append("")
    out.append("## 注記")
    out.append(f"- 帳簿純資産には当期純損益 {signed(current_profit)}円（期中・未確定）が含まれる。")
    for n in rules.get("policy", {}).get("notes", []):
        out.append(f"- {n}")
    for w in warnings:
        out.append(f"- ⚠ {w}")
    print("\n".join(out))

    result = {
        "as_of": as_of.isoformat(), "book_assets": book_assets, "book_liabilities": book_liabilities,
        "book_net_assets": book_na, "total_delta": total_delta, "adjusted_net_assets": adj_na,
        "verdict": verdict, "current_profit": current_profit, "rows": rows, "warnings": warnings,
        "freee": {"company_id": meta.get("company_id"), "fiscal_year": meta.get("fiscal_year"), "created_at": meta.get("created_at")},
    }
    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8") as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
    if args.history:
        new = not os.path.exists(args.history)
        with open(args.history, "a", encoding="utf-8", newline="") as f:
            w = csv.writer(f)
            if new:
                w.writerow(["as_of", "book_assets", "book_liabilities", "book_net_assets", "total_delta", "adjusted_net_assets", "verdict"])
            w.writerow([as_of.isoformat(), book_assets, book_liabilities, book_na, total_delta, adj_na, verdict])
    return 0


if __name__ == "__main__":
    sys.exit(main())
