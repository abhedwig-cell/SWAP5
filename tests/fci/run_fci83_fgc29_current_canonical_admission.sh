#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PRE_CANONICAL="6530b8bc3f37c675828a8373ef4c5e4bf9141b62"
OWNER_QUALIFIED_SOURCE="bf0bc93e359fba42237fd102ced7da9a5a84efad"
OWNER_CHECKPOINT="fc3a7a93b374fce885b12a9a447249bf745353f6"
OWNER_MODULE="src/runtime/mod_groundwater_response_sensitivity_contract.f90"
OWNER_MODULE_BLOB="fb8fd6a5447edd4fa4f664cd754c93d7db331969"
FGC18_SERVICE="src/runtime/mod_groundwater_exchange_service_contract.f90"
FGC18_SERVICE_BLOB="e99ae052fccd9992b76c12a91422a987dce059e2"
FVQ94_HEAD="43a8f8bdf0582674be39e95fe23dccb8e83fadd2"
FVQ94_STATUS_HEAD="4727a346da7d3e3fc124c13697e00946acd83ec6"
FVQ94_TEST="tests/fvq/test_fvq94_fgc29_independent_r1.f90"

git merge-base --is-ancestor "$PRE_CANONICAL" HEAD
git merge-base --is-ancestor "$OWNER_CHECKPOINT" HEAD
git merge-base --is-ancestor "$OWNER_QUALIFIED_SOURCE" HEAD
test "$(git rev-parse HEAD:$OWNER_MODULE)" = "$OWNER_MODULE_BLOB"
test "$(git rev-parse "$OWNER_QUALIFIED_SOURCE:$OWNER_MODULE")" = "$OWNER_MODULE_BLOB"
test "$(git rev-parse HEAD:$FGC18_SERVICE)" = "$FGC18_SERVICE_BLOB"
test "$(git rev-parse "$PRE_CANONICAL:$FGC18_SERVICE")" = "$FGC18_SERVICE_BLOB"

mapfile -t src_delta < <(git diff --name-only "$PRE_CANONICAL..HEAD" -- 'src/**')
test "${#src_delta[@]}" -eq 1
test "${src_delta[0]}" = "$OWNER_MODULE"

python3 - <<'PY'
import json
from pathlib import Path
status=json.loads(Path('qualification/F-VQ94_STATUS.json').read_text())
assert status['verdict'] == 'INDEPENDENTLY_QUALIFIED_FOR_CANONICAL_ADMISSION'
assert status['canonical_baseline'] == '6530b8bc3f37c675828a8373ef4c5e4bf9141b62'
assert status['owner']['qualified_source_head'] == 'bf0bc93e359fba42237fd102ced7da9a5a84efad'
assert status['owner']['production_module_blob'] == 'fb8fd6a5447edd4fa4f664cd754c93d7db331969'
assert status['owner']['preserved_F_GC18_service_blob'] == 'e99ae052fccd9992b76c12a91422a987dce059e2'
assert status['verifier_history']['qualified_verifier_head'] == '43a8f8bdf0582674be39e95fe23dccb8e83fadd2'
assert status['verifier_history']['qualified_conclusion'] == 'success'
assert status['independence']['verifier_production_delta'] == 'NONE'
assert status['independence']['finite_difference_in_production'] is False
print('FCI83_FVQ94_EVIDENCE_LOCK=PASS')
PY

python3 - <<'PY'
from pathlib import Path
s=Path('src/runtime/mod_groundwater_response_sensitivity_contract.f90').read_text()
low=s.lower()
assert 'public :: groundwater_trial_with_response_sensitivity' in s
assert 'public :: groundwater_query_response_sensitivity' not in s
assert s.count('call groundwater_trial_from_checkpoint') == 1
for forbidden in ['finite_difference', 'secant', 'modflow', '.swp', 'midnight']:
    assert forbidden not in low, forbidden
