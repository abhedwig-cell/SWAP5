#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=63b19be26f64e73eb9328e22d187af9f12cccff9
PREREG=integration/f-rom/ROM1AD2_PREREGISTRATION.json
D1_STATUS=integration/f-rom/ROM1AD1_STATUS.json
TEST=tests/rom/test_rom1ad2_mode2_fallback.f90
ANALYZER=tests/rom/analyze_rom1ad2_mode2_fallback.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rom1ad2-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${ROM1AD2_EVIDENCE_DIR:-$ROOT/ROM1AD2_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "ROM1AD2_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "D2 preregistration not ancestor"
git diff --quiet "$PREREG_COMMIT"...HEAD -- src reference || fail "D2 changed src/reference"
echo "ROM1AD2_SOURCE_FREEZE=PASS"

python3 - "$PREREG" "$D1_STATUS" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); d=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_POLICY_EXECUTION"
assert p["predecessors"]["ROM1AD1"]=="ROM1AD1_RETRY_TOTAL_ONLY_WITHIN_REPRESENTATION_BOUND"
assert p["qualification_matrix"]["material"]=="B01"
assert len(p["qualification_matrix"]["trajectories"])==2
assert p["qualification_matrix"]["steps_per_trajectory"]==64
assert p["qualification_matrix"]["held_out_histories_used"] is False
assert p["qualification_matrix"]["B14_used"] is False
assert p["frozen_controls"]["original_total_balance_tolerance_cm_per_day"]==1e-12
assert p["frozen_controls"]["compartment_balance_tolerance_cm_per_day"]==1e-12
assert p["policy"]["failed_residual_used_to_choose_tolerance"] is False
assert d["decision"]=="ROM1AD1_RETRY_TOTAL_ONLY_WITHIN_REPRESENTATION_BOUND"
assert d["mode2_research_fallback_qualified"] is False
print("ROM1AD2_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    cat "$EVIDENCE/o$opt.txt" >&2
    fail "D2 executable O$opt"
  }
  cat "$EVIDENCE/o$opt.txt"
  grep -Fq 'ROM1AD2_EXECUTION_COMPLETE=PASS' "$EVIDENCE/o$opt.txt" || fail "missing D2 completion O$opt"
  [[ "$(grep -c 'ROM1AD2_CASE_PASS|' "$EVIDENCE/o$opt.txt")" -eq 2 ]] || fail "expected two case passes O$opt"
  [[ "$(grep -c 'ROM1AD2_STEP|' "$EVIDENCE/o$opt.txt")" -eq 128 ]] || fail "expected 128 committed steps O$opt"
done
cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" || fail "D2 O0/O2 output drift"

python3 "$ANALYZER" --input "$EVIDENCE/o2.txt" --repeat "$EVIDENCE/o0.txt"   --output "$EVIDENCE/ROM1AD2_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/ROM1AD2_RESULT.json"
sha256sum "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" "$EVIDENCE/ROM1AD2_RESULT.json"   "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "ROM1AD2_EVIDENCE_PRESERVED=PASS"
