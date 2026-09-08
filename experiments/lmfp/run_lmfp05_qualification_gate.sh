#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTDIR="$ROOT/lmfp05-artifacts"
mkdir -p "$OUTDIR"
cd "$ROOT"

# Part A: source-bound same-grid attribution against the current SWAP5
# FullRichards route at step sizes already shown to converge in this harness.
bash "$ROOT/experiments/lmfp/run_lmfp05_attribution_gate.sh"

# Part B: direct frozen-state spatial closure attribution. This deliberately
# avoids forcing HeadCalc toward dt=0 because F-LMFP05 observed non-monotone
# retry behaviour there. The FullRichards SWKMEAN=1 semi-discrete face law is
# explicit in HeadCalc/hcomean and can be compared without time integration.
python3 "$ROOT/experiments/lmfp/run_lmfp05_closure_limit.py" \
  "$OUTDIR/F-LMFP05_CLOSURE_LIMIT_EVIDENCE.json" \
  | tee "$OUTDIR/F-LMFP05_CLOSURE_LIMIT_EVIDENCE.stdout.json"

python3 - "$OUTDIR/F-LMFP05_ATTRIBUTION_EVIDENCE.json" "$OUTDIR/F-LMFP05_CLOSURE_LIMIT_EVIDENCE.json" <<'PY'
import json, pathlib, sys
same = json.loads(pathlib.Path(sys.argv[1]).read_text())
limit = json.loads(pathlib.Path(sys.argv[2]).read_text())
assert same['structural_pass'] is True
assert limit['structural_pass'] is True
for name in ('redistribution_sand', 'sand_over_clay', 'clay_over_sand'):
    anchor = same['four_layer_anchor_attribution'][name]
    # Attribution only: arithmetic-K is the control matching the current
    # FullRichards SWKMEAN=1 face law. This is not a physical admission rule.
    assert anchor['mfp_over_arithmetic_error_l1'] > 100.0
print('F-LMFP05_QUALIFICATION_GATE PASS')
PY
