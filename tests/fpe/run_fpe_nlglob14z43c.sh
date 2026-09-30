#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-nlglob14z43c-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

# Replay explicit opt-in/default configuration smoke.
gfortran -std=f2008 -O3   src/runtime/mod_timestep_numerical_profile.f90   tests/fpe/test_fpe_nlglob14z43_profile.f90   -o "$BUILD/z43c_profile"
"$BUILD/z43c_profile"

python3 tests/fpe/materialize_fpe_nlglob14z43c_maxit16.py   --source tests/fpe/test_fpe_nlglob14z43a_reference_solvability.f90   --output "$BUILD/preflight_maxit16.f90"
python3 tests/fpe/materialize_fpe_nlglob14z43c_maxit16.py   --source tests/fpe/test_fpe_nlglob14z43_admission_holdout.f90   --output "$BUILD/holdout_maxit16.f90"

compile_n() {
  local n="$1"
  local dir="$BUILD/n$n"
  mkdir -p "$dir"
  python3 tests/rom/materialize_f_rom0_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --output "$dir/stub.f90" --nodes "$n" --dz-cm 10
  python3 tests/fpe/materialize_fpe_timeint03_binding.py     --source src/adapter/mod_reference_richards_legacy_binding.f90     --output "$dir/mod_fpe_timeint03_reference_binding.f90"
  python3 tests/fpe/materialize_fpe_timeint02_headcalc.py     --source src/legacy/b1_10_port/headcalc.f90     --output "$dir/headcalc_z43c.f90"

  python3 tests/fpe/compile_fpe_timeint03_closure.py     --root "$ROOT" --stub "$dir/stub.f90"     --target "$BUILD/preflight_maxit16.f90"     --external-source "$dir/headcalc_z43c.f90"     --external-module-source "$dir/mod_fpe_timeint03_reference_binding.f90"     --build "$dir/preflight" --opt 3

  python3 tests/fpe/compile_fpe_timeint03_closure.py     --root "$ROOT" --stub "$dir/stub.f90"     --target "$BUILD/holdout_maxit16.f90"     --external-source "$dir/headcalc_z43c.f90"     --external-module-source "$dir/mod_fpe_timeint03_reference_binding.f90"     --build "$dir/holdout" --opt 3
}

compile_n 32
compile_n 64

python3 tests/fpe/run_fpe_nlglob14z43c.py   "$BUILD/n32/preflight/timeint03_test"   "$BUILD/n64/preflight/timeint03_test"   "$BUILD/n32/holdout/timeint03_test"   "$BUILD/n64/holdout/timeint03_test"   docs/performance/F-PE-BOFEK01_TESTBANK.json
