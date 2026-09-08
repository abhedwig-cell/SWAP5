#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTDIR="$ROOT/lmfp06-artifacts"
mkdir -p "$OUTDIR"
cd "$ROOT/experiments/lmfp"

python3 -m py_compile \
  run_lmfp02_testbench.py \
  run_lmfp03_column.py \
  run_lmfp06_darcian_reference.py

python3 run_lmfp06_darcian_reference.py \
  > "$OUTDIR/F-LMFP06_DARCIAN_REFERENCE_EVIDENCE.json"

python3 - "$OUTDIR/F-LMFP06_DARCIAN_REFERENCE_EVIDENCE.json" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
e = json.loads(p.read_text())
assert e['structural_pass'] is True
for name, test in e['tests'].items():
    assert test['pass'] is True, name
local = e['tests']['heterogeneous_local_limit']['finest_cases']
assert len(local) == 2
assert all(x['mfp_rel_error'] < 0.01 for x in local)
assert all(x['harmonic_rel_error'] < 0.01 for x in local)
assert all(x['arithmetic_rel_error'] > 0.25 for x in local)
matrix = e['tests']['bounded_reference_matrix']
assert matrix['failures'] == 0
assert matrix['sign_mismatch']['mfp'] == 0
print(json.dumps({
  'structural_pass': e['structural_pass'],
  'local_limit': local,
  'matrix_summary': {
    'cases': matrix['cases'],
    'mfp_error': matrix['mfp_error'],
    'arithmetic_error': matrix['arithmetic_error'],
    'harmonic_error': matrix['harmonic_error'],
    'sign_mismatch': matrix['sign_mismatch'],
    'max_oracle_root_iterations': matrix['max_oracle_root_iterations'],
    'max_accumulated_ode_steps_per_root': matrix['max_accumulated_ode_steps_per_root'],
  },
  'reproducibility': e['tests']['oracle_tolerance_reproducibility'],
}, indent=2, sort_keys=True))
PY
