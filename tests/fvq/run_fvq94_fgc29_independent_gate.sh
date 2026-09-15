#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

CANONICAL="6530b8bc3f37c675828a8373ef4c5e4bf9141b62"
OWNER_HEAD="bf0bc93e359fba42237fd102ced7da9a5a84efad"
OWNER_MODULE="src/runtime/mod_groundwater_response_sensitivity_contract.f90"
OWNER_MODULE_BLOB="fb8fd6a5447edd4fa4f664cd754c93d7db331969"
CANONICAL_SERVICE_BLOB="e99ae052fccd9992b76c12a91422a987dce059e2"

# The verifier branch is evidence-only and is rooted at the audited canonical.
git merge-base --is-ancestor "$CANONICAL" HEAD
test "$(git merge-base "$CANONICAL" "$OWNER_HEAD")" = "$CANONICAL"
test "$(git rev-parse "$OWNER_HEAD:$OWNER_MODULE")" = "$OWNER_MODULE_BLOB"
test "$(git rev-parse "$CANONICAL:src/runtime/mod_groundwater_exchange_service_contract.f90")" = "$CANONICAL_SERVICE_BLOB"
test "$(git rev-parse "$OWNER_HEAD:src/runtime/mod_groundwater_exchange_service_contract.f90")" = "$CANONICAL_SERVICE_BLOB"

mapfile -t owner_src_delta < <(git diff --name-only "$CANONICAL..$OWNER_HEAD" -- 'src/**')
test "${#owner_src_delta[@]}" -eq 1
test "${owner_src_delta[0]}" = "$OWNER_MODULE"

if git diff --name-only "$CANONICAL..HEAD" -- 'src/**' | grep -q .; then
  echo 'FVQ94_SCOPE_FAIL verifier branch modifies production source' >&2
  exit 20
fi
while IFS= read -r path; do
  case "$path" in
    tests/fvq/test_fvq94_fgc29_independent.f90|tests/fvq/run_fvq94_fgc29_independent_gate.sh|.github/workflows/f-vq94-fgc29-independent.yml|qualification/F-VQ94_*) ;;
    *) echo "FVQ94_SCOPE_FAIL unexpected verifier path: $path" >&2; exit 21 ;;
  esac
done < <(git diff --name-only "$CANONICAL..HEAD")

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
git show "$OWNER_HEAD:$OWNER_MODULE" > "$work/mod_groundwater_response_sensitivity_contract.f90"

python3 - "$work/mod_groundwater_response_sensitivity_contract.f90" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
low=s.lower()
assert 'public :: groundwater_trial_with_response_sensitivity' in s
assert 'public :: groundwater_query_response_sensitivity' not in s
assert s.count('call groundwater_trial_from_checkpoint') == 1
for token in ['finite_difference', 'secant', 'modflow', '.swp', 'midnight']:
    assert token not in low, token
for required in [
    'GW_RESPONSE_PROVIDER_NONSMOOTH',
    'GW_RESPONSE_PROVENANCE_MISMATCH',
    '.not. ieee_is_finite(derivative)',
    'trial_result%candidate_revision /= candidate%candidate_revision()',
    'trial_result%origin_revision /= candidate%origin_revision()',
    'trial_result%groundwater_lineage_id /= candidate%lineage_id()'
]:
    assert required in s, required
print('FVQ94_OWNER_STATIC_CONTRACT=PASS')
print('FVQ94_FGC18_SERVICE_BYTE_PRESERVATION=PASS')
PY

compile_and_run() {
  local opt="$1"
  local out="$2"
  local dir="$work/$opt"
  mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" \
    src/runtime/mod_groundwater_coupling_contract.f90 \
    src/runtime/mod_groundwater_exchange_service_contract.f90 \
    "$work/mod_groundwater_response_sensitivity_contract.f90" \
    tests/fvq/test_fvq94_fgc29_independent.f90 \
    -o "$dir/test_fvq94"
  "$dir/test_fvq94" > "$out"
}

compile_and_run O0 "$work/o0.txt"
compile_and_run O2 "$work/o2.txt"
diff -u "$work/o0.txt" "$work/o2.txt"

for marker in \
  FVQ94_ATOMIC_NATIVE_SINGLE_TRIAL \
  FVQ94_EXACT_PROVENANCE \
  FVQ94_INDEPENDENT_FIVE_POINT_FD \
  FVQ94_RETRY_ZERO_STALE_CONTRIBUTION \
  FVQ94_REJECTED_TRIAL_ZERO_RESPONSE \
  FVQ94_UNSUPPORTED_PROVIDER_FAIL_CLOSED \
  FVQ94_NONSMOOTH_FAIL_CLOSED \
  FVQ94_NONFINITE_FAIL_CLOSED \
  FVQ94_COMMITTED_STATE_UNCHANGED \
  FVQ94_INDEPENDENT_ORACLE; do
  grep -q "^${marker}=PASS$" "$work/o0.txt"
done

cat "$work/o0.txt"
echo "FVQ94_CANONICAL=PASS:$CANONICAL"
echo "FVQ94_OWNER_HEAD=PASS:$OWNER_HEAD"
echo "FVQ94_OWNER_MODULE_BLOB=PASS:$OWNER_MODULE_BLOB"
echo 'FVQ94_VERIFIER_PRODUCTION_DELTA=PASS:NONE'
echo 'FVQ94_O0_O2_IDENTITY=PASS'
echo 'FVQ94_DECISION=INDEPENDENTLY_QUALIFIED_FOR_CANONICAL_ADMISSION'
