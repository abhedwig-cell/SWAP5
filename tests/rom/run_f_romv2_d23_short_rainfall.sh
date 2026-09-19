#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=ee83e12504e12ac92fc6c55a8d8e5a134666ed19
PREREG=integration/f-rom/F-ROMV2_D23_PREREGISTRATION.json
PREREG_BLOB=b0103ef9f5493a141ac6486e82fbff6b4f8ac453
PREFLIGHT=tests/rom/preflight_f_romv2_d23_short_rainfall.py
TEST=tests/rom/test_f_romv2_d23_rainfall_comparators.f90
ANALYZER=tests/rom/analyze_f_romv2_d23_short_rainfall.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-romv2-d23-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROMV2_D23_EVIDENCE_DIR:-$ROOT/F-ROMV2-D23-EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROMV2_D23_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin integration/f-ci-canonical
LIVE="$(git rev-parse FETCH_HEAD)"
[[ "$LIVE" == "$BASE" ]] || fail "canonical advanced after D23 preregistration: $LIVE"
git merge-base --is-ancestor "$BASE" HEAD || fail "D23 candidate not descendant of preregistered canonical"
git diff --quiet "$BASE"...HEAD -- src reference || fail "D23 mutated src/reference"
[[ "$(git rev-parse HEAD:$PREREG)" == "$PREREG_BLOB" ]] || fail "D23 preregistration blob drift"

python3 "$PREFLIGHT" --prereg "$PREREG" --output "$EVIDENCE/F-ROMV2_D23_FMC_PREFLIGHT.json" | tee "$EVIDENCE/preflight.txt"
grep -Fq '"decision": "D23_FMC_SHORT_RAINFALL_INTERNAL_PREFLIGHT_PASS"' "$EVIDENCE/F-ROMV2_D23_FMC_PREFLIGHT.json" || fail "FMC preflight no-go"

for spec in "R16 16 10" "R2 2 80"; do
  read -r id n dz <<<"$spec"
  stub="$BUILD/stubs_n${n}.f90"
  python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$stub" --nodes "$n" --dz-cm "$dz"
  for opt in 0 2; do
    outdir="$BUILD/${id}_o${opt}"
    python3 "$COMPILER" --root "$ROOT" --stub "$stub" --target "$TEST"       --external-source src/legacy/b1_10_port/headcalc.f90 --build "$outdir" --opt "$opt"
    "$outdir/rom0_test" > "$EVIDENCE/${id}_o${opt}.txt" 2>&1 || {
      tail -n 500 "$EVIDENCE/${id}_o${opt}.txt" >&2
      fail "${id} O${opt} execution"
    }
    grep -Fq 'F_ROMV2_D23_REF_EXECUTION_COMPLETE=PASS' "$EVIDENCE/${id}_o${opt}.txt" || fail "${id} missing completion O${opt}"
    [[ "$(grep -c 'F_ROMV2_D23_REF_STATE|' "$EVIDENCE/${id}_o${opt}.txt")" -eq 192 ]] || fail "${id} expected 192 states O${opt}"
  done
  cmp "$EVIDENCE/${id}_o0.txt" "$EVIDENCE/${id}_o2.txt" || fail "${id} O0/O2 drift"
  echo "F_ROMV2_D23_${id}_O0_O2_IDENTITY=PASS"
done

python3 "$ANALYZER"   --r16 "$EVIDENCE/R16_o2.txt" --r2 "$EVIDENCE/R2_o2.txt"   --prereg "$PREREG" --preflight "$EVIDENCE/F-ROMV2_D23_FMC_PREFLIGHT.json"   --output "$EVIDENCE/F-ROMV2_D23_RESULT.json" | tee "$EVIDENCE/analyzer.txt"

sha256sum "$EVIDENCE"/R*_o*.txt "$EVIDENCE/F-ROMV2_D23_FMC_PREFLIGHT.json"   "$EVIDENCE/F-ROMV2_D23_RESULT.json" "$EVIDENCE/preflight.txt" "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"

echo "F_ROMV2_D23_SHORT_RAINFALL_TRAJECTORY=PASS"
