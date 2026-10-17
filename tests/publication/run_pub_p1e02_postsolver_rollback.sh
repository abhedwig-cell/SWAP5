#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-p1e02-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
fail() { echo "PUB_P1E02_GATE_FAIL $*" >&2; exit 1; }

TEST=tests/publication/test_pub_p1e02_postsolver_rollback.f90

git diff --check -- "$TEST" tests/publication/run_pub_p1e02_postsolver_rollback.sh || fail 'diff check'
[[ -z "$(git diff --name-only -- src reference)" ]] || fail 'production/reference source dirty before publication experiment'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -fopenmp -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/transaction/mod_transaction_reference.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_drainage_process.f90
  src/process/mod_drainage_tabulated_response.f90
  src/process/mod_drainage_hooghoudt_equivalent_depth.f90
  src/process/mod_drainage_hooghoudt_ipos1_response.f90
  src/process/mod_drainage_hooghoudt_ipos23_response.f90
  src/process/mod_drainage_ernst_ipos45_preparation.f90
  src/process/mod_drainage_ernst_ipos45_response.f90
  src/process/mod_drainage_empirical_interflow_response.f90
  src/process/mod_drainage_multilevel_aggregation.f90
  src/process/mod_drainage_extended_exchange.f90
  # DRAMET3 production dependency must compile before the shared drain binding.
  src/process/mod_drainage_dramet3_response.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_direct_retention_core.f90
  src/solver/mod_b110_direct_retention_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/process/mod_pond_water_temporal_difference.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_soil_water_application_host.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
  src/solver/mod_rossfast_d3r_table_kernel.f90
  src/solver/mod_rossfast_d3r_table_provider.f90
  src/solver/mod_rossfast_d3r_soil_water_solver.f90
  src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_owned_commit_receipt.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
)

# Resolve the full real module closure once, without reimplementing physics.
# A missing/ambiguous provider or dependency cycle rejects before compilation.
python3 tests/publication/resolve_fortran_module_closure.py "${MODULE_SRC[@]}" > "$BUILD/module_sources.txt" || fail 'Fortran module closure'
mapfile -t MODULE_SRC < "$BUILD/module_sources.txt"
echo "PUB_P1E02_RESOLVED_MODULE_SOURCES=${#MODULE_SRC[@]}"

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    [[ -f "$source" ]] || fail "missing compile source $source"
    obj="$OUT/$(basename "${source%.*}").o"
    extra=()
    [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
    gfortran "${COMMON[@]}" "${extra[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"

  if ! "$OUT/test" > "$OUT/output.txt" 2>&1; then
    cat "$OUT/output.txt" >&2
    fail "production post-solver rollback O$opt"
  fi
  for marker in \
    'PUB_P1E02_POSTSOLVER_COMMITTED_STATE_IDENTITY=PASS' \
    'PUB_P1E02_REJECTED_TRANSFER_EXCLUSION=PASS' \
    'PUB_P1E02_PRODUCTION_POSTSOLVER_ROLLBACK=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done
  # Exercise the production B1.11 pond owner, not a reconstructed process.
  # Historical accepted mixing: initial 1 cm, 2 mg/cm2, evaporation
  # 0.5 cm, infiltration 0.25 cm => 1 mg/cm2 infiltrates.
  cat > "$OUT/test_pond_evap.f90" <<'F90'
program test_pond_evap
use iso_fortran_env, only: real64,int64
use mod_b111_persistent_pond
implicit none
type(persistent_pond_state_t) :: original,candidate,restored,rejected
type(pond_step_t) :: s,bad
type(persistent_pond_receipt_t) :: r
real(real64) :: clock,depth,mass
integer(int64) :: revision
integer :: status
call initialize_persistent_pond(0d0,1d0,2d0,original,status)
if(status/=POND_OK) error stop 'pond init'
s=pond_step_t(0d0,1d0,1d0,0.25d0,-0.25d0,0d0,0d0,0d0,0d0,0d0)
s%pond_evaporation_rate=0.5d0
call advance_persistent_pond(original,s,candidate,r)
if(r%status/=POND_OK) error stop 'evap acceptance'
if(abs(r%soil_transfer-1d0)>1d-13.or.abs(r%mass_after-1d0)>1d-13) &
 error stop 'historical production mixing'
if(abs(r%mass_residual)>1d-13.or.abs(r%water_residual)>1d-13) &
 error stop 'pond water or mass imbalance'
call candidate%snapshot(clock,depth,mass,revision)
call restore_persistent_pond(1,clock,depth,mass,revision,restored,status)
if(status/=POND_OK) error stop 'pond restore'
call restored%snapshot(clock,depth,mass,revision)
if(depth/=0.25d0.or.mass/=1d0.or.revision/=1_int64) error stop 'restart identity'
! Drying removes the residual 0.25 cm water but no remaining solute.
s=pond_step_t(1d0,2d0,0.25d0,0d0,0d0,0d0,0d0,0d0,0d0,0d0)
s%pond_evaporation_rate=0.25d0
call advance_persistent_pond(restored,s,candidate,r)
if(r%status/=POND_OK.or.r%mass_after/=1d0.or.r%soil_transfer/=0d0) &
 error stop 'dry residual solute retention'
! After dry restart, chemically specified rain re-wets the existing owner.
call candidate%snapshot(clock,depth,mass,revision)
call restore_persistent_pond(1,clock,depth,mass,revision,restored,status)
if(status/=POND_OK) error stop 'dry restart'
s=pond_step_t(2d0,3d0,0d0,0.25d0,-0.25d0,0.5d0,0.2d0,0d0,0d0,0d0)
call advance_persistent_pond(restored,s,candidate,r)
if(r%status/=POND_OK) error stop 'rewet acceptance'
if(abs(r%soil_transfer-0.55d0)>1d-13.or.abs(r%mass_after-0.55d0)>1d-13) &
 error stop 'rewet historical mixing'
if(abs(r%mass_residual)>1d-13.or.abs(r%water_residual)>1d-13) &
 error stop 'multi-step accepted balances'
bad=pond_step_t(0d0,1d0,1d0,0.25d0,-0.25d0,0d0,0d0,0d0,0d0,0d0)
bad%pond_evaporation_rate=0.25d0
call advance_persistent_pond(original,bad,rejected,r)
if(r%status/=POND_WATER) error stop 'unbalanced evaporation accepted'
call rejected%snapshot(clock,depth,mass,revision)
if(depth/=1d0.or.mass/=2d0.or.revision/=0_int64) error stop 'rejected mutation'
print '(A)', 'MC_SOL01_POND_EVAP_SOURCE_MIX_BALANCE_RESTART_REJECT=PASS'
end program
F90
  POND_OBJECTS=()
  for pond_source in src/process/mod_b111_pond_solute_exchange.f90 src/process/mod_b111_persistent_pond.f90; do
    pond_obj="$OUT/$(basename "${pond_source%.f90}")-evap.o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$pond_source" -o "$pond_obj"
    POND_OBJECTS+=("$pond_obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" "$OUT/test_pond_evap.f90" "${POND_OBJECTS[@]}" -o "$OUT/test_pond_evap"
  "$OUT/test_pond_evap" | tee "$OUT/pond_evap.txt"
  grep -Fq 'MC_SOL01_POND_EVAP_SOURCE_MIX_BALANCE_RESTART_REJECT=PASS' "$OUT/pond_evap.txt" || fail "pond evaporation O$opt"
  cat "$OUT/output.txt"
  echo "PUB_P1E02_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 rollback semantic drift'
}

echo "PUB_P1E02_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'PUB_P1E02_POSTSOLVER_ROLLBACK_GATE=PASS'
