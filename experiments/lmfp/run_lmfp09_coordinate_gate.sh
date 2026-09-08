#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTDIR="$ROOT/lmfp09-coordinate-artifacts"
mkdir -p "$OUTDIR"
cd "$ROOT"

python3 -m py_compile \
  experiments/lmfp/run_lmfp09_coordinate_envelope.py \
  experiments/lmfp/run_lmfp02_testbench.py

python3 experiments/lmfp/run_lmfp09_coordinate_envelope.py \
  "$OUTDIR/F-LMFP09_COORDINATE_EVIDENCE.json" \
  | tee "$OUTDIR/F-LMFP09_COORDINATE_EVIDENCE.stdout.json"

python3 - "$OUTDIR/F-LMFP09_COORDINATE_EVIDENCE.json" <<'PY'
import json, pathlib, sys
p=pathlib.Path(sys.argv[1])
e=json.loads(p.read_text())
assert e['structural_pass'] is True
assert e['selected'] is not None
assert e['selected']['pass'] is True
assert e['fail_closed']['pass'] is True
print('F-LMFP09_COORDINATE_AND_ENVELOPE_GATE PASS')
print('selected hscale_cm=', e['selected']['hscale_cm'])
print('selected negative_head_nodes=', e['selected']['negative_head_nodes'])
PY
