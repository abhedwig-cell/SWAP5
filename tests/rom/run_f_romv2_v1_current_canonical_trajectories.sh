#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG=integration/f-rom/F-ROMV2_V1_PREREGISTRATION.json
PREREG_BLOB=91069b15c64fafedbced5b5f1c02d24468490022
TEST=tests/rom/test_f_romv2_v1_current_canonical_trajectories.f90
ANALYZER=tests/rom/analyze_f_romv2_v1_current_canonical_trajectories.py
C2_ANALYZER=tests/rom/analyze_f_romv2_v1_c2_blind.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-romv2-v1-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROMV2_V1_EVIDENCE_DIR:-$ROOT/F-ROMV2-V1-EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROMV2_V1_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin integration/f-ci-canonical
LIVE="$(git rev-parse FETCH_HEAD)"
git merge-base --is-ancestor "$LIVE" HEAD || fail "candidate is not descendant of live canonical"
BASE="$(git merge-base "$LIVE" HEAD)"
[[ "$BASE" == "$LIVE" ]] || fail "live canonical merge-base mismatch"
git diff --quiet "$LIVE"...HEAD -- src reference || fail "V1 branch changes src/reference"
[[ "$(git rev-parse HEAD:$PREREG)" == "$PREREG_BLOB" ]] || fail "V1 preregistration blob drift"

python3 - "$PREREG" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p["phase"]=="PREREGISTERED_BEFORE_CURRENT_CANONICAL_TRAJECTORY_GENERATION"
assert p["frozen_state"]["id"]=="C2"
assert p["frozen_state"]["dimension"]==2
assert p["closure"]["family"]=="FORCING_SPECIFIC_ONE_NEAREST_NEIGHBOR_TRANSITION_TABLE"
assert p["ood_gate"]["state"].startswith("for the exact forcing tuple, C2 query must lie inside the closed convex hull")
assert [x["id"] for x in p["new_blind_validation_histories"]]==["V01","V02","V03","V04"]
assert p["research_reference_policy"]["scope"]=="RESEARCH_REFERENCE_ONLY_NOT_PRODUCTION_FALLBACK"
assert p["firewalls"][0]=="NO_H01_H04_BLIND_REUSE"
print("F_ROMV2_V1_PREREGISTRATION_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90" \
    --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    tail -n 400 "$EVIDENCE/o$opt.txt" >&2
    fail "current-canonical trajectory execution O$opt"
  }
  grep -Fq 'F_ROMV2_V1_EXECUTION_COMPLETE=PASS' "$EVIDENCE/o$opt.txt" || fail "missing completion O$opt"
  [[ "$(grep -c 'F_ROMV2_V1_STATE|' "$EVIDENCE/o$opt.txt")" -eq 768 ]] || fail "expected 768 states O$opt"
done

cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" || fail "O0/O2 trajectory output drift"

python3 "$ANALYZER" --input "$EVIDENCE/o2.txt" --repeat "$EVIDENCE/o0.txt" \
  --output "$EVIDENCE/F-ROMV2_V1_TRAJECTORY_RESULT.json" | tee "$EVIDENCE/trajectory-analyzer.txt"

grep -Fq '"decision": "F_ROMV2_V1_CURRENT_CANONICAL_TRAJECTORIES_QUALIFIED"' \
  "$EVIDENCE/F-ROMV2_V1_TRAJECTORY_RESULT.json" || fail "trajectory authority no-go"

python3 "$C2_ANALYZER" --input "$EVIDENCE/o2.txt" --prereg "$PREREG" \
  --output "$EVIDENCE/F-ROMV2_V1_C2_RESULT.json" | tee "$EVIDENCE/c2-analyzer.txt"

grep -Fq '"decision": "V2_V1_C2_BLIND_HYDRAULIC_FEASIBILITY_PASS"' \
  "$EVIDENCE/F-ROMV2_V1_C2_RESULT.json" || fail "C2 blind feasibility no-go"

sha256sum "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" \
  "$EVIDENCE/F-ROMV2_V1_TRAJECTORY_RESULT.json" "$EVIDENCE/trajectory-analyzer.txt" \
  "$EVIDENCE/F-ROMV2_V1_C2_RESULT.json" "$EVIDENCE/c2-analyzer.txt" \
  > "$EVIDENCE/sha256.txt"

echo "F_ROMV2_V1_TRAJECTORY_AUTHORITY=PASS"
echo "F_ROMV2_V1_C2_BLIND_GATE=PASS"
