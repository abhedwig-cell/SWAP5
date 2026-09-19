#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=5c31a25b0e8d3f62a57aa87323703df611fa75f2
PREREG=integration/f-rom/F-ROMV2_D13_PREREGISTRATION.json
PREREG_BLOB=639abdde5146d5848d0043f8cead6a74fb4cd67d
PREFLIGHT=tests/rom/preflight_f_romv2_d13_fmc_groundwater.py
TEST=tests/rom/test_f_romv2_d13_groundwater_comparators.f90
ANALYZER=tests/rom/analyze_f_romv2_d13_fmc_groundwater.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-romv2-d13-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROMV2_D13_EVIDENCE_DIR:-$ROOT/F-ROMV2-D13-EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROMV2_D13_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin integration/f-ci-canonical
LIVE="$(git rev-parse FETCH_HEAD)"
[[ "$LIVE" == "$BASE" ]] || fail "canonical advanced after D13 preregistration: $LIVE"
git merge-base --is-ancestor "$BASE" HEAD || fail "D13 candidate not descendant of preregistered canonical"
git diff --quiet "$BASE"...HEAD -- src reference || fail "D13 mutated src/reference"
[[ "$(git rev-parse HEAD:$PREREG)" == "$PREREG_BLOB" ]] || fail "D13 preregistration blob drift"

python3 - "$PREREG" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p["phase"]=="PREREGISTERED_BEFORE_FULL_ALGORITHM_PREFLIGHT"
assert p["candidate"]["id"]=="FMC_GW200"
assert p["candidate"]["moisture_bins"]==200
assert p["time_integration"]["internal_substep_max_seconds"]==10
assert "bin i=100" in p["groundwater_front"]["baseline_theta"]
assert p["matched_SWAP_state"]["top_boundary"]=="zero prescribed flux"
assert p["matched_SWAP_state"]["bottom_boundary"]=="zero pressure head at column lower boundary"
assert "NO_BIN_COUNT_TUNING" in p["firewalls"]
assert "NO_SUBSTEP_TUNING" in p["firewalls"]
assert "NO_POST_PREFLIGHT_LAMBDA_RETUNING" in p["firewalls"]
print("F_ROMV2_D13_PREREGISTRATION_LOCK=PASS")
PY

python3 "$PREFLIGHT" --prereg "$PREREG" --output "$EVIDENCE/F-ROMV2_D13_PREFLIGHT_RESULT.json" | tee "$EVIDENCE/preflight.txt"
grep -Fq '"decision": "D13_FMC_GROUNDWATER_FRONT_PREFLIGHT_PASS"' "$EVIDENCE/F-ROMV2_D13_PREFLIGHT_RESULT.json" || fail "full-algorithm preflight no-go"

for spec in "R16 16 10" "R2 2 80"; do
  read -r id n dz <<<"$spec"
  stub="$BUILD/stubs_n${n}.f90"
  python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$stub" --nodes "$n" --dz-cm "$dz"
  for opt in 0 2; do
    outdir="$BUILD/${id}_o${opt}"
    python3 "$COMPILER" --root "$ROOT" --stub "$stub" --target "$TEST" \
      --external-source src/legacy/b1_10_port/headcalc.f90 --build "$outdir" --opt "$opt"
    "$outdir/rom0_test" > "$EVIDENCE/${id}_o${opt}.txt" 2>&1 || {
      tail -n 400 "$EVIDENCE/${id}_o${opt}.txt" >&2
      fail "${id} O${opt} execution"
    }
    grep -Fq 'F_ROMV2_D13_REF_EXECUTION_COMPLETE=PASS' "$EVIDENCE/${id}_o${opt}.txt" || fail "${id} missing completion O${opt}"
    [[ "$(grep -c 'F_ROMV2_D13_REF_STATE|' "$EVIDENCE/${id}_o${opt}.txt")" -eq 256 ]] || fail "${id} expected 256 states O${opt}"
  done
  cmp "$EVIDENCE/${id}_o0.txt" "$EVIDENCE/${id}_o2.txt" || fail "${id} O0/O2 drift"
  echo "F_ROMV2_D13_${id}_O0_O2_IDENTITY=PASS"
done

python3 "$ANALYZER" \
  --r16 "$EVIDENCE/R16_o2.txt" --r2 "$EVIDENCE/R2_o2.txt" \
  --prereg "$PREREG" --preflight "$EVIDENCE/F-ROMV2_D13_PREFLIGHT_RESULT.json" \
  --output "$EVIDENCE/F-ROMV2_D13_RESULT.json" | tee "$EVIDENCE/analyzer.txt"

sha256sum "$EVIDENCE"/R*_o*.txt "$EVIDENCE/F-ROMV2_D13_PREFLIGHT_RESULT.json" \
  "$EVIDENCE/F-ROMV2_D13_RESULT.json" "$EVIDENCE/preflight.txt" "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"

echo "F_ROMV2_D13_FMC_GROUNDWATER_COMPARATOR=PASS"
