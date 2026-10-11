#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
BUILD=$(mktemp -d /tmp/swap5-fci93-contract.XXXXXX)
trap 'rm -rf "$BUILD"' EXIT
for opt in 0 2; do
  python3 tests/rom/compile_f_rom0_fortran_closure.py --root "$PWD" \
    --stub tests/fsi/fsi04_real_headcalc_stubs.f90 \
    --target tests/fci/test_fci93_headed_contract_diagnostic.f90 \
    --build "$BUILD/o$opt" --opt "$opt" > "$BUILD/compile$opt.log" 2>&1 || { tail -n 30 "$BUILD/compile$opt.log"; exit 93; }
  "$BUILD/o$opt/rom0_test" > "$BUILD/output$opt.txt"
  cat "$BUILD/output$opt.txt"
done
cmp "$BUILD/output0.txt" "$BUILD/output2.txt"
echo 'FCI93_DIAGNOSTIC_O0_O2_IDENTITY=PASS_NOT_PRODUCTION_QUALIFICATION'
