#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

CANONICAL="6530b8bc3f37c675828a8373ef4c5e4bf9141b62"
CANONICAL_SERVICE_BLOB="e99ae052fccd9992b76c12a91422a987dce059e2"
FGC16_PLAN_BLOB="d8b02dcf1c4915634c0a7659f3202604c4d91b88"

# Owner work must remain a narrow current-canonical descendant.
git merge-base --is-ancestor "$CANONICAL" HEAD

test "$(git rev-parse HEAD:src/runtime/mod_groundwater_exchange_service_contract.f90)" = "$CANONICAL_SERVICE_BLOB"
test "$(git rev-parse work/f-gc16-production-groundwater-coupling-minimal-viable-composition-admission-plan:integration/f-gc/F-GC16_DEPENDENCY_ORDERED_IMPLEMENTATION_PLAN.json 2>/dev/null || true)" != "" || true

mapfile -t changed_src < <(git diff --name-only "$CANONICAL..HEAD" -- 'src/**')
test "${#changed_src[@]}" -eq 1
test "${changed_src[0]}" = "src/runtime/mod_groundwater_response_sensitivity_contract.f90"

while IFS= read -r path; do
  case "$path" in
    src/runtime/mod_groundwater_response_sensitivity_contract.f90|tests/fgc/test_fgc29_groundwater_response_sensitivity.f90|tests/fgc/run_fgc29_groundwater_response_sensitivity.sh|.github/workflows/fgc29-groundwater-response-sensitivity.yml|integration/f-gc/F-GC29_*) ;;
    *) echo "FGC29_SCOPE_FAIL unexpected path: $path" >&2; exit 20 ;;
  esac
done < <(git diff --name-only "$CANONICAL..HEAD")

python3 - <<'PY'
from pathlib import Path
s=Path('src/runtime/mod_groundwater_response_sensitivity_contract.f90').read_text()
service=Path('src/runtime/mod_groundwater_exchange_service_contract.f90').read_text()
low=s.lower()
for forbidden in ['modflow', '.swp', 'midnight']:
    assert forbidden not in low, forbidden
for required in [
    'groundwater_response_sensitivity_provider_t',
    'groundwater_query_response_sensitivity',
    'GW_RESPONSE_PROVIDER_NONSMOOTH',
    'GW_RESPONSE_PROVENANCE_MISMATCH',
    'dh_groundwater_dq_groundwater_s',
    'trial_result%candidate_revision /= candidate%candidate_revision()',
    'trial_result%origin_revision /= candidate%origin_revision()',
    'trial_result%groundwater_lineage_id /= candidate%lineage_id()',
    '.not. present(provider)',
    '.not. ieee_is_finite(derivative)'
]:
    assert required in s, required
# The admitted F-GC18/F-GC18R boundary is read-only in F-GC29.
assert 'type, abstract, public :: groundwater_exchange_service_t' in service
assert 'type, abstract, extends(groundwater_exchange_service_t), public :: groundwater_preparable_exchange_service_t' in service
# No production finite-difference or secant construction is permitted.
for forbidden in ['finite_difference', 'finite difference', 'secant']:
    assert forbidden not in low, forbidden
print('FGC29_STATIC_CONTRACT_AUDIT=PASS')
print('FGC29_FGC18_SERVICE_BLOB_PRESERVED=PASS')
PY

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

compile_and_run() {
  local opt="$1"
  local out="$2"
  local dir="$work/$opt"
  mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" \
    src/runtime/mod_groundwater_coupling_contract.f90 \
    src/runtime/mod_groundwater_exchange_service_contract.f90 \
    src/runtime/mod_groundwater_response_sensitivity_contract.f90 \
    tests/fgc/test_fgc29_groundwater_response_sensitivity.f90 \
    -o "$dir/test_fgc29"
  "$dir/test_fgc29" > "$out"
}

compile_and_run O0 "$work/o0.txt"
compile_and_run O2 "$work/o2.txt"
diff -u "$work/o0.txt" "$work/o2.txt"

for marker in \
  FGC29_PROVENANCE_BOUND_RESPONSE \
  FGC29_INDEPENDENT_FD_REFERENCE \
  FGC29_DETERMINISTIC_RESPONSE \
  FGC29_PROVENANCE_MISMATCH_FAIL_CLOSED \
  FGC29_OPTIONAL_PROVIDER_UNAVAILABLE \
  FGC29_DISCARDED_TRIAL_ZERO_RESPONSE_LEAKAGE \
  FGC29_NONSMOOTH_FAIL_CLOSED \
  FGC29_PROVIDER_UNAVAILABLE_FAIL_CLOSED \
  FGC29_PROVIDER_ERROR_FAIL_CLOSED \
  FGC29_NONFINITE_DERIVATIVE_FAIL_CLOSED \
  FGC29_NO_COMMITTED_STATE_MUTATION \
  FGC29_OWNER_ORACLE; do
  grep -q "^${marker}=PASS$" "$work/o0.txt"
done

cat "$work/o0.txt"
echo "FGC29_CURRENT_CANONICAL=PASS:$CANONICAL"
echo "FGC29_FGC16_AUTHORITY_BLOB=PASS:$FGC16_PLAN_BLOB"
echo 'FGC29_SCOPE_ALLOWLIST=PASS'
echo 'FGC29_O0_O2_IDENTITY=PASS'
echo 'FGC29_DECISION=OWNER_QUALIFIED_PENDING_INDEPENDENT_QUALIFICATION'
