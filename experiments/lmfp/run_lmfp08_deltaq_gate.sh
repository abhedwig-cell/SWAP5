#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTDIR="$ROOT/lmfp08-deltaq-artifacts"
mkdir -p "$OUTDIR"
cd "$ROOT"

bash experiments/lmfp/run_lmfp04_ab_gate.sh
python3 -m py_compile \
  experiments/lmfp/run_lmfp08_deltaq_candidate.py \
  experiments/lmfp/run_lmfp08_physics_informed_correction.py \
  experiments/lmfp/run_lmfp07_transient_abc.py \
  experiments/lmfp/run_lmfp06_darcian_reference.py

python3 experiments/lmfp/run_lmfp08_deltaq_candidate.py \
  lmfp04-artifacts/F-LMFP04_FULLRICHARDS_REFERENCE.txt \
  "$OUTDIR/F-LMFP08_DELTAQ_EVIDENCE.json" \
  | tee "$OUTDIR/F-LMFP08_DELTAQ_EVIDENCE.stdout.json"

python3 - "$OUTDIR/F-LMFP08_DELTAQ_EVIDENCE.json" <<'PY'
import json, pathlib, sys
e=json.loads(pathlib.Path(sys.argv[1]).read_text())
assert e['structural_pass'] is True
assert e['tests']['exact_identities']['pass'] is True
assert e['tests']['face_oracle_validation']['pass'] is True
assert e['tests']['response_diagnostics']['pass'] is True
assert e['tests']['transient_matrix']['pass'] is True
print('F-LMFP08_DELTAQ_GATE PASS')
PY
