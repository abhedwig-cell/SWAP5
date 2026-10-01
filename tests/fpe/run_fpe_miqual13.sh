#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-miqual13-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

ARGS=()
for n in 8 10 11 12 13 14 16; do
  dir="$BUILD/n$n"
  mkdir -p "$dir"
  python3 tests/rom/materialize_f_rom0_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --output "$dir/stub.f90" --nodes "$n" --dz-cm 10
  python3 tests/fpe/materialize_fpe_timeint03_binding.py     --source src/adapter/mod_reference_richards_legacy_binding.f90     --output "$dir/mod_fpe_timeint03_reference_binding.f90"
  python3 tests/fpe/materialize_fpe_timeint02_headcalc.py     --source src/legacy/b1_10_port/headcalc.f90     --output "$dir/headcalc_miqual13.f90"
  python3 tests/fpe/compile_fpe_timeint03_closure.py     --root "$ROOT" --stub "$dir/stub.f90"     --target tests/fpe/test_fpe_miqual13_reference_solve_scaling.f90     --external-source "$dir/headcalc_miqual13.f90"     --external-module-source "$dir/mod_fpe_timeint03_reference_binding.f90"     --build "$dir/run" --opt 3
  ARGS+=("$n=$dir/run/timeint03_test")
done

python3 tests/fpe/run_fpe_miqual13.py "${ARGS[@]}" | tee "$BUILD/result.txt"
grep -Fq 'F_PE_MIQUAL13_GATE=PASS' "$BUILD/result.txt"
echo "F_PE_MIQUAL13=PASS"
