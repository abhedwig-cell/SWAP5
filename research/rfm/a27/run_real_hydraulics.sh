#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
B="$(mktemp -d)";trap 'rm -rf "$B"' EXIT
for opt in 0 2;do
 "${FC:-gfortran}" -std=f2008 -ffree-line-length-none -fcheck=all -O"$opt" -J"$B" -I"$B" \
 src/process/macropore/mod_ppa_wu05a6_saturated_exchange_rate.f90 \
 src/solver/mod_soil_water_solver_contract.f90 src/solver/mod_b110_default_mvg_provider.f90 \
 research/rfm/a27/test_real_hydraulics.f90 -o "$B/test"
 "$B/test" tests/fpe/data/fpe_elastic05_staringreeks_2018.csv "${1:-hydraulic}" > "$B/o$opt"
done
cmp "$B/o0" "$B/o2"
cat "$B/o2"
echo 'A27_REAL_HYDRAULICS_O0_O2=PASS' >&2
