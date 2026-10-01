#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-miqual06-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

bash tests/fpe/run_fpe_nlglob14z43f.sh | tee "$BUILD/z43f.txt"
grep -Fq 'F_PE_NLGLOB14Z43F=PASS' "$BUILD/z43f.txt"

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10
python3 tests/fpe/materialize_fpe_timeint02_headcalc.py   --source src/legacy/b1_10_port/headcalc.f90   --output "$BUILD/headcalc_miqual06.f90"

python3 tests/fpe/compile_fpe_timeint03_closure.py   --root "$ROOT"   --stub "$BUILD/stub.f90"   --target tests/fmr/test_fpe_miqual06_serialized_manager.f90   --external-source "$BUILD/headcalc_miqual06.f90"   --build "$BUILD/runtime" --opt 2

"$BUILD/runtime/timeint03_test" | tee "$BUILD/runtime.txt"
grep -Fq 'F_PE_MIQUAL06_SERIALIZED_RUNTIME_SEAM=PASS' "$BUILD/runtime.txt"

git diff --check --   src/runtime/mod_fmr_moving_interface_runtime_adapter.f90   src/runtime/mod_fmr_serialized_reference_backend.f90   tests/fmr/test_fpe_miqual06_serialized_manager.f90

echo "F_PE_MIQUAL06=PASS"
