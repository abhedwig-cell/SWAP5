#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BASE=d980bbc2d735004a24a80f4fce5020e7f09f84e8
PREREG=integration/f-rom/F-ROMV2_D10_PREREGISTRATION.json
PREREG_BLOB=8b4cbc76d872e7e8eb259c93a09de848e7a0a64f
TEST=tests/rom/test_f_romv2_d10_zero_head_comparators.f90
ANALYZER=tests/rom/analyze_f_romv2_d10_he_two_layer.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-romv2-d10-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROMV2_D10_EVIDENCE_DIR:-$ROOT/F-ROMV2-D10-EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROMV2_D10_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin integration/f-ci-canonical
LIVE="$(git rev-parse FETCH_HEAD)"
[[ "$LIVE" == "$BASE" ]] || fail "canonical advanced after D10 preregistration: $LIVE"
git diff --quiet "$BASE"...HEAD -- src reference || fail "D10 mutated src/reference"
[[ "$(git rev-parse HEAD:$PREREG)" == "$PREREG_BLOB" ]] || fail "D10 preregistration blob drift"

python3 - "$PREREG" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p["phase"]=="PREREGISTERED_BEFORE_EXECUTION"
assert p["he2"]["id"]=="HE2_PUBLISHED_FIXED_H"
assert p["he2"]["corrector_tolerance_theta"]==1e-4
assert p["scope"]["bottom_boundary"]=="zero pressure head h=0 / psi_b=0"
assert p["seed"]["bottom_boundary"]=="zero pressure head h=0 / psi_b=0 from the first seed interval"
assert "NO_ARBITRARY_NONZERO_BOTTOM_HEAD" in p["firewalls"]
print("F_ROMV2_D10_PREREGISTRATION_LOCK=PASS")
PY

for spec in "R16 16 10" "R2 2 80"; do
  read -r id n dz <<<"$spec"
  stub="$BUILD/stubs_n${n}.f90"
  python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$stub" --nodes "$n" --dz-cm "$dz"
  for opt in 0 2; do
    outdir="$BUILD/${id}_o${opt}"
    python3 "$COMPILER" --root "$ROOT" --stub "$stub" --target "$TEST" \
      --external-source src/legacy/b1_10_port/headcalc.f90 --build "$outdir" --opt "$opt"
    "$outdir/rom0_test" > "$EVIDENCE/${id}_o${opt}.txt" 2>&1 || {
      tail -n 300 "$EVIDENCE/${id}_o${opt}.txt" >&2
      fail "${id} O${opt} execution"
    }
    grep -Fq 'F_ROMV2_D10_REF_EXECUTION_COMPLETE=PASS' "$EVIDENCE/${id}_o${opt}.txt" || fail "${id} completion O${opt}"
    [[ "$(grep -c 'F_ROMV2_D10_REF_STATE|' "$EVIDENCE/${id}_o${opt}.txt")" -eq 256 ]] || fail "${id} expected 256 states O${opt}"
  done
  cmp "$EVIDENCE/${id}_o0.txt" "$EVIDENCE/${id}_o2.txt" || fail "${id} O0/O2 drift"
  echo "F_ROMV2_D10_${id}_O0_O2_IDENTITY=PASS"
done

python3 "$ANALYZER" --r16 "$EVIDENCE/R16_o2.txt" --r2 "$EVIDENCE/R2_o2.txt" \
  --prereg "$PREREG" --output "$EVIDENCE/F-ROMV2_D10_RESULT.json" \
  | tee "$EVIDENCE/analyzer.txt"

sha256sum "$EVIDENCE"/R*_o*.txt "$EVIDENCE/F-ROMV2_D10_RESULT.json" "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
echo "F_ROMV2_D10_LITERATURE_BOUND_COMPARATOR=PASS"
