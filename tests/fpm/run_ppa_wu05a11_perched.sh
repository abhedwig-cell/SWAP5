#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${TMPDIR:-/tmp}/swap5-ppa-wu05a11"
rm -rf "$BUILD"
mkdir -p "$BUILD"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all)
MODULE_SRC=(
  src/solver/mod_soil_water_solver_contract.f90
  src/runtime/mod_macropore_continuation_state.f90
  src/process/macropore/mod_ppa_wu05a5_top_partition.f90
  src/process/macropore/mod_ppa_wu05a5_multi_domain_process.f90
  src/process/macropore/mod_ppa_wu05a6_sorptivity_rate.f90
  src/process/macropore/mod_ppa_wu05a6_unsat_absorption_rate.f90
  src/process/macropore/mod_ppa_wu05a6_saturated_exchange_rate.f90
  src/process/macropore/mod_ppa_wu05a6_saturated_sources.f90
  src/process/macropore/mod_ppa_wu05a6_rapid_drain_rate.f90
  src/process/macropore/mod_ppa_wu05a6_top_inflow_limiter.f90
  src/process/macropore/mod_ppa_wu05a6_sorptivity_history.f90
  src/process/macropore/mod_ppa_wu05a6_rate_bundle.f90
  src/process/macropore/mod_macropore_standard_storage.f90
  src/runtime/mod_macropore_standard_rate_adapter.f90
  src/runtime/mod_fmr_macropore_configuration.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fpm/test_ppa_wu05a11_perched_carrier.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" | tee "$OUT/out.txt"
  grep -Fq "PPA_WU05A11_PERCHED_SOURCE_ORACLE=PASS" "$OUT/out.txt"
  grep -Fq "PPA_WU05A11_PERCHED_FMR_CARRIER=PASS" "$OUT/out.txt"
done

cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt"
echo "PPA_WU05A11_PERCHED_GATE=PASS"
