#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=8f56c8a6e6e7a9973ca21711011c6e4a400975a0
PREREG=integration/f-rom/F-ROMV2_D8_PREREGISTRATION.json
PREREG_BLOB=72f683bec3fb8c2ddfe57f793db0a58b5c13ccc8
SEGMENT_C=tests/rom/f_romv2_d8_qs2_segment.c
PREFLIGHT=tests/rom/preflight_f_romv2_d8_qs2_composite.py
REFTEST=tests/rom/test_f_romv2_d8_r16_reference.f90
ANALYZER=tests/rom/analyze_f_romv2_d8_qs2_trajectories.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-romv2-d8-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROMV2_D8_EVIDENCE_DIR:-$ROOT/F-ROMV2-D8-EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROMV2_D8_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin integration/f-ci-canonical
LIVE="$(git rev-parse FETCH_HEAD)"
[[ "$LIVE" == "$BASE" ]] || fail "canonical advanced after D8 preregistration: $LIVE"
git diff --quiet "$BASE"...HEAD -- src reference || fail "D8 mutated src/reference"
[[ "$(git rev-parse HEAD:$PREREG)" == "$PREREG_BLOB" ]] || fail "D8 preregistration blob drift"

python3 - "$PREREG" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p["phase"]=="PREREGISTERED_BEFORE_PREFLIGHT"
assert p["candidate"]["id"]=="QS2_COMPOSITE"
assert p["candidate"]["dynamic_state_dimension"]==2
assert p["segment_profile_equations"]["RK4_subintervals_per_80cm_segment"]==512
assert p["decision_logic"]["no_application_thresholds"] is True
assert "NO_POST_RESULT_EQUATION_RETUNING" in p["firewalls"]
print("F_ROMV2_D8_PREREGISTRATION_LOCK=PASS")
PY

cc -O3 -fPIC -shared "$SEGMENT_C" -o "$BUILD/libqs2.so" -lm

python3 "$PREFLIGHT" --prereg "$PREREG" --lib "$BUILD/libqs2.so" \
  --output "$EVIDENCE/F-ROMV2_D8_PREFLIGHT_RESULT.json" | tee "$EVIDENCE/preflight.txt"
grep -Fq '"decision": "D8_QS2_COMPOSITE_PREFLIGHT_PASS"' "$EVIDENCE/F-ROMV2_D8_PREFLIGHT_RESULT.json" || fail "D8 preflight no-go"

stub="$BUILD/stubs_n16.f90"
python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$stub" --nodes 16 --dz-cm 10
for opt in 0 2; do
  out="$BUILD/ref_o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$stub" --target "$REFTEST" \
    --external-source src/legacy/b1_10_port/headcalc.f90 --build "$out" --opt "$opt"
  "$out/rom0_test" > "$EVIDENCE/R16_o$opt.txt" 2>&1 || fail "R16 O$opt execution"
  grep -Fq 'F_ROMV2_D8_REF_EXECUTION_COMPLETE=PASS' "$EVIDENCE/R16_o$opt.txt" || fail "R16 completion O$opt"
done
cmp "$EVIDENCE/R16_o0.txt" "$EVIDENCE/R16_o2.txt" || fail "R16 O0/O2 drift"

python3 "$ANALYZER" --reference "$EVIDENCE/R16_o2.txt" --prereg "$PREREG" \
  --preflight "$EVIDENCE/F-ROMV2_D8_PREFLIGHT_RESULT.json" --lib "$BUILD/libqs2.so" \
  --output "$EVIDENCE/F-ROMV2_D8_RESULT.json" | tee "$EVIDENCE/analyzer.txt"

sha256sum "$EVIDENCE"/* > "$EVIDENCE/sha256.txt"
echo "F_ROMV2_D8_QS2_DISCRIMINATOR=PASS"
