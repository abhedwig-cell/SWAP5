#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq127-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_VQ127_FAIL $*" >&2; exit 1; }

SUBJECT=1d66daadfe63b3a5c2bd7bf96b9d3e7311f3e717
[[ -z "$(git diff --name-only "$SUBJECT"..HEAD -- src)" ]] || fail "qualification mutated production source"
[[ "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_provider.f90)" == 90183cbe0f3f0b349e40fa6b0c65b2223ca8a739 ]] || fail "provider subject drift"
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == 556ed83dee4d5b159f1de7ae797af7106a0abe2e ]] || fail "runtime carrier subject drift"

COMMON=(-std=f2008 -pedantic-errors -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  gfortran "${COMMON[@]}" -Wno-error=unused-dummy-argument -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$OUT/provider.o"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J "$OUT" -I "$OUT" -c tests/fvq/test_fvq127_fsi39_ksatexm_independent.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/contract.o" "$OUT/provider.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  for m in F_VQ127_EXACT_B111_ORACLE=PASS F_VQ127_PER_NODE_ACTIVATION=PASS F_VQ127_DEFAULT_ROUTE_PRESERVED=PASS F_VQ127_BELOW_THRESHOLD_IDENTITY=PASS; do
    grep -Fq "$m" "$OUT/output.txt" || fail "missing O$opt marker $m"
  done
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || { diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true; fail "O0/O2 drift"; }
cat "$BUILD/o0/output.txt"
echo "F_VQ127_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'F_VQ127_FSI39_INDEPENDENT=PASS'
