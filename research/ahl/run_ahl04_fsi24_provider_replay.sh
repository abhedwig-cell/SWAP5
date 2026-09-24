#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="\${RUNNER_TEMP:-\${TMPDIR:-/tmp}}/swap5-ahl04-\${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -O2)

SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  research/ahl/mod_ahl04_hybrid_lookup_provider.f90
  research/ahl/test_ahl04_fsi24_provider_replay.f90
)

objs=()
for source in "\${SRC[@]}"; do
  obj="$BUILD/$(basename "\${source%.*}").o"
  gfortran "\${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
  objs+=("$obj")
done

gfortran -O2 "\${objs[@]}" -o "$BUILD/test"

TABLE_ROOT="\${1:?table root required}"
OUT="\${2:-/tmp/ahl04_stage_a.txt}"
: > "$OUT"
for label in fixed50 fixed100 adaptive; do
  "$BUILD/test" "$TABLE_ROOT/\${label}.dat" "$label" | tee -a "$OUT"
done

grep -Fq 'AHL04_ADAPTIVE_STAGE_A=PASS' "$OUT"
echo 'AHL04_STAGE_A_REPLAY=PASS'
