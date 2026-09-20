#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CANONICAL_START=b3dc66cd85bcebe2bfca4d46f9ee92cb06d3137d
STATE_AUTHORITY_COMMIT=7925b611314c1a9e8be6ef9d4468ee1d39f87591
STATE_AUTHORITY=integration/f-rom/LAYER_ROM_PHASE_A_STATE_AUTHORITY.json
RESPONSE_PREREG=integration/f-rom/LAYER_ROM_PHASE_A_STATE_RESPONSE_PREREGISTRATION.json
START_PREP=tests/rom/prepare_layer_rom_phase_a_future_starts.py
BASE_TEST=tests/rom/test_layer_rom_phase_a_reference.f90
FUTURE_TEST=tests/rom/test_layer_rom_phase_a_future_response.f90
ANALYZER=tests/rom/analyze_layer_rom_phase_a_future_response.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-layer-rom-pa-response-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${LAYER_ROM_PHASE_A_RESPONSE_EVIDENCE_DIR:-$ROOT/LAYER_ROM_PHASE_A_RESPONSE_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "LAYER_ROM_PHASE_A_RESPONSE_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$CANONICAL_START" HEAD || fail "canonical start not ancestor"
git merge-base --is-ancestor "$STATE_AUTHORITY_COMMIT" HEAD || fail "state authority not ancestor"
git diff --quiet "$CANONICAL_START"...HEAD -- src reference || fail "Layer-ROM response work changed src/reference"

python3 - "$STATE_AUTHORITY" "$RESPONSE_PREREG" <<'PY'
import json,sys
a=json.load(open(sys.argv[1])); p=json.load(open(sys.argv[2]))
assert a["decision"]=="INDEPENDENT_STATE_INFORMATION_SCREEN_AND_PAIR_FREEZE_QUALIFIED"
assert a["execution"]["workflow_run"]==35494306128
assert p["phase"]=="PREREGISTERED_BEFORE_INDEPENDENT_REFERENCE_RESULT_EXPOSURE"
assert p["common_future_probe_bank"]["horizons_steps"]==[8,64,256]
assert [x["id"] for x in p["common_future_probe_bank"]["probes"]]==[
 "P_FX_ZERO","P_FX_OPPOSED","P_HD_WETTER","P_HD_DRIER","P_HD_SWITCH","P_TOP_SWITCH"]
print("LAYER_ROM_PHASE_A_RESPONSE_AUTHORITY_LOCK=PASS")
PY

python3 "$START_PREP" --authority "$STATE_AUTHORITY" --output "$EVIDENCE/starts.txt" |
  tee "$EVIDENCE/start_selection.txt"
[[ "$(wc -l < "$EVIDENCE/starts.txt")" -eq 30 ]] || fail "expected 30 unique starts"

python3 "$MATERIALIZER"   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90"   --nodes 16   --dz-cm 10

python3 "$COMPILER"   --root "$ROOT"   --stub "$BUILD/stubs_n16.f90"   --target "$BASE_TEST"   --external-source src/legacy/b1_10_port/headcalc.f90   --build "$BUILD/base"   --opt 2
"$BUILD/base/rom0_test" > "$EVIDENCE/base_reference.txt" 2>&1 || {
  tail -n 400 "$EVIDENCE/base_reference.txt" >&2
  fail "base Reference replay"
}
grep -Fq 'LAYERR1_EXECUTION_COMPLETE=PASS' "$EVIDENCE/base_reference.txt" ||
  fail "base Reference completion marker"
BASE_SHA="$(sha256sum "$EVIDENCE/base_reference.txt" | awk '{print $1}')"
[[ "$BASE_SHA" == "063ce66fbd30b710e7653a19647e93002671a6e937012ff1dba49959c0a1479d" ]] ||
  fail "base Reference stdout drift from qualified authority"

for opt in 0 2; do
  OUT="$BUILD/future_o$opt"
  python3 "$COMPILER"     --root "$ROOT"     --stub "$BUILD/stubs_n16.f90"     --target "$FUTURE_TEST"     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT"     --opt "$opt"
  LAYER_ROM_PHASE_A_STARTS_FILE="$EVIDENCE/starts.txt" "$OUT/rom0_test" > "$EVIDENCE/future_o$opt.txt" 2>&1 || {
    tail -n 500 "$EVIDENCE/future_o$opt.txt" >&2
    fail "future response execution O$opt"
  }
  grep -Fq 'LAYERR2_EXECUTION_COMPLETE=PASS' "$EVIDENCE/future_o$opt.txt" ||
    fail "future completion marker O$opt"
  [[ "$(grep -c 'LAYERR2_START|' "$EVIDENCE/future_o$opt.txt")" -eq 30 ]] ||
    fail "future start count O$opt"
  [[ "$(grep -c 'LAYERR2_START_NODE|' "$EVIDENCE/future_o$opt.txt")" -eq 480 ]] ||
    fail "future start node count O$opt"
  [[ "$(grep -c 'LAYERR2_STEP|' "$EVIDENCE/future_o$opt.txt")" -eq 46080 ]] ||
    fail "future step count O$opt"
  [[ "$(grep -c 'LAYERR2_PROBE|' "$EVIDENCE/future_o$opt.txt")" -eq 540 ]] ||
    fail "future endpoint count O$opt"
  [[ "$(grep -c 'LAYERR2_PROBE_NODE|' "$EVIDENCE/future_o$opt.txt")" -eq 8640 ]] ||
    fail "future endpoint node count O$opt"
done

cmp "$EVIDENCE/future_o0.txt" "$EVIDENCE/future_o2.txt" ||
  fail "future O0/O2 stdout drift"
echo 'LAYER_ROM_PHASE_A_FUTURE_O0_O2_IDENTITY=PASS'

python3 "$ANALYZER"   --input "$EVIDENCE/future_o2.txt"   --repeat "$EVIDENCE/future_o0.txt"   --base-reference "$EVIDENCE/base_reference.txt"   --authority "$STATE_AUTHORITY"   --prereg "$RESPONSE_PREREG"   --output "$EVIDENCE/LAYER_ROM_PHASE_A_FUTURE_RESPONSE_RESULT.json" |
  tee "$EVIDENCE/analyzer.txt"

sha256sum   "$EVIDENCE/base_reference.txt"   "$EVIDENCE/future_o0.txt"   "$EVIDENCE/future_o2.txt"   "$EVIDENCE/LAYER_ROM_PHASE_A_FUTURE_RESPONSE_RESULT.json"   "$EVIDENCE/starts.txt"   "$EVIDENCE/start_selection.txt"   "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"

git diff --check "$CANONICAL_START"...HEAD
echo 'LAYER_ROM_PHASE_A_FUTURE_RESPONSE_GATE=PASS'
