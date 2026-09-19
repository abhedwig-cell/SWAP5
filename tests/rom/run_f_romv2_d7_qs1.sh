#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BASE=38559be9288e2fe5a7f0d9b202e9611c3d33de33
PREREG=integration/f-rom/F-ROMV2_D7_PREREGISTRATION.json
PREREG_BLOB=b5338c41c74272c674b3bdd171fc867cd651491b
PREFLIGHT=tests/rom/preflight_f_romv2_d7_admissible_manifold.py
REFTEST=tests/rom/test_f_romv2_d7_r16_reference.f90
ANALYZER=tests/rom/analyze_f_romv2_d7_qs1_trajectories.py
PROFILE_C=tests/rom/f_romv2_d7_qs1_profile.c
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-romv2-d7-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROMV2_D7_EVIDENCE_DIR:-$ROOT/F-ROMV2-D7-EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROMV2_D7_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin integration/f-ci-canonical
LIVE="$(git rev-parse FETCH_HEAD)"
[[ "$LIVE" == "$BASE" ]] || fail "canonical advanced after D7 preregistration: $LIVE"
git diff --quiet "$BASE"...HEAD -- src reference || fail "D7 mutated src/reference"
[[ "$(git rev-parse HEAD:$PREREG)" == "$PREREG_BLOB" ]] || fail "D7 preregistration blob drift"

python3 "$PREFLIGHT" --prereg "$PREREG" --output "$EVIDENCE/F-ROMV2_D7_PREFLIGHT_RESULT.json" | tee "$EVIDENCE/preflight.txt"
grep -Fq '"decision": "D7_ADMISSIBLE_ROOT_SEARCH_PREFLIGHT_PASS"' "$EVIDENCE/F-ROMV2_D7_PREFLIGHT_RESULT.json" || fail "preflight no-go"

stub="$BUILD/stubs_n16.f90"
python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$stub" --nodes 16 --dz-cm 10
for opt in 0 2; do
  out="$BUILD/ref_o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$stub" --target "$REFTEST" \
    --external-source src/legacy/b1_10_port/headcalc.f90 --build "$out" --opt "$opt"
  "$out/rom0_test" > "$EVIDENCE/R16_o$opt.txt" 2>&1 || fail "R16 O$opt execution"
  grep -Fq 'F_ROMV2_D7_REF_EXECUTION_COMPLETE=PASS' "$EVIDENCE/R16_o$opt.txt" || fail "R16 completion O$opt"
done
cmp "$EVIDENCE/R16_o0.txt" "$EVIDENCE/R16_o2.txt" || fail "R16 O0/O2 drift"

cc -O3 -fPIC -shared "$PROFILE_C" -o "$BUILD/libqs1.so" -lm
python3 "$ANALYZER" --reference "$EVIDENCE/R16_o2.txt" --prereg "$PREREG" \
  --preflight "$EVIDENCE/F-ROMV2_D7_PREFLIGHT_RESULT.json" \
  --profile-lib "$BUILD/libqs1.so" \
  --output "$EVIDENCE/F-ROMV2_D7_RESULT.json" | tee "$EVIDENCE/analyzer.txt"

sha256sum "$EVIDENCE"/* > "$EVIDENCE/sha256.txt"
echo "F_ROMV2_D7_QS1_DISCRIMINATOR=PASS"
