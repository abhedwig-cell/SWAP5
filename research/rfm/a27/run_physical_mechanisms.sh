#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
B="$(mktemp -d)";trap 'rm -rf "$B"' EXIT
for opt in 0 2;do
 "${FC:-gfortran}" -std=f2008 -ffree-line-length-none -fcheck=all -O"$opt" -J"$B" -I"$B" \
 src/runtime/mod_macropore_continuation_state.f90 \
 src/process/macropore/mod_ppa_wu05a6_sorptivity_rate.f90 \
 src/process/macropore/mod_ppa_wu05a6_unsat_absorption_rate.f90 \
 src/process/macropore/mod_ppa_wu05a6_sorptivity_history.f90 \
 src/process/macropore/mod_ppa_wu05a6_saturated_exchange_rate.f90 \
 research/rfm/a27/test_physical_mechanisms.f90 -o "$B/test"
 "$B/test" > "$B/o$opt"
done
cmp "$B/o0" "$B/o2";cat "$B/o2"
