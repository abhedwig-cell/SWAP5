#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 MATERIAL FIXTURE.txt METADATA.json" >&2
  exit 64
fi
MATERIAL=$1
FIXTURE=$2
METADATA=$3

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ross25-${MATERIAL}-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
fail() { echo "F_ROSS25_GATE_FAIL $*" >&2; exit 1; }

CONTRACT=integration/f-ross/F-ROSS25_TIERED_WETTING_SEAM_QUALIFICATION_CONTRACT.json
TEST=tests/ross/test_ross25_tiered_wetting_kernel.f90
KERNEL_BLOB=438ee46e012e9eb183b8f2532437e2fe56aa18ed
MODEL_BLOB=5442fd7e7a2f392c9b796cd17c76b17977259f22
PROVIDER_BLOB=ac997bf06c56a37080d1c8db69b6d4208f4b75ca
POLICY_BLOB=a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9

for path in "$CONTRACT" "$TEST" "$FIXTURE" "$METADATA"; do
  [[ -f "$path" ]] || fail "missing $path"
done

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

python3 - "$METADATA" "$MATERIAL" <<'PY'
import json, sys
path, material = sys.argv[1:]
m=json.load(open(path))
assert m["work_unit"]=="F-ROSS25"
assert m["material"]==material
assert m["science_pass"] is True
assert m["science_case_count"]==3
assert m["kernel_fixture_case_count"]==3
assert m["table_fingerprint_matches_authority"] is True
assert m["candidate_domain_failure_count"]==0
assert m["candidate_envelope_failure_count"]==0
assert m["candidate_nonfinite_count"]==0
assert m["reference_nonfinite_count"]==0
assert m["reference_self_max"] <= 1.0e-9
PY

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
    [[ -f "$source" ]] || fail "missing compile source $source"
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  if ! "$OUT/test" "$MATERIAL" "$FIXTURE" > "$OUT/output.txt" 2>&1; then
    cat "$OUT/output.txt" >&2
    fail "current tiered WETTING qualification O$opt $MATERIAL"
  fi
  grep -Fq 'F_ROSS25_CASE_COUNT=3' "$OUT/output.txt" || fail "missing exact case count O$opt"
  grep -Fq 'F_ROSS25_TIERED_WETTING_KERNEL=PASS' "$OUT/output.txt" || fail "missing qualification pass O$opt"
  cat "$OUT/output.txt"
  echo "F_ROSS25_${MATERIAL}_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 current tiered output drift $MATERIAL"
}
HASH="$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
python3 - "$METADATA" "$HASH" <<'PY'
import json, sys
path, digest = sys.argv[1:]
m=json.load(open(path))
m["production_kernel_qualification_pass"]=True
m["production_kernel_o0_o2_identical"]=True
m["production_kernel_o0_o2_sha256"]=digest
m["ross25_material_pass"]=bool(
    m["science_pass"]
    and m["table_fingerprint_matches_authority"]
    and m["production_kernel_qualification_pass"]
)
with open(path,"w") as f:
    json.dump(m,f,indent=2,sort_keys=True)
    f.write("\n")
PY

cp "$BUILD/o0/output.txt" "${GITHUB_WORKSPACE:-$ROOT}/F-ROSS25-${MATERIAL}-output.txt"
echo "F_ROSS25_${MATERIAL}_O0_O2_SHA256=$HASH"
echo "F_ROSS25_${MATERIAL}_MATERIAL_QUALIFICATION=PASS"
