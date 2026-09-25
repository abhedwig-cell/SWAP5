#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fahl49-matrix-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

python3 - "$BUILD/test.f90" <<'PY'
from pathlib import Path
import sys
src=Path("research/ahl/test_fahl47_matrix_timing.f90").read_text()
src=src.replace("program test_fahl47_matrix_timing","program test_fahl49_production_matrix")
src=src.replace("end program test_fahl47_matrix_timing","end program test_fahl49_production_matrix")
src=src.replace(
    "use mod_ahl47_direct_retention_provider, only: ahl47_provider_t, bind_ahl47_provider",
    "use mod_b110_direct_retention_core, only: acquire_b110_direct_retention_slot, freeze_b110_direct_retention_pool, reset_b110_direct_retention_pool\n"
    "  use mod_b110_direct_retention_provider, only: b110_direct_retention_provider_t, bind_b110_direct_retention_provider")
src=src.replace("type(ahl47_provider_t), target :: lookup","type(b110_direct_retention_provider_t), target :: lookup")
src=src.replace("logical :: valid","logical :: valid, was_hit")
src=src.replace("integer :: k","integer :: k, direct_slot")
src=src.replace(
    "call bind_ahl47_provider(lookup,hp,total_dt,valid)",
    "call reset_b110_direct_retention_pool()\n"
    "  call acquire_b110_direct_retention_slot(hp,direct_slot,valid,was_hit)\n"
    "  call require(valid .and. .not. was_hit,'direct-retention acquire')\n"
    "  call freeze_b110_direct_retention_pool()\n"
    "  call bind_b110_direct_retention_provider(lookup,hp,total_dt,direct_slot,valid)")
src=src.replace("FAHL47_","FAHL49_PROD_")
Path(sys.argv[1]).write_text(src)
PY

COMMON=(-std=f2008 -ffree-line-length-none -O3)
SRC=(
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
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_direct_retention_core.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_direct_retention_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
)
objects=()
for source in "${SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$BUILD/test.f90" -o "$BUILD/test.o"
gfortran -O3 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test"

RESULT="$BUILD/result.txt"
: > "$RESULT"
for material in B01 B12 O05 O14; do
  for spec in "wet -10 -7.5" "mid -75 -50" "dry -500 -400"; do
    read -r regime h0 hbot <<< "$spec"
    "$BUILD/test" "$material" "$regime" "$h0" "$hbot" | tee -a "$RESULT"
  done
done

python3 - "$RESULT" <<'PY'
import re,statistics,sys
rows={}
passes=0
for line in open(sys.argv[1]):
    if line.startswith("FAHL49_PROD_MATRIX ") and line.rstrip().endswith(" PASS"):
        passes += 1
    m=re.search(r'FAHL49_PROD_TIMING_MEDIAN\|CASE=([^|]+)\|RATIO=([0-9Ee+.-]+)',line)
    if m: rows[m.group(1)]=float(m.group(2))
if passes != 12: raise SystemExit(f'expected 12 matrix passes got {passes}')
if len(rows) != 12: raise SystemExit(f'expected 12 timing medians got {len(rows)}')
vals=sorted(rows.values())
print(f'FAHL49_PROD_MATRIX_MEDIAN={(vals[5]+vals[6])/2:.9f}')
print(f'FAHL49_PROD_MATRIX_MIN={min(vals):.9f}')
print(f'FAHL49_PROD_MATRIX_MAX={max(vals):.9f}')
print('FAHL49_PROD_MATRIX_POSITIVE='+str(sum(v<0.98 for v in vals)))
print('FAHL49_PROD_MATRIX_NEGATIVE='+str(sum(v>1.02 for v in vals)))
print('FAHL49_PRODUCTION_MATRIX=PASS')
PY
