#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rm18-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "RM18_FAIL $*" >&2; exit 1; }

# Preservation authority first.
bash tests/fsi/run_fsi38_prescribed_qbot_temporal_certificate_gate.sh | tee "$BUILD/fsi38.txt"
grep -Fq 'FSI38_QUALIFICATION_GATE=PASS' "$BUILD/fsi38.txt" || fail "FSI38 preservation"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace)
SRC=(
 tests/fsi/fsi04_real_headcalc_stubs.f90
 src/solver/mod_soil_water_accepted_step_direction_contract.f90
 src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
 src/transaction/mod_accepted_trajectory_directional_publication.f90
 src/runtime/mod_a23bu_worker_execution_context.f90
 src/solver/mod_soil_water_solver_contract.f90
 src/solver/mod_reference_richards_workspace.f90
 src/solver/mod_reference_richards_state_binding.f90
 src/solver/mod_reference_linear_solver.f90
 src/solver/mod_b110_default_mvg_provider.f90
 src/solver/mod_b110_source_sink_provider.f90
 src/solver/mod_fixed_flux_top_boundary_provider.f90
 src/process/mod_restricted_surface_evaporation.f90
 src/solver/mod_b110_dynamic_top_boundary_provider.f90
 src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
 src/solver/mod_b110_root_sink_provider.f90
 src/solver/mod_reference_richards_temporal_indicator.f90
 src/legacy/b1_10_port/headcalc.f90
 src/adapter/mod_reference_richards_legacy_binding.f90
)
objects=()
for source in "${SRC[@]}"; do
 obj="$BUILD/$(basename "${source%.*}").o"
 gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj" || fail "compile $source"
 objects+=("$obj")
done
gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c  tests/ribasim-management/test_rm18_dynamic_flux_temporal_certificate.f90 -o "$BUILD/test.o"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test"
"$BUILD/test" | tee "$BUILD/rm18.txt"
grep -Fq 'RM18_DYNAMIC_FLUX_TEMPORAL_CERTIFICATE=PASS' "$BUILD/rm18.txt" || fail "RM18 unit marker"
echo 'RM18_TEMPORAL_CERTIFICATE_GATE=PASS'
