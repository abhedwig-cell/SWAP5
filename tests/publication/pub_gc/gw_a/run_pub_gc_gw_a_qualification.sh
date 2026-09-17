#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

SPEC_COMMIT=b6800d1337c2101b39d1c07e45ee808a35711926
DECISION_COMMIT=9ab529a7d905f73b27513320dfdac537339b90e8
RESEARCH_BASE=154315df6906e6e1b3979290a1cfda82c9f3d1da
MODULE=tests/publication/pub_gc/gw_a/mod_pub_gc_gw_a.f90
TEST=tests/publication/pub_gc/gw_a/test_pub_gc_gw_a.f90
RUNNER=tests/publication/pub_gc/gw_a/run_pub_gc_gw_a_qualification.sh
WORKFLOW=.github/workflows/pub-gc-gw-a-qualification.yml

# Chronology and scope locks. The component is research-only and may not alter
# SWAP5 production/runtime science to make this gate pass.
git merge-base --is-ancestor "$SPEC_COMMIT" HEAD
git merge-base --is-ancestor "$DECISION_COMMIT" HEAD
git merge-base --is-ancestor "$RESEARCH_BASE" HEAD

allowed=("$MODULE" "$TEST" "$RUNNER" "$WORKFLOW")
mapfile -t changed < <(git diff --name-only "$RESEARCH_BASE..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do
    if [[ "$path" == "$candidate" ]]; then ok=1; break; fi
  done
  if [[ "$ok" -ne 1 ]]; then
    echo "PUB_GC_GW_A_SCOPE_FAIL=$path" >&2
    exit 20
  fi
done
echo 'PUB_GC_GW_A_RESEARCH_ONLY_SCOPE=PASS'

BUILD="${TMPDIR:-/tmp}/swap5-pub-gc-gw-a-$$"
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
    exit 21
  fi
  "$dir/test" >"$dir/output.txt" 2>&1 || { cat "$dir/output.txt" >&2; exit 22; }
  grep -q '^PUB_GC_GW_A_COMPONENT_ORACLE=PASS$' "$dir/output.txt"
done

diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'PUB_GC_GW_A_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"

echo "PUB_GC_GW_A_HEAD=$(git rev-parse HEAD)"
echo "PUB_GC_GW_A_MODULE_BLOB=$(git rev-parse HEAD:$MODULE)"
echo "PUB_GC_GW_A_TEST_BLOB=$(git rev-parse HEAD:$TEST)"
echo "PUB_GC_GW_A_RUNNER_BLOB=$(git rev-parse HEAD:$RUNNER)"
echo 'PUB_GC_GW_A_QUALIFICATION=PASS'
