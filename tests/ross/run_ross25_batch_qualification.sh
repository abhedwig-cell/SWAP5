#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RESEARCH_ROOT=${1:?usage: $0 RESEARCH_ROOT OUTPUT_ROOT}
OUTPUT_ROOT=${2:?usage: $0 RESEARCH_ROOT OUTPUT_ROOT}
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ross25-batch-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2" "$OUTPUT_ROOT"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "F_ROSS25_BATCH_FAIL $*" >&2; exit 1; }

CONTRACT=integration/f-ross/F-ROSS25_TIERED_WETTING_SEAM_QUALIFICATION_CONTRACT.json
FINGERPRINT=integration/f-ross/F-ROSS13_36_MATERIAL_N241_FINGERPRINT_AUTHORITY.json
ORACLE=tests/ross/generate_ross25_wetting_oracle.py
TEST=tests/ross/test_ross25_tiered_wetting_kernel.f90
AGG=tests/ross/aggregate_ross25_wetting_qualification.py
RESULT="$OUTPUT_ROOT/F-ROSS25_TIERED_WETTING_SEAM_QUALIFICATION_RESULT.json"

KERNEL_BLOB=438ee46e012e9eb183b8f2532437e2fe56aa18ed
MODEL_BLOB=5442fd7e7a2f392c9b796cd17c76b17977259f22
PROVIDER_BLOB=ac997bf06c56a37080d1c8db69b6d4208f4b75ca
POLICY_BLOB=a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9

for path in "$CONTRACT" "$FINGERPRINT" "$ORACLE" "$TEST" "$AGG"; do
  [[ -f "$path" ]] || fail "missing $path"
done
[[ -d "$RESEARCH_ROOT" ]] || fail "missing pinned research worktree"

grep -Fq '"status": "FROZEN_BEFORE_MEASUREMENT"' "$CONTRACT" || fail 'preregistration status drift'
grep -Fq '"case_count": 108' "$CONTRACT" || fail '108-case contract drift'
grep -Fq '"NO_MODEL_BINDING_WIDENING"' "$CONTRACT" || fail 'binding firewall drift'
grep -Fq '"NO_TEMPORAL_THRESHOLD_CHANGE"' "$CONTRACT" || fail 'temporal firewall drift'

BASE="$(git merge-base HEAD origin/integration/f-ci-canonical)"
[[ -n "$BASE" ]] || fail 'unable to resolve canonical merge-base'
git diff --quiet "$BASE" HEAD -- src reference || fail 'F-ROSS25 mutated src or reference'

test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_table_kernel.f90)" = "$KERNEL_BLOB" || fail 'admitted tiered kernel drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_model_binding.f90)" = "$MODEL_BLOB" || fail 'model binding drift'
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_table_provider.f90)" = "$PROVIDER_BLOB" || fail 'provider drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_execution_policy.f90)" = "$POLICY_BLOB" || fail 'execution policy drift'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -fopenmp -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  src/transaction/mod_transaction_reference.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
  src/solver/mod_rossfast_d3r_table_kernel.f90
  src/solver/mod_rossfast_d3r_table_provider.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
done

MATERIALS=(
  B01 B02 B03 B04 B05 B06 B07 B08 B09 B10 B11 B12 B13 B14 B15 B16 B17 B18
  O01 O02 O03 O04 O05 O06 O07 O08 O09 O10 O11 O12 O13 O14 O15 O16 O17 O18
)

for MATERIAL in "${MATERIALS[@]}"; do
  echo "F_ROSS25_BATCH_MATERIAL_BEGIN=$MATERIAL"
  MDIR="$OUTPUT_ROOT/$MATERIAL"
  mkdir -p "$MDIR"
  FIXTURE="$MDIR/fixture-$MATERIAL.txt"
  METADATA="$MDIR/metadata-$MATERIAL.json"
  OUT0="$MDIR/o0-$MATERIAL.txt"
  OUT2="$MDIR/o2-$MATERIAL.txt"
  FORTRAN="$MDIR/fortran-$MATERIAL.txt"

  python3 "$ORACLE"     --research-root "$RESEARCH_ROOT"     --contract "$CONTRACT"     --fingerprint-authority "$FINGERPRINT"     --material "$MATERIAL"     --fixture-out "$FIXTURE"     --metadata-out "$METADATA"

  python3 - "$METADATA" "$MATERIAL" <<'PY'
import json, sys
p,m=sys.argv[1:]
d=json.load(open(p))
assert d["work_unit"]=="F-ROSS25"
assert d["material"]==m
assert d["science_pass"] is True
assert d["science_case_count"]==3
assert d["kernel_fixture_case_count"]==3
assert d["table_fingerprint_matches_authority"] is True
assert d["candidate_domain_failure_count"]==0
assert d["candidate_envelope_failure_count"]==0
assert d["candidate_nonfinite_count"]==0
assert d["reference_nonfinite_count"]==0
assert d["reference_self_max"] <= 1.0e-9
PY

  "$BUILD/o0/test" "$MATERIAL" "$FIXTURE" > "$OUT0" 2>&1 || { cat "$OUT0" >&2; fail "O0 $MATERIAL"; }
  "$BUILD/o2/test" "$MATERIAL" "$FIXTURE" > "$OUT2" 2>&1 || { cat "$OUT2" >&2; fail "O2 $MATERIAL"; }
  grep -Fq 'F_ROSS25_CASE_COUNT=3' "$OUT0" || fail "O0 exact case count $MATERIAL"
  grep -Fq 'F_ROSS25_TIERED_WETTING_KERNEL=PASS' "$OUT0" || fail "O0 pass $MATERIAL"
  grep -Fq 'F_ROSS25_CASE_COUNT=3' "$OUT2" || fail "O2 exact case count $MATERIAL"
  grep -Fq 'F_ROSS25_TIERED_WETTING_KERNEL=PASS' "$OUT2" || fail "O2 pass $MATERIAL"
  cmp -s "$OUT0" "$OUT2" || { diff -u "$OUT0" "$OUT2" >&2 || true; fail "O0/O2 drift $MATERIAL"; }
  cp "$OUT0" "$FORTRAN"
  HASH="$(sha256sum "$OUT0" | awk '{print $1}')"
  python3 - "$METADATA" "$HASH" <<'PY'
import json, sys
p,digest=sys.argv[1:]
d=json.load(open(p))
d["production_kernel_qualification_pass"]=True
d["production_kernel_o0_o2_identical"]=True
d["production_kernel_o0_o2_sha256"]=digest
d["ross25_material_pass"]=bool(
    d["science_pass"]
    and d["table_fingerprint_matches_authority"]
    and d["production_kernel_qualification_pass"]
)
with open(p,"w") as f:
    json.dump(d,f,indent=2,sort_keys=True)
    f.write("\n")
PY
  rm -f "$FIXTURE" "$OUT0" "$OUT2"
  echo "F_ROSS25_BATCH_MATERIAL_PASS=$MATERIAL"
done

python3 "$AGG"   --input-root "$OUTPUT_ROOT"   --contract "$CONTRACT"   --output "$RESULT"

grep -Fq '"attempted_cases": 108' "$RESULT" || fail 'aggregate case count'
grep -Fq '"verdict": "QUALIFIED_RESEARCH_EVIDENCE_CURRENT_TIERED_ROSSFAST_WETTING_STATE_SOLVER_VALID_WITH_SEAM_CROSSINGS"' "$RESULT" || fail 'aggregate verdict'
echo "F_ROSS25_BATCH_QUALIFICATION=PASS"
cat "$RESULT"
