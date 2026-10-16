#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
bash tests/fci/run_fci93_non_m1_fixed_k_qualification.sh --verify-only
BUILD=$(mktemp -d /tmp/swap5-fci93-fixed-k-components.XXXXXX)
trap 'rm -rf "$BUILD"' EXIT
test "$(git hash-object tests/fci/test_fci93_headed_contract_diagnostic.f90)" = "$(git rev-parse 85866972d3e2ea2dff835b955f73ae1009d02006:tests/fci/test_fci93_headed_contract_diagnostic.f90)"
for case in tests/m1/test_m1_c3_fixed_top_conductivity.f90 tests/fci/test_fci93_headed_contract_diagnostic.f90 tests/fsi/test_fsi39_b110_ksatexm.f90; do
  tag="$(basename "${case%.f90}")"
  for opt in 0 2; do
    out="$BUILD/${tag}-o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py --root "$ROOT" --stub tests/fsi/fsi04_real_headcalc_stubs.f90 --target "$case" --build "$out" --opt "$opt"
    "$out/rom0_test" > "$BUILD/${tag}-o$opt.txt"
  done
  cmp "$BUILD/${tag}-o0.txt" "$BUILD/${tag}-o2.txt"
  cat "$BUILD/${tag}-o0.txt"
done
echo 'FCI93_FIXED_K_M1_AND_HEADED_COMPONENT_O0_O2=PASS'
