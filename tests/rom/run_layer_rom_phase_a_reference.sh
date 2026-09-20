#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CANONICAL_START=b3dc66cd85bcebe2bfca4d46f9ee92cb06d3137d
PREREG_COMMIT=a0c03f7a247f62e404724a5a86bca5114324dff3
PREREG=integration/f-rom/LAYER_ROM_PHASE_A_REFERENCE_PREREGISTRATION.json
TEST=tests/rom/test_layer_rom_phase_a_reference.f90
ANALYZER=tests/rom/analyze_layer_rom_phase_a_reference.py
STATE_ANALYZER=tests/rom/analyze_layer_rom_phase_a_independent_state.py
PAIR_FREEZER=tests/rom/freeze_layer_rom_phase_a_pairs.py
STATE_PREREG=integration/f-rom/LAYER_ROM_PHASE_A_PREREGISTRATION.json
STATE_RESPONSE_PREREG=integration/f-rom/LAYER_ROM_PHASE_A_STATE_RESPONSE_PREREGISTRATION.json
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-layer-rom-pa-ref-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${LAYER_ROM_PHASE_A_EVIDENCE_DIR:-$ROOT/LAYER_ROM_PHASE_A_REFERENCE_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "LAYER_ROM_PHASE_A_REFERENCE_GATE_FAIL $*" >&2; exit 1; }

python3 - <<'PY'
import numpy
assert numpy.__version__ == "2.3.3", numpy.__version__
print("LAYER_ROM_PHASE_A_NUMPY_VERSION=2.3.3")
PY

git merge-base --is-ancestor "$CANONICAL_START" HEAD || fail "canonical start not ancestor"
git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "Reference preregistration not ancestor"
git diff --quiet "$CANONICAL_START"...HEAD -- src reference || fail "Layer-ROM Phase A changed src/reference"
echo 'LAYER_ROM_PHASE_A_SOURCE_FREEZE=PASS'

python3 - "$PREREG" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p["phase"]=="PREREGISTERED_BEFORE_FIRST_INDEPENDENT_REFERENCE_EXECUTION"
assert p["canonical_basis"]=="integration/f-ci-canonical@b3dc66cd85bcebe2bfca4d46f9ee92cb06d3137d"
assert p["time"]["steps_per_history"]==1024
assert p["time"]["observation_dt_day"]==0.0008
assert [h["id"] for h in p["histories"]]==["F00","F01","F02","H00","H01","H02"]
assert [h["se0"] for h in p["histories"]]==[0.60,0.75,0.90,0.60,0.75,0.90]
assert all(sum(n for _,n in h["segments"])==1024 for h in p["histories"])
assert [h["bottom_mode"] for h in p["histories"]]==[2,2,2,5,5,5]
assert p["forcing_scale"]["top_pulse_delta"]=="0.0125 * K(h0)"
assert p["production_rom_authorized"] is False
print("LAYER_ROM_PHASE_A_REFERENCE_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/stubs_n16.f90" \
  --nodes 16 \
  --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" \
    --root "$ROOT" \
    --stub "$BUILD/stubs_n16.f90" \
    --target "$TEST" \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" \
    --opt "$opt"

  "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    tail -n 400 "$EVIDENCE/o$opt.txt" >&2
    fail "Reference library execution O$opt"
  }

  grep -Fq 'LAYERR1_EXECUTION_COMPLETE=PASS' "$EVIDENCE/o$opt.txt" ||
    fail "missing completion marker O$opt"
  [[ "$(grep -c 'LAYERR1_STATE|' "$EVIDENCE/o$opt.txt")" -eq 6144 ]] ||
    fail "expected 6144 accepted states O$opt"
  [[ "$(grep -c 'LAYERR1_NODE|' "$EVIDENCE/o$opt.txt")" -eq 98304 ]] ||
    fail "expected 98304 node records O$opt"
done

cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" ||
  fail "O0/O2 Reference-library stdout drift"
echo 'LAYER_ROM_PHASE_A_O0_O2_IDENTITY=PASS'

python3 "$ANALYZER" \
  --input "$EVIDENCE/o2.txt" \
  --repeat "$EVIDENCE/o0.txt" \
  --prereg "$PREREG" \
  --output "$EVIDENCE/LAYER_ROM_PHASE_A_REFERENCE_RESULT.json" |
  tee "$EVIDENCE/analyzer.txt"

cat "$EVIDENCE/LAYER_ROM_PHASE_A_REFERENCE_RESULT.json"

python3 "$STATE_ANALYZER" \
  --input "$EVIDENCE/o2.txt" \
  --prereg "$STATE_PREREG" \
  --state-prereg "$STATE_RESPONSE_PREREG" \
  --output "$EVIDENCE/LAYER_ROM_PHASE_A_INDEPENDENT_STATE_RESULT.json" |
  tee "$EVIDENCE/state_analyzer.txt"

cat "$EVIDENCE/LAYER_ROM_PHASE_A_INDEPENDENT_STATE_RESULT.json"

python3 "$PAIR_FREEZER" \
  --state-result "$EVIDENCE/LAYER_ROM_PHASE_A_INDEPENDENT_STATE_RESULT.json" \
  --prereg "$STATE_RESPONSE_PREREG" \
  --output "$EVIDENCE/LAYER_ROM_PHASE_A_PAIR_MANIFEST.json" |
  tee "$EVIDENCE/pair_freezer.txt"

cat "$EVIDENCE/LAYER_ROM_PHASE_A_PAIR_MANIFEST.json"

sha256sum \
  "$EVIDENCE/o0.txt" \
  "$EVIDENCE/o2.txt" \
  "$EVIDENCE/LAYER_ROM_PHASE_A_REFERENCE_RESULT.json" \
  "$EVIDENCE/LAYER_ROM_PHASE_A_INDEPENDENT_STATE_RESULT.json" \
  "$EVIDENCE/LAYER_ROM_PHASE_A_PAIR_MANIFEST.json" \
  "$EVIDENCE/analyzer.txt" \
  "$EVIDENCE/pair_freezer.txt" \
  "$EVIDENCE/state_analyzer.txt" > "$EVIDENCE/sha256.txt"

git diff --check "$CANONICAL_START"...HEAD
echo 'LAYER_ROM_PHASE_A_REFERENCE_LIBRARY_GATE=PASS'