for required in [
    'GW_RESPONSE_PROVIDER_NONSMOOTH',
    'GW_RESPONSE_PROVENANCE_MISMATCH',
    '.not. ieee_is_finite(derivative)',
    'trial_result%candidate_revision /= candidate%candidate_revision()',
    'trial_result%origin_revision /= candidate%origin_revision()',
    'trial_result%groundwater_lineage_id /= candidate%lineage_id()'
]:
    assert required in s, required
print('FCI83_PRODUCTION_CONTRACT_AUDIT=PASS')
print('FCI83_FGC18_SERVICE_PRESERVED=PASS')
PY

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

git show "$FVQ94_HEAD:$FVQ94_TEST" > "$work/test_fvq94.f90"
test "$(git rev-parse "$FVQ94_STATUS_HEAD:qualification/F-VQ94_STATUS.json")" = \
     "$(git rev-parse HEAD:qualification/F-VQ94_STATUS.json)"

compile_owner() {
  local opt="$1"
  local out="$2"
  local dir="$work/owner_$opt"
  mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" \
    src/runtime/mod_groundwater_coupling_contract.f90 \
    src/runtime/mod_groundwater_exchange_service_contract.f90 \
    src/runtime/mod_groundwater_response_sensitivity_contract.f90 \
    tests/fgc/test_fgc29_groundwater_response_sensitivity.f90 \
    -o "$dir/test_owner"
  "$dir/test_owner" > "$out"
}

compile_independent() {
  local opt="$1"
  local out="$2"
  local dir="$work/vq_$opt"
  mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" \
    src/runtime/mod_groundwater_coupling_contract.f90 \
    src/runtime/mod_groundwater_exchange_service_contract.f90 \
    src/runtime/mod_groundwater_response_sensitivity_contract.f90 \
    "$work/test_fvq94.f90" \
    -o "$dir/test_vq"
  "$dir/test_vq" > "$out"
}

compile_owner O0 "$work/owner_o0.txt"
compile_owner O2 "$work/owner_o2.txt"
diff -u "$work/owner_o0.txt" "$work/owner_o2.txt"

compile_independent O0 "$work/vq_o0.txt"
compile_independent O2 "$work/vq_o2.txt"
diff -u "$work/vq_o0.txt" "$work/vq_o2.txt"

for marker in \
  FGC29_ATOMIC_TRIAL_RESPONSE_BINDING \
  FGC29_PROVENANCE_BOUND_RESPONSE \
  FGC29_INDEPENDENT_FD_REFERENCE \
  FGC29_RETRY_REPLACES_RESPONSE_WITH_ZERO_STALE_LEAKAGE \
  FGC29_REJECTED_TRIAL_ZERO_RESPONSE \
  FGC29_NONSMOOTH_FAIL_CLOSED \
  FGC29_NONFINITE_DERIVATIVE_FAIL_CLOSED \
  FGC29_NO_COMMITTED_STATE_MUTATION \
  FGC29_OWNER_ORACLE; do
  grep -q "^${marker}=PASS$" "$work/owner_o0.txt"
done

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
  grep -q "^${marker}=PASS$" "$work/vq_o0.txt"
done

cat "$work/owner_o0.txt"
cat "$work/vq_o0.txt"
echo "FCI83_PRE_CANONICAL=PASS:$PRE_CANONICAL"
echo "FCI83_OWNER_SOURCE=PASS:$OWNER_QUALIFIED_SOURCE"
echo "FCI83_OWNER_MODULE_BLOB=PASS:$OWNER_MODULE_BLOB"
echo "FCI83_FVQ94_HEAD=PASS:$FVQ94_HEAD"
echo 'FCI83_PRODUCTION_DELTA=PASS:ONE_ADDITIVE_MODULE'
echo 'FCI83_OWNER_O0_O2_IDENTITY=PASS'
echo 'FCI83_INDEPENDENT_O0_O2_IDENTITY=PASS'
echo 'FCI83_DECISION=QUALIFIED_FOR_CANONICAL_ADMISSION'
