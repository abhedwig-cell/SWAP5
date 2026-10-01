#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-miqual14-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT

ARGS=()
for spec in "N16_T13 16 13" "N32_T25 32 25" "N64_T49 64 49"; do
  set -- $spec
  label="$1"; n="$2"; tail="$3"; dir="$BUILD/$label"; mkdir -p "$dir"
  python3 tests/fpe/materialize_fpe_miqual14_geometry.py     --source tests/fmr/test_fpe_miqual07_serialized_benchmark.f90     --output "$dir/test.f90" --nodes "$n" --tail-start "$tail"
  python3 tests/rom/materialize_f_rom0_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --output "$dir/stub.f90" --nodes "$n" --dz-cm 10
  python3 tests/fpe/materialize_fpe_timeint02_headcalc.py     --source src/legacy/b1_10_port/headcalc.f90     --output "$dir/headcalc.f90"
  python3 tests/fpe/compile_fpe_timeint03_closure.py     --root "$ROOT" --stub "$dir/stub.f90" --target "$dir/test.f90"     --external-source "$dir/headcalc.f90" --build "$dir/run" --opt 3
  ARGS+=("$label=$dir/run/timeint03_test")
done

python3 tests/fmr/run_fpe_miqual14.py "${ARGS[@]}" | tee "$BUILD/result.txt"
grep -Fq 'F_PE_MIQUAL14_GATE=PASS' "$BUILD/result.txt"
echo "F_PE_MIQUAL14=PASS"
