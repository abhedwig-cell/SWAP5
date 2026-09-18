#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
PREREG_COMMIT=4387d8a35692692faacff4235cb40524dc51ea90
PREREG=integration/f-rom/ROM1AR2_PREREGISTRATION.json
D3_STATUS=integration/f-rom/ROM1AR1D3_STATUS.json
PARENT=integration/f-rom/F-ROM1A_PREREGISTRATION.json
TEST=tests/rom/test_rom1ar2_reachable_state_library.f90
ANALYZER=tests/rom/analyze_rom1ar2_reachable_state_library.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rom1ar2-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${ROM1AR2_EVIDENCE_DIR:-$ROOT/ROM1AR2_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "ROM1AR2_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "R2 preregistration not ancestor"
git diff --quiet "$PREREG_COMMIT"...HEAD -- src reference || fail "R2 changed src/reference"
echo "ROM1AR2_SOURCE_FREEZE=PASS"

python3 - "$PREREG" "$D3_STATUS" "$PARENT" <<'PY'
import json,sys
r=json.load(open(sys.argv[1])); d=json.load(open(sys.argv[2])); p=json.load(open(sys.argv[3]))
assert r["phase"]=="PREREGISTERED_BEFORE_HELDOUT_LIBRARY_EXECUTION"
assert r["reference_policy_authority"]["decision"]=="ROM1AR1D3_DISCOVERY_LOCAL_PLUS_TOTAL_FALLBACK_QUALIFIED"
assert r["reference_policy_authority"]["frozen_before_heldout_exposure"] is True
assert r["reference_policy_authority"]["policy_retuning_from_heldout_allowed"] is False
assert r["library"]["discovery_histories"]==[x["id"] for x in p["history_design"]["discovery_histories"]]
assert r["library"]["held_out_histories"]==[x["id"] for x in p["history_design"]["held_out_histories"]]
assert r["library"]["steps_per_history"]==64
assert r["library"]["total_state_count"]==768
assert r["library"]["B14_generated"] is False
assert d["decision"]=="ROM1AR1D3_DISCOVERY_LOCAL_PLUS_TOTAL_FALLBACK_QUALIFIED"
assert d["research_reference_policy_frozen"] is True
assert d["heldout_exposed"] is False
print("ROM1AR2_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    tail -n 350 "$EVIDENCE/o$opt.txt" >&2
    fail "R2 library execution O$opt"
  }
  grep -Fq 'ROM1AR2_EXECUTION_COMPLETE=PASS' "$EVIDENCE/o$opt.txt" || fail "missing R2 completion O$opt"
  [[ "$(grep -c 'ROM1AR2_STATE|' "$EVIDENCE/o$opt.txt")" -eq 768 ]] || fail "expected 768 states O$opt"
done
cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" || fail "R2 O0/O2 drift"

python3 "$ANALYZER" --input "$EVIDENCE/o2.txt" --repeat "$EVIDENCE/o0.txt"   --output "$EVIDENCE/ROM1AR2_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/ROM1AR2_RESULT.json"
sha256sum "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" "$EVIDENCE/ROM1AR2_RESULT.json"   "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "ROM1AR2_EVIDENCE_PRESERVED=PASS"
