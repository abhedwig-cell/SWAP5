#!/usr/bin/env bash
set -euo pipefail
B="${TMPDIR:-/tmp}/low01a-tx-$$"; trap 'rm -rf "$B"' EXIT; mkdir -p "$B"
for opt in 0 2; do
 gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -O"$opt" -J "$B" -I "$B" \
  src/runtime/mod_fmr_legacy_qgwl_bottom_boundary_provider.f90 \
  src/runtime/mod_fmr_legacy_bottom_boundary_application_binding.f90 \
  tests/fmig431/test_fmig431_low01a_transaction_contract.f90 -o "$B/t$opt"
 "$B/t$opt" > "$B/o$opt"
 cat "$B/o$opt"
done
cmp -s "$B/o0" "$B/o2"
echo F-MIG431-LOW01A_TRANSACTION_O0_O2_IDENTITY=PASS
