# line_hacchu_import.py の回帰テスト（本番から隔離：一時フォルダだけ。LINE のまとめの場所・発注案の場所を差し替える）
import importlib.util, io, json, os, sys, tempfile, hashlib, contextlib
K = '/tmp/w/kaizen'
res = []
def T(i, name, ok, d=''):
    res.append((i, ok)); print(('PASS' if ok else 'FAIL'), i, name, ('— ' + d) if d else '')
def load(path, tmp):
    spec = importlib.util.spec_from_file_location('lhi_' + os.path.basename(os.path.dirname(path)), path)
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    logd = os.path.join(tmp, 'log'); os.makedirs(logd, exist_ok=True)
    m.LOG_DIR = logd; m.PLAN = tmp; m.OUT = os.path.join(tmp, '_LINEで発注済み.json'); m.load_places = lambda: {}
    return m
def h(p): return hashlib.sha256(open(p, 'rb').read()).hexdigest()
ittap_row = {'日時': '2026-10-30 10:00', '会場': '京阪百貨店ひらかた店', 'だれが': '尾崎', '出どころ': '1タップ', '本文': 'セニヤ 発注しました'}
cases = [('P1', '前回の記録が0バイト', b''), ('P2', '前回の記録の JSON が壊れている', '{"発注完了":[{"日時":'.encode('utf-8')),
         ('P3', '前回の記録に「発注完了」の欄が無い', json.dumps({'説明': '書きかけ'}, ensure_ascii=False).encode('utf-8'))]
for ver in ('orig', 'new'):
    for i, nm, body in cases:
        with tempfile.TemporaryDirectory() as tmp:
            m = load(f'{K}/{ver}/line_hacchu_import.py', tmp)
            open(m.OUT, 'wb').write(body); b = h(m.OUT)
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf): rc = m.main()
            same = h(m.OUT) == b
            if ver == 'orig':
                T(i + '-今', f'【今のコード】{nm} → 黙って上書きする（再現）', (not same) and rc in (None, 0), f'rc={rc} 上書き={"した" if not same else "しない"}')
            else:
                T(i + '-案', f'【案】{nm} → 上書きしない・3を返す・⛔を出す', same and rc == 3 and '⛔' in buf.getvalue(), f'rc={rc} 上書き={"した" if not same else "しない"}')
for ver in ('orig', 'new'):
    with tempfile.TemporaryDirectory() as tmp:
        m = load(f'{K}/{ver}/line_hacchu_import.py', tmp)
        json.dump({'発注完了': [ittap_row], '返事待ちの依頼': []}, io.open(m.OUT, 'w', encoding='utf-8-sig'), ensure_ascii=False)
        with contextlib.redirect_stdout(io.StringIO()): rc = m.main()
        kept = [r for r in json.load(io.open(m.OUT, encoding='utf-8-sig'))['発注完了'] if r.get('出どころ') == '1タップ']
        T('P4-' + ('今' if ver == 'orig' else '案'), f'【{"今のコード" if ver == "orig" else "案"}・陽性対照】前回の記録が正常 → 書き直し、1タップ由来の行は残す', rc in (None, 0) and len(kept) == 1, f'rc={rc} 残った1タップ行={len(kept)}')
ng = [x for x in res if not x[1]]
print(f'合計 {len(res)} 件／通った {len(res)-len(ng)} 件／落ちた {len(ng)} 件')
