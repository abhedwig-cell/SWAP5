#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=52b4608fdf548b89b154f19caeb97c1a5effe3de
PREREG=integration/f-rom/F-ROMV2_D20_PREREGISTRATION.json
PREREG_BLOB=af1cf1bd4ad8073fb6b9aade554f8ab72c2cbef7
AUTH=integration/f-rom/F-ROMV2_D20_STAGE2_AUTHORIZATION.json
AUTH_BLOB=d5ccb341ab0f836ac5f7d8504c955a50cdd25a61
PREFLIGHT=tests/rom/preflight_f_romv2_d20_hourly_persistence.py
TEST=tests/rom/test_f_romv2_d20_hourly_persistence_comparators.f90
ANALYZER=tests/rom/analyze_f_romv2_d20_hourly_persistence.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-romv2-d20-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROMV2_D20_EVIDENCE_DIR:-$ROOT/F-ROMV2-D20-EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROMV2_D20_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin integration/f-ci-canonical
LIVE="$(git rev-parse FETCH_HEAD)"
[[ "$LIVE" == "$BASE" ]] || fail "canonical advanced after D20 Stage-1 authority: $LIVE"
git merge-base --is-ancestor "$BASE" HEAD || fail "D20 candidate not descendant of Stage-2 base"
git diff --quiet "$BASE"...HEAD -- src reference || fail "D20 mutated src/reference"
[[ "$(git rev-parse HEAD:$PREREG)" == "$PREREG_BLOB" ]] || fail "D20 preregistration blob drift"
[[ "$(git rev-parse HEAD:$AUTH)" == "$AUTH_BLOB" ]] || fail "D20 Stage-2 authorization blob drift"

python3 - "$PREREG" "$AUTH" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); a=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_INTERNAL_PREFLIGHT_AND_SWAP_TRAJECTORY_EXECUTION"
assert p["temporal_design"]["total_steps_per_history"]==360
assert p["temporal_design"]["last_quarter_steps"]=="271..360"
assert [h["id"] for h in p["histories"]]==["P_UP","P_DOWN","P_ALT_A","P_ALT_B"]
assert a["stage"]=="STAGE2_MATCHED_R16_R2_AUTHORIZED"
assert a["original_preregistration_blob"]=="af1cf1bd4ad8073fb6b9aade554f8ab72c2cbef7"
assert a["stage1_execution"]["decision"]=="D20_FMC_ONE_HOUR_PREFLIGHT_PASS"
assert a["stage1_execution"]["SWAP_trajectory_evidence_consumed"] is False
assert a["stage2_authorized"] is True
assert a["production_rom_authorized"] is False
print("F_ROMV2_D20_STAGE2_LOCK=PASS")
PY

python3 "$PREFLIGHT" --prereg "$PREREG"   --output "$EVIDENCE/F-ROMV2_D20_PREFLIGHT_RESULT.json" | tee "$EVIDENCE/preflight.txt"
grep -Fq '"decision": "D20_FMC_ONE_HOUR_PREFLIGHT_PASS"'   "$EVIDENCE/F-ROMV2_D20_PREFLIGHT_RESULT.json" || fail "D20 preflight no-go"

for spec in "R16 16 10" "R2 2 80"; do
  read -r id n dz <<<"$spec"
  stub="$BUILD/stubs_n${n}.f90"
  python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90     --output "$stub" --nodes "$n" --dz-cm "$dz"
  for opt in 0 2; do
    outdir="$BUILD/${id}_o${opt}"
    python3 "$COMPILER" --root "$ROOT" --stub "$stub" --target "$TEST"       --external-source src/legacy/b1_10_port/headcalc.f90 --build "$outdir" --opt "$opt"
    "$outdir/rom0_test" > "$EVIDENCE/${id}_o${opt}.txt" 2>&1 || {
      tail -n 500 "$EVIDENCE/${id}_o${opt}.txt" >&2
      fail "${id} O${opt} execution"
    }
    grep -Fq 'F_ROMV2_D20_REF_EXECUTION_COMPLETE=PASS' "$EVIDENCE/${id}_o${opt}.txt"       || fail "${id} missing completion O${opt}"
    [[ "$(grep -c 'F_ROMV2_D20_REF_STATE|' "$EVIDENCE/${id}_o${opt}.txt")" -eq 1440 ]]       || fail "${id} expected 1440 states O${opt}"
  done
  cmp "$EVIDENCE/${id}_o0.txt" "$EVIDENCE/${id}_o2.txt" || fail "${id} O0/O2 drift"
  echo "F_ROMV2_D20_${id}_O0_O2_IDENTITY=PASS"
done

python3 "$ANALYZER"   --r16 "$EVIDENCE/R16_o2.txt" --r2 "$EVIDENCE/R2_o2.txt"   --prereg "$PREREG" --preflight "$EVIDENCE/F-ROMV2_D20_PREFLIGHT_RESULT.json"   --output "$EVIDENCE/F-ROMV2_D20_RESULT.json" | tee "$EVIDENCE/analyzer.txt"

sha256sum "$EVIDENCE"/R*_o*.txt "$EVIDENCE/F-ROMV2_D20_PREFLIGHT_RESULT.json"   "$EVIDENCE/F-ROMV2_D20_RESULT.json" "$EVIDENCE/preflight.txt" "$EVIDENCE/analyzer.txt"   > "$EVIDENCE/sha256.txt"

echo "F_ROMV2_D20_ONE_HOUR_COMPARATOR=PASS"
