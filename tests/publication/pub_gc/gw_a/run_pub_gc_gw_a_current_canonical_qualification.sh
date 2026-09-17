#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

CANONICAL_BASE=8e0de81a62527bc7d8e49068f1ffd4a8a85aeec3
SPEC_COMMIT=b6800d1337c2101b39d1c07e45ee808a35711926
DECISION_COMMIT=9ab529a7d905f73b27513320dfdac537339b90e8
OLD_QUALIFIED_HEAD=8a090fc9228574525e599817771aadb8ae176047
MODULE=tests/publication/pub_gc/gw_a/mod_pub_gc_gw_a.f90
TEST=tests/publication/pub_gc/gw_a/test_pub_gc_gw_a.f90
RUNNER=tests/publication/pub_gc/gw_a/run_pub_gc_gw_a_current_canonical_qualification.sh
WORKFLOW=.github/workflows/pub-gc-e1-origin-harness.yml

EXPECTED_MODULE_BLOB=ac725a64ffa96f4f08998e9aac7537af5ca76ba0
EXPECTED_TEST_BLOB=58711bc7eeab069ca937fd60e6e82e739bd5f156
EXPECTED_COUPLING_CONTRACT_BLOB=fc598d14eabafcb025bb55621f7b00d6d1816f10
EXPECTED_EXCHANGE_CONTRACT_BLOB=e99ae052fccd9992b76c12a91422a987dce059e2

# Immutable research chronology is external to this branch. The workflow fetches
# the documentation branch explicitly so these frozen authorities must exist as
# Git objects before qualification can proceed.
for commit in "$SPEC_COMMIT" "$DECISION_COMMIT" "$OLD_QUALIFIED_HEAD" "$CANONICAL_BASE"; do
  git cat-file -e "$commit^{commit}"
done

# This research branch must descend from the live canonical that was reconciled
# before the E1 harness was materialized.
git merge-base --is-ancestor "$CANONICAL_BASE" HEAD

# Reuse is allowed only because both the research component and its direct
# production contracts are byte-identical to the previously qualified state.
[[ "$(git rev-parse HEAD:$MODULE)" == "$EXPECTED_MODULE_BLOB" ]]
[[ "$(git rev-parse HEAD:$TEST)" == "$EXPECTED_TEST_BLOB" ]]
[[ "$(git rev-parse HEAD:src/runtime/mod_groundwater_coupling_contract.f90)" == "$EXPECTED_COUPLING_CONTRACT_BLOB" ]]
[[ "$(git rev-parse HEAD:src/runtime/mod_groundwater_exchange_service_contract.f90)" == "$EXPECTED_EXCHANGE_CONTRACT_BLOB" ]]
echo 'PUB_GC_GW_A_IMMUTABLE_REUSE=PASS'

# Research-only scope. Future E1 qualification may add files only below the
# dedicated e1_origin test surface and this one workflow; production src/** is
# never an admissible way to make this gate pass.
mapfile -t changed < <(git diff --name-only "$CANONICAL_BASE..HEAD")
for path in "${changed[@]}"; do
  case "$path" in
    tests/publication/pub_gc/gw_a/*) ;;
    tests/publication/pub_gc/e1_origin/*) ;;
    .github/workflows/pub-gc-e1-origin-harness.yml) ;;
    *)
      echo "PUB_GC_E1_RESEARCH_SCOPE_FAIL=$path" >&2
      exit 20
      ;;
  esac
done
if printf '%s\n' "${changed[@]}" | grep -q '^src/'; then
  echo 'PUB_GC_E1_PRODUCTION_MUTATION_FORBIDDEN' >&2
  exit 21
fi
echo 'PUB_GC_E1_RESEARCH_ONLY_SCOPE=PASS'

BUILD="${TMPDIR:-/tmp}/swap5-pub-gc-gw-a-current-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SOURCES=(
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_exchange_service_contract.f90
  "$MODULE"
  "$TEST"
)

for opt in 0 2; do
  dir="$BUILD/o$opt"
  mkdir -p "$dir"
  gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir" "${SOURCES[@]}" -o "$dir/test" 2>"$dir/compiler.txt"
  if grep -E 'Warning:' "$dir/compiler.txt" | grep -v -F '[-Wcompare-reals]'; then
    echo "PUB_GC_GW_A_UNEXPECTED_WARNING_O${opt}" >&2
    cat "$dir/compiler.txt" >&2
    exit 22
  fi
  "$dir/test" >"$dir/output.txt" 2>&1 || { cat "$dir/output.txt" >&2; exit 23; }
  grep -q '^PUB_GC_GW_A_COMPONENT_ORACLE=PASS$' "$dir/output.txt"
done

diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'PUB_GC_GW_A_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"

echo "PUB_GC_GW_A_CURRENT_HEAD=$(git rev-parse HEAD)"
echo "PUB_GC_GW_A_CANONICAL_BASE=$CANONICAL_BASE"
echo "PUB_GC_GW_A_SPEC_COMMIT=$SPEC_COMMIT"
echo "PUB_GC_GW_A_DECISION_COMMIT=$DECISION_COMMIT"
echo "PUB_GC_GW_A_PRIOR_QUALIFIED_HEAD=$OLD_QUALIFIED_HEAD"
echo "PUB_GC_GW_A_MODULE_BLOB=$(git rev-parse HEAD:$MODULE)"
echo "PUB_GC_GW_A_TEST_BLOB=$(git rev-parse HEAD:$TEST)"
echo "PUB_GC_GW_A_RUNNER_BLOB=$(git rev-parse HEAD:$RUNNER)"
echo 'PUB_GC_GW_A_CURRENT_CANONICAL_QUALIFICATION=PASS'
