#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=2abf3a00dcb80455cf1fdee85655eae19e6f761b
PREREG=integration/f-rom/F-ROMV2_D5_PREREGISTRATION.json
PREREG_BLOB=eab62b17b15b5fb414535b604e2e7c9b24f56300
D4_RESULT=integration/f-rom/F-ROMV2_D4_RESULT.json
REF_TEST=tests/rom/test_f_romv2_d5_r16_reference.f90
ANALYZER=tests/rom/analyze_f_romv2_d5_two_layer_physical_reduction.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-romv2-d5-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROMV2_D5_EVIDENCE_DIR:-$ROOT/F-ROMV2-D5-EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROMV2_D5_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin integration/f-ci-canonical
LIVE="$(git rev-parse FETCH_HEAD)"
[[ "$LIVE" == "$BASE" ]] || fail "canonical advanced after D5 preregistration: $LIVE"
git merge-base --is-ancestor "$BASE" HEAD || fail "D5 candidate is not descendant of preregistered canonical"
git diff --quiet "$BASE"...HEAD -- src reference || fail "D5 mutated src/reference"
[[ "$(git rev-parse HEAD:$PREREG)" == "$PREREG_BLOB" ]] || fail "D5 preregistration blob drift"

python3 - "$PREREG" "$D4_RESULT" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
d4=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_EXECUTION"
assert p["candidate"]["id"]=="L2_IMC"
assert p["candidate"]["state_dimension"]==2
assert p["candidate"]["training_required"] is False
assert p["candidate"]["nonlinear_Richards_solve_required"] is False
assert p["candidate"]["adaptive_substepping_allowed"] is False
assert p["candidate"]["clipping_allowed"] is False
assert p["candidate"]["fallback_to_Richards"] is False
assert p["time_integration"]["internal_substeps"]==1
assert p["time_integration"]["hard_mass_gate_cm"]==1e-12
assert p["decision_logic"]["no_application_thresholds"] is True
assert "NO_POST_RESULT_EQUATION_RETUNING" in p["firewalls"]
assert d4["decision"]=="STRONGLY_COARSE_RICHARDS_HYDROLOGICALLY_MEASURABLE_UNDER_INTEGRATED_MASS_POLICY"
print("F_ROMV2_D5_PREREGISTRATION_LOCK=PASS")
PY

stub="$BUILD/stubs_n16.f90"
python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$stub" --nodes 16 --dz-cm 10

for opt in 0 2; do
  outdir="$BUILD/ref_o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$stub" --target "$REF_TEST" \
    --external-source src/legacy/b1_10_port/headcalc.f90 --build "$outdir" --opt "$opt"
  "$outdir/rom0_test" > "$EVIDENCE/R16_o$opt.txt" 2>&1 || {
    tail -n 500 "$EVIDENCE/R16_o$opt.txt" >&2
    fail "R16 reference O$opt execution"
  }
  grep -Fq 'F_ROMV2_D5_REF_EXECUTION_COMPLETE=PASS' "$EVIDENCE/R16_o$opt.txt" || fail "missing R16 completion O$opt"
  [[ "$(grep -c 'F_ROMV2_D5_REF_STATE|' "$EVIDENCE/R16_o$opt.txt")" -eq 768 ]] || fail "expected 768 R16 states O$opt"
done

cmp "$EVIDENCE/R16_o0.txt" "$EVIDENCE/R16_o2.txt" || fail "R16 O0/O2 reference drift"
echo "F_ROMV2_D5_R16_O0_O2_IDENTITY=PASS"

python3 "$ANALYZER" --reference "$EVIDENCE/R16_o2.txt" --prereg "$PREREG" \
  --d4-result "$D4_RESULT" --output "$EVIDENCE/F-ROMV2_D5_RESULT.json" \
  | tee "$EVIDENCE/analyzer.txt"

sha256sum "$EVIDENCE/R16_o0.txt" "$EVIDENCE/R16_o2.txt" \
  "$EVIDENCE/F-ROMV2_D5_RESULT.json" "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"

echo "F_ROMV2_D5_ARCHITECTURE_DISCRIMINATOR=PASS"
