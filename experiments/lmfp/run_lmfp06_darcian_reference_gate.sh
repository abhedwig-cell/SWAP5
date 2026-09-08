#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTDIR="$ROOT/lmfp06-artifacts"
mkdir -p "$OUTDIR"
cd "$ROOT/experiments/lmfp"

python3 -m py_compile \
  run_lmfp02_testbench.py \
  run_lmfp03_column.py \
  run_lmfp06_darcian_reference.py \
  run_lmfp06_szym2009_control.py \
  run_lmfp06_lookup_surrogate.py

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

python3 run_lmfp06_szym2009_control.py \
  > "$OUTDIR/F-LMFP06_SZYMKIEWICZ_2009_CONTROL.json"

python3 - "$OUTDIR/F-LMFP06_SZYMKIEWICZ_2009_CONTROL.json" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
e = json.loads(p.read_text())
assert e['structural_pass'] is True
assert e['swkmean7_reproduced'] is False
for name, test in e['tests'].items():
    assert test['pass'] is True, name
m = e['tests']['homogeneous_oracle_matrix']
assert m['failures'] == 0
assert m['sign_mismatch'] == 0
assert m['szym2009_error']['p90'] < m['mfp_error']['p90']
print(json.dumps({
  'structural_pass': e['structural_pass'],
  'control': e['control'],
  'swkmean7_reproduced': e['swkmean7_reproduced'],
  'targeted': e['tests']['targeted_strong_gradient_control'],
  'matrix_summary': {
    'cases': m['cases'],
    'fraction_szym2009_better_than_mfp': m['fraction_szym2009_better_than_mfp'],
    'mfp_error': m['mfp_error'],
    'szym2009_error': m['szym2009_error'],
    'by_regime': m['by_regime'],
  }
}, indent=2, sort_keys=True))
PY

python3 run_lmfp06_lookup_surrogate.py \
  > "$OUTDIR/F-LMFP06_DARCIAN_LOOKUP_SURROGATE.json"

python3 - "$OUTDIR/F-LMFP06_DARCIAN_LOOKUP_SURROGATE.json" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
e = json.loads(p.read_text())
assert e['structural_pass'] is True
assert e['legacy_swkmean7_table_reproduced'] is False
for name, face in e['faces'].items():
    assert face['pass'] is True, name
    assert face['failures'] == 0
    assert face['sign_mismatch'] == 0
print(json.dumps({
  'structural_pass': e['structural_pass'],
  'surrogate': e['surrogate'],
  'legacy_swkmean7_table_reproduced': e['legacy_swkmean7_table_reproduced'],
  'head_axis_points': len(e['head_axis']),
  'faces': {k:{
    'table_shape':v['table_shape'],
    'validation_cases':v['validation_cases'],
    'error':v['error'],
    'sign_mismatch':v['sign_mismatch'],
  } for k,v in e['faces'].items()},
}, indent=2, sort_keys=True))
PY
