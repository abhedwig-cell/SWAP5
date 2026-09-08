#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTDIR="$ROOT/lmfp08-artifacts"
mkdir -p "$OUTDIR"
cd "$ROOT"

# Rebuild the admitted same-grid FullRichards reference on this exact checkout.
bash experiments/lmfp/run_lmfp04_ab_gate.sh

python3 -m py_compile \
  experiments/lmfp/run_lmfp08_log_ratio.py \
  experiments/lmfp/run_lmfp08_physics_informed_correction.py \
  experiments/lmfp/run_lmfp07_transient_abc.py \
  experiments/lmfp/run_lmfp06_darcian_reference.py \
  experiments/lmfp/run_lmfp04_ab.py \
  experiments/lmfp/run_lmfp03_column.py \
  experiments/lmfp/run_lmfp02_testbench.py

# Evaluate the multiplicative log Darcian-conductivity ratio representation.
# Tables are shared immutably per material/geometry class inside the wrapper.
python3 experiments/lmfp/run_lmfp08_log_ratio.py \
  lmfp04-artifacts/F-LMFP04_FULLRICHARDS_REFERENCE.txt \
  "$OUTDIR/F-LMFP08_LOG_RATIO_EVIDENCE.json" \
  | tee "$OUTDIR/F-LMFP08_LOG_RATIO_EVIDENCE.stdout.json"

python3 - "$OUTDIR/F-LMFP08_LOG_RATIO_EVIDENCE.json" <<'PY'
import json, pathlib, sys
p=pathlib.Path(sys.argv[1])
e=json.loads(p.read_text())
assert e['structural_pass'] is True
assert e['tests']['exact_identities']['pass'] is True
assert e['tests']['face_oracle_validation']['pass'] is True
assert e['tests']['response_diagnostics']['pass'] is True
assert e['tests']['transient_matrix']['pass'] is True
assert e['tests']['transient_matrix']['stress_corrected_closer_to_direct_darcian']['count'] == 5
print('F-LMFP08_LOG_DARCIAN_RATIO_GATE PASS')
PY
