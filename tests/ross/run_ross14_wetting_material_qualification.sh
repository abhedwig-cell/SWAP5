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
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ross14-${MATERIAL}-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "F_ROSS14_GATE_FAIL $*" >&2; exit 1; }

CONTRACT=integration/f-ross/F-ROSS14_TOP_WETTING_FORCING_ENVELOPE_CONTRACT.json
P2E10_RESULT=docs/publication/P2E10_E0_BROAD_PAIRED_MATRIX_RESULT.json
FINGERPRINT=integration/f-ross/F-ROSS13_36_MATERIAL_N241_FINGERPRINT_AUTHORITY.json
TEST=tests/ross/test_ross14_wetting_kernel_equivalence.f90

MODEL_BINDING_BLOB=5442fd7e7a2f392c9b796cd17c76b17977259f22
KERNEL_BLOB=034136c193b287bcf9a953a9b89df2a8fb0c97cc
PROVIDER_BLOB=ac997bf06c56a37080d1c8db69b6d4208f4b75ca
POLICY_BLOB=a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9
P2E10_RESULT_BLOB=83864f6379279725fa97d24d57936f590d3c2174
FINGERPRINT_BLOB=01fa631a245f3011b1007b2888b0528b111ee17f

[[ -f "$CONTRACT" ]] || fail 'missing F-ROSS14 contract'
[[ -f "$FIXTURE" ]] || fail 'missing research fixture'
[[ -f "$METADATA" ]] || fail 'missing research metadata'

grep -Fq '"production_implementation": false' "$CONTRACT" || fail 'production-mutation firewall missing'
grep -Fq '"NO_GLOBAL_SYMMETRIC_ENVELOPE_FRACTION_INCREASE"' "$CONTRACT" || fail 'one-sided scope firewall missing'
grep -Fq '"target_internal_top_flux_over_initial_K": -0.025' "$CONTRACT" || fail 'target top forcing drift'

CURRENT_BASE="$(git merge-base HEAD origin/integration/f-ci-canonical)"
[[ -n "$CURRENT_BASE" ]] || fail 'unable to resolve current canonical merge-base'
git diff --quiet "$CURRENT_BASE" HEAD -- src reference || fail 'preproduction F-ROSS14 mutated src or reference'
echo "F_ROSS14_RECONCILED_BASE=$CURRENT_BASE"

test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_model_binding.f90)" = "$MODEL_BINDING_BLOB" || fail 'model binding drift'
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_table_kernel.f90)" = "$KERNEL_BLOB" || fail 'table kernel drift'
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_table_provider.f90)" = "$PROVIDER_BLOB" || fail 'table provider drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_execution_policy.f90)" = "$POLICY_BLOB" || fail 'execution policy drift'
test "$(git rev-parse HEAD:$P2E10_RESULT)" = "$P2E10_RESULT_BLOB" || fail 'P2E10 result drift'
test "$(git rev-parse HEAD:$FINGERPRINT)" = "$FINGERPRINT_BLOB" || fail 'fingerprint authority drift'

python3 - "$METADATA" "$MATERIAL" <<'PY'
import json, sys
p, material = sys.argv[1:]
m = json.load(open(p))
assert m["work_unit"] == "F-ROSS14"
assert m["material"] == material
assert m["science_pass"] is True
assert m["science_case_count"] == 3
assert m["table_fingerprint_matches_authority"] is True
assert m["kernel_fixture_case_count"] == 27
assert m["inadmissible_transition_route_count"] == 0
assert m["candidate_domain_failure_count"] == 0
assert m["candidate_envelope_failure_count"] == 0
assert m["candidate_nonfinite_count"] == 0
assert m["reference_nonfinite_count"] == 0
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -fopenmp -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  src/transaction/mod_transaction_reference.f90
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
    fail "production-kernel equivalence O$opt $MATERIAL"
  fi
  grep -Fq 'F_ROSS14_KERNEL_CASE_COUNT=27' "$OUT/output.txt" || fail "missing exact case count O$opt"
  grep -Fq 'F_ROSS14_PRODUCTION_KERNEL_EQUIVALENCE=PASS' "$OUT/output.txt" || fail "missing kernel pass O$opt"
  cat "$OUT/output.txt"
  echo "F_ROSS14_${MATERIAL}_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 kernel-equivalence drift $MATERIAL"
}

HASH="$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
python3 - "$METADATA" "$HASH" <<'PY'
import json, sys
path, digest = sys.argv[1:]
p = open(path)
m = json.load(p)
p.close()
m["production_kernel_equivalence_pass"] = True
m["production_kernel_o0_o2_identical"] = True
m["production_kernel_o0_o2_sha256"] = digest
m["ross14_material_pass"] = bool(
    m["science_pass"]
    and m["table_fingerprint_matches_authority"]
    and m["production_kernel_equivalence_pass"]
)
with open(path, "w") as f:
    json.dump(m, f, indent=2, sort_keys=True)
    f.write("\n")
PY

echo "F_ROSS14_${MATERIAL}_O0_O2_SHA256=$HASH"
echo "F_ROSS14_${MATERIAL}_MATERIAL_QUALIFICATION=PASS"
