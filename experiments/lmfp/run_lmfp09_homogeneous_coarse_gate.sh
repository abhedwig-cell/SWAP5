#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTDIR="$ROOT/lmfp09-homogeneous-coarse-artifacts"
mkdir -p "$OUTDIR"
cd "$ROOT"

python3 -m py_compile \
  experiments/lmfp/run_lmfp09_homogeneous_coarse_first.py \
  experiments/lmfp/run_lmfp09_homogeneous_face_matrix.py \
  experiments/lmfp/run_lmfp09_coordinate_envelope.py \
  experiments/lmfp/run_lmfp06_darcian_reference.py \
  experiments/lmfp/run_lmfp02_testbench.py

python3 experiments/lmfp/run_lmfp09_homogeneous_coarse_first.py \
  "$OUTDIR/F-LMFP09_HOMOGENEOUS_COARSE_EVIDENCE.json" \
  | tee "$OUTDIR/F-LMFP09_HOMOGENEOUS_COARSE_EVIDENCE.stdout.json"

python3 - "$OUTDIR/F-LMFP09_HOMOGENEOUS_COARSE_EVIDENCE.json" <<'PY'
import json, pathlib, sys
p=pathlib.Path(sys.argv[1])
e=json.loads(p.read_text())
assert e['candidate_ratio_head_nodes'] == [17, 33]
assert e['structural_pass'] is True
assert e['selected'] is not None
assert e['selected']['ratio_head_nodes'] in (17, 33)
print('F-LMFP09_B1_COARSE_FIRST_GATE PASS')
print('selected ratio_head_nodes=', e['selected']['ratio_head_nodes'])
print('bytes/class=', e['selected']['bytes_per_material_geometry_class_before_metadata'])
PY
