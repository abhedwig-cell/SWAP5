#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTDIR="$ROOT/lmfp09-homogeneous-artifacts"
mkdir -p "$OUTDIR"
cd "$ROOT"

python3 -m py_compile \
  experiments/lmfp/run_lmfp09_homogeneous_face_matrix.py \
  experiments/lmfp/run_lmfp09_coordinate_envelope.py \
  experiments/lmfp/run_lmfp06_darcian_reference.py \
  experiments/lmfp/run_lmfp02_testbench.py

python3 experiments/lmfp/run_lmfp09_homogeneous_face_matrix.py \
  "$OUTDIR/F-LMFP09_HOMOGENEOUS_EVIDENCE.json" \
  | tee "$OUTDIR/F-LMFP09_HOMOGENEOUS_EVIDENCE.stdout.json"

python3 - "$OUTDIR/F-LMFP09_HOMOGENEOUS_EVIDENCE.json" <<'PY'
import json, pathlib, sys
p=pathlib.Path(sys.argv[1])
e=json.loads(p.read_text())
assert e['structural_pass'] is True
assert e['selected'] is not None
assert e['selected']['pass'] is True
for c in e['selected']['classes']:
    assert c['identity']['pass'] is True
    assert c['continuity']['pass'] is True
    assert c['fail_closed']['pass'] is True
    assert c['face_matrix']['pass'] is True
print('F-LMFP09_EXPANDED_HOMOGENEOUS_FACE_GATE PASS')
print('selected ratio_head_nodes=', e['selected']['ratio_head_nodes'])
print('bytes/class=', e['selected']['bytes_per_material_geometry_class_before_metadata'])
PY
