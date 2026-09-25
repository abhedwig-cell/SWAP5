#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fahl-governance-ksatexm-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SRC=(
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_adaptive_hydraulic_builder.f90
  src/solver/mod_b110_adaptive_hydraulic_cache.f90
  src/solver/mod_b110_adaptive_hydraulic_provider.f90
)
for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for source in "${SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     tests/fahl/test_fahl_governance_ksatexm_fallback.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" | tee "$OUT/output.txt"
  grep -Fq 'FAHL_KSATEXM_ANALYTICAL_FALLBACK=PASS' "$OUT/output.txt"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FAHL_KSATEXM_O0_O2_IDENTITY=PASS'
