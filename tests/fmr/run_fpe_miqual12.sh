#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-miqual12-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

bash tests/fmr/run_fpe_miqual06_serialized_manager.sh | tee "$BUILD/miqual06.txt"
grep -Fq 'F_PE_MIQUAL06_SERIALIZED_RUNTIME_SEAM=PASS' "$BUILD/miqual06.txt"

python3 tests/fpe/materialize_fpe_miqual09_length.py   --source tests/fmr/test_fpe_miqual07_serialized_benchmark.f90   --output "$BUILD/test_fpe_miqual12_attribution.f90"

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10
python3 tests/fpe/materialize_fpe_timeint02_headcalc.py   --source src/legacy/b1_10_port/headcalc.f90   --output "$BUILD/headcalc_miqual12.f90"

python3 tests/fpe/compile_fpe_timeint03_closure.py   --root "$ROOT"   --stub "$BUILD/stub.f90"   --target "$BUILD/test_fpe_miqual12_attribution.f90"   --external-source "$BUILD/headcalc_miqual12.f90"   --build "$BUILD/runtime" --opt 3

python3 tests/fmr/run_fpe_miqual12.py "$BUILD/runtime/timeint03_test" | tee "$BUILD/result.txt"
grep -Fq 'F_PE_MIQUAL12=PASS' "$BUILD/result.txt"
