# SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
"""Compare what the indicator drew (DumpIndicator CSVs on MT5, Dump4 CSVs on MT4) with tests/reference.py, bar by bar.

    python3 tests/check_parity.py <dump dir>          (needs numpy and pandas; looks in <dump dir>/dump)
    python3 tests/check_parity.py <dump dir> --mt4    (the MT4 edition, dumps from the MT4 tester)

Buffers: b0 bullish arrow, b1 bearish arrow, b2/b3 their pattern bit masks (1 ABCD, 2 Gartley, 4 Bat).
The indicator scans the last InpHistory closed bars (start = bars - 1 - history) and never the forming bar.
Pass: arrows on the same bars with the same pattern masks."""
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).parent))
from reference import Params, run  # noqa: E402

FREE = (True, True, True)
HEAD = "s:Patterns|b:{a}|b:{g}|b:{b}|s:Swings and ratios|i:{l}|i:{r}|d:{t}|d:{z}|s:Display|i:{h}|b:true|b:true|b:true|c:6465062|c:4606690|s:Alerts|b:false|b:false|s:alert.wav|b:false|b:false"
CONFIGS = {  # tag: (Params, history, DumpIndicator InpParams for MT5 in input order; each group counts) - as tests/configs.tsv
    "hm_default": (Params(use=FREE), 3000, HEAD.format(a="true", g="true", b="true", l=10, r=5, t="5.0", z="3.0", h=3000)),
    "hm_all_loose": (Params(left=6, right=3, tol=0.08, prz=0.04, use=FREE), 5000,
                     HEAD.format(a="true", g="true", b="true", l=6, r=3, t="8.0", z="4.0", h=5000)),
    "hm_gartley": (Params(left=5, right=2, use=(False, True, False)), 3000,
                   HEAD.format(a="false", g="true", b="false", l=5, r=2, t="5.0", z="3.0", h=3000)),
}


def num(col):
    return pd.to_numeric(col, errors="coerce").to_numpy(float)


def check(csv: Path, pr: Params, hist: int, mt4=False):
    d = pd.read_csv(csv)
    n = len(d)
    # MT4 tester: the indicator was attached with far fewer than InpHistory bars, so it scans from bar 0 and keeps feeding
    start = 0 if mt4 else max(0, n - 1 - hist)
    h, l, c = (d[k].to_numpy(float)[start:n - 1] for k in ("high", "low", "close"))
    ev = run(h, l, c, pr)
    msgs, ok = [], True
    for b, mb, dr, name in (("b0", "b2", 1, "bull"), ("b1", "b3", -1, "bear")):
        ref = {}
        for e in ev:
            if e["dir"] == dr:
                ref[start + e["bar"]] = ref.get(start + e["bar"], 0) | (1 << e["pat"])
        arr = num(d[b])
        mt_bars = [int(i) for i in np.flatnonzero(~np.isnan(arr)) if start <= i < n - 1]
        mt = {i: int(num(d[mb])[i]) for i in mt_bars}
        same = mt == ref
        ok &= same
        msgs.append(f"{name} {len(ref):>3} {'OK' if same else f'DIFFER (mt5 {len(mt)})'}")
        if not same:
            diff = sorted(set(mt.items()) ^ set(ref.items()))[:5]
            msgs.append(f"[first differences {diff}]")
    return ok, f"{csv.stem:38} bars {n:>6} scanned {n - 1 - start:>5}  " + "  ".join(msgs)


if __name__ == "__main__":
    mt4 = "--mt4" in sys.argv          # dumps of the MT4 Strategy Tester run
    root = Path([a for a in sys.argv[1:] if a != "--mt4"][0])
    allok, k = True, 0
    for tag, (pr, hist, _) in CONFIGS.items():
        for f in sorted(root.glob(f"dump/{tag}_*.csv")):
            ok, msg = check(f, pr, hist, mt4)
            allok &= ok
            k += 1
            print(("PASS " if ok else "FAIL ") + msg)
    print(f"\n{'ALL PASS' if allok and k else 'FAILURES'} ({k} files)")
    sys.exit(0 if allok and k else 1)
