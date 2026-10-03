#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-bofek01-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
python3 tests/rom/materialize_f_rom0_headcalc_stubs.py \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10
python3 tests/rom/compile_f_rom0_fortran_closure.py \
  --root "$ROOT" --stub "$BUILD/stub.f90" \
  --target tests/performance/characterize_bartholomeus_e2e05_bofek.f90 \
  --external-source src/legacy/b1_10_port/headcalc.f90 \
  --external-source src/physics/oxygen/mod_bartholomeus_parameter_contract.f90 \
  --external-source src/physics/oxygen/mod_bartholomeus_temperature.f90 \
  --external-source src/physics/oxygen/mod_bartholomeus_soil_diffusivity.f90 \
  --external-source src/physics/oxygen/mod_bartholomeus_microbial.f90 \
  --external-source src/physics/oxygen/mod_bartholomeus_micro.f90 \
  --external-source src/physics/oxygen/mod_bartholomeus_waterfilm.f90 \
  --external-source src/process/mod_bartholomeus_runtime_input.f90 \
  --external-source src/physics/oxygen/mod_bartholomeus_no_stress_gate.f90 \
  --build "$BUILD/compile" --opt 2
python3 tests/fpe/run_fpe_bofek01_screen.py \
  "$BUILD/compile/rom0_test" docs/performance/F-PE-BOFEK01_TESTBANK.json

# trigger E2E05 screening characterization
