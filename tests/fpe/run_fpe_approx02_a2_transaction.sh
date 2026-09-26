#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-approx02-a2-transaction-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "APPROX02_A2_TRANSACTION_FAIL $*" >&2; exit 1; }

python3 - "$BUILD/test.f90" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fpe/test_fpe_approx02_r1_transaction.f90").read_text()
src=src.replace("program test_fpe_approx02_r1_transaction","program test_fpe_approx02_a2_transaction",1)
src=src.replace("end program test_fpe_approx02_r1_transaction","end program test_fpe_approx02_a2_transaction",1)
src=src.replace("real(real64), parameter :: r1_tol=1.0e-2_real64",
                "real(real64), parameter :: r1_tol=1.0e-4_real64",1)
src=src.replace("'R1'","'A2'")
src=src.replace("APPROX02_R1_","APPROX02_A2_")
src=src.replace("FPE_APPROX02_R1_TRANSACTION","FPE_APPROX02_A2_TRANSACTION")
Path(sys.argv[1]).write_text(src)
PY

COMMON=(-std=f2008 -ffree-line-length-none -O2)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_owned_commit_receipt.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
  src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
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
  src/solver/mod_b110_smooth_freatic_projection.f90
  src/runtime/mod_fmr_drainage_qbot_directional_binding.f90
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
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
  src/process/mod_snow_process.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_soil_water_application_host.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
  src/solver/mod_rossfast_d3r_table_kernel.f90
  src/solver/mod_rossfast_d3r_table_provider.f90
  src/solver/mod_rossfast_d3r_soil_water_solver.f90
  src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$BUILD/test.f90" -o "$BUILD/test.o" || fail "compile fixture"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test" || fail "link"

OUT="$BUILD/results.txt"
: > "$OUT"
for material in B01 B12 O05 O14; do
  for spec in "wet -10" "mid -75" "dry -500"; do
    read -r regime h0 <<< "$spec"
    raw="$("$BUILD/test" "$material" "$regime" "$h0" 2>&1)" || { printf '%s
' "$raw" >&2; fail "$material $regime"; }
    printf '%s
' "$raw" | grep '^APPROX02_A2_' | tee -a "$OUT"
  done
done

python3 - "$OUT" <<'PY'
import statistics,sys
rows=[]; errs=[]
for line in open(sys.argv[1]):
    d={}
    for p in line.strip().split('|')[1:]:
        if '=' in p:
            k,v=p.split('=',1); d[k]=v
    if line.startswith('APPROX02_A2_TRANSACTION|'): rows.append(d)
    elif line.startswith('APPROX02_A2_TRANSACTION_ERROR|'): errs.append(d)
if len(rows)!=12 or len(errs)!=12:
    raise SystemExit(f'expected 12 transaction/error rows, got {len(rows)}/{len(errs)}')
for r in rows:
    if r['EXACT_COMPLETED'].lower() not in ('t','true','.true.') or r['R1_COMPLETED'].lower() not in ('t','true','.true.'):
        raise SystemExit(f"incomplete trajectory {r}")
    if float(r['EXACT_MAX_MASS_RESIDUAL'])>1e-12 or float(r['R1_MAX_MASS_RESIDUAL'])>1e-12:
        raise SystemExit(f"mass gate exceeded {r}")
for e in errs:
    print(
      f"APPROX02_A2_TRANSACTION_CASE|MATERIAL={e['MATERIAL']}|REGIME={e['REGIME']}"
      f"|MAX_HEAD_REL={float(e['MAX_HEAD_REL']):.17e}"
      f"|MAX_THETA_REL={float(e['MAX_THETA_REL']):.17e}"
      f"|CUM_BOTTOM_REL={float(e['CUM_BOTTOM_REL']):.17e}"
      f"|FINAL_STORAGE_REL={float(e['FINAL_STORAGE_REL']):.17e}"
    )
print(
  f"APPROX02_A2_TRANSACTION_SUMMARY"
  f"|MEDIAN_SPEEDUP_PERCENT={statistics.median(float(r['SPEEDUP_PERCENT']) for r in rows):.6f}"
  f"|MIN_SPEEDUP_PERCENT={min(float(r['SPEEDUP_PERCENT']) for r in rows):.6f}"
  f"|MAX_MASS_RESIDUAL={max(max(float(r['EXACT_MAX_MASS_RESIDUAL']),float(r['R1_MAX_MASS_RESIDUAL'])) for r in rows):.17e}"
  f"|MAX_RETRIES={max(max(int(r['EXACT_RETRIES']),int(r['R1_RETRIES'])) for r in rows)}"
  f"|MAX_MASS_REJECTIONS={max(max(int(r['EXACT_MASS_REJECTIONS']),int(r['R1_MASS_REJECTIONS'])) for r in rows)}"
  f"|MAX_HEAD_REL={max(float(e['MAX_HEAD_REL']) for e in errs):.17e}"
  f"|MAX_THETA_REL={max(float(e['MAX_THETA_REL']) for e in errs):.17e}"
  f"|MAX_CUM_BOTTOM_REL={max(float(e['CUM_BOTTOM_REL']) for e in errs):.17e}"
  f"|MAX_FINAL_STORAGE_REL={max(float(e['FINAL_STORAGE_REL']) for e in errs):.17e}"
)
print('FPE_APPROX02_A2_TRANSACTION_MATRIX=PASS')
PY
