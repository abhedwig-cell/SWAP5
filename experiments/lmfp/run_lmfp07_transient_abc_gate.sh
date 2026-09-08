#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTDIR="$ROOT/lmfp07-artifacts"
mkdir -p "$OUTDIR"
cd "$ROOT"

# Rebuild and run the admitted F-LMFP04 reference harness on this exact checkout.
bash experiments/lmfp/run_lmfp04_ab_gate.sh

python3 -m py_compile \
  experiments/lmfp/run_lmfp07_transient_abc.py \
  experiments/lmfp/run_lmfp07_direct_darcian_control.py \
  experiments/lmfp/run_lmfp06_lookup_surrogate.py \
  experiments/lmfp/run_lmfp06_darcian_reference.py \
  experiments/lmfp/run_lmfp04_ab.py \
  experiments/lmfp/run_lmfp03_column.py \
  experiments/lmfp/run_lmfp02_testbench.py

python3 experiments/lmfp/run_lmfp07_transient_abc.py \
  lmfp04-artifacts/F-LMFP04_FULLRICHARDS_REFERENCE.txt \
  "$OUTDIR/F-LMFP07_TRANSIENT_ABC_EVIDENCE.json" \
  | tee "$OUTDIR/F-LMFP07_TRANSIENT_ABC_EVIDENCE.stdout.json"

python3 experiments/lmfp/run_lmfp07_direct_darcian_control.py \
  "$OUTDIR/F-LMFP07_TRANSIENT_ABC_EVIDENCE.json" \
  "$OUTDIR/F-LMFP07_DIRECT_DARCIAN_CONTROL.json" \
  | tee "$OUTDIR/F-LMFP07_DIRECT_DARCIAN_CONTROL.stdout.json"

python3 - "$OUTDIR/F-LMFP07_TRANSIENT_ABC_EVIDENCE.json" "$OUTDIR/F-LMFP07_DIRECT_DARCIAN_CONTROL.json" <<'PY'
import json, pathlib, sys
e=json.loads(pathlib.Path(sys.argv[1]).read_text())
d=json.loads(pathlib.Path(sys.argv[2]).read_text())
assert e['structural_pass'] is True
assert e['tests']['all_candidate_steps_accepted']['pass'] is True
assert e['tests']['candidate_mass_closure']['pass'] is True
assert e['tests']['lookup_coverage_main']['pass'] is True
assert e['tests']['lookup_coverage_stress']['pass'] is True
assert e['tests']['stress_all_paths_mass_conservative']['pass'] is True
assert d['structural_pass'] is True
assert d['summary']['all_direct_darcian_steps_accepted'] is True
print('F-LMFP07_TRANSIENT_ABC_STRUCTURAL_GATE PASS')
PY
