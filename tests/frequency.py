# SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
"""Count completed patterns per 1,000 closed bars from the OHLC columns of dump CSVs (aggregate numbers only).

    python3 tests/frequency.py <dump dir> M15 H1 H4 > docs/data/pattern-frequency.json
Reads <dump dir>/dump/hm_default_<SYMBOL>_<TF>.csv; every closed bar is scanned with tests/reference.py (default inputs)."""
import json
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).parent))
from reference import NAMES, Params, run  # noqa: E402

root = Path(sys.argv[1])
result = {}
for tf in sys.argv[2:]:
    bars = 0
    cnt = {n: [0, 0] for n in NAMES}                  # bullish, bearish
    per_symbol = {}
    for f in sorted(root.glob(f"dump/hm_default_*_{tf}.csv")):
        d = pd.read_csv(f)
        h, l, c = (d[k].to_numpy(float)[:-1] for k in ("high", "low", "close"))
        ev = run(h, l, c, Params())
        for e in ev:
            cnt[e["name"]][0 if e["dir"] > 0 else 1] += 1
        sym = f.stem.split("_")[2]
        per_symbol[sym] = dict(bars=len(c), patterns=len(ev))
        bars += len(c)
    total = sum(sum(v) for v in cnt.values())
    result[tf] = dict(closed_bars=bars, per_symbol=per_symbol,
                      per_1000_bars={n: dict(bullish=round(1000 * v[0] / bars, 2), bearish=round(1000 * v[1] / bars, 2))
                                     for n, v in cnt.items()},
                      per_1000_bars_total=round(1000 * total / bars, 2), bars_per_pattern=round(bars / max(1, total)))
print(json.dumps(result, indent=1))
