#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-approx01-tangent-sweep-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "APPROX01_TANGENT_SWEEP_FAIL $*" >&2; exit 1; }

python3 - "$BUILD/test.f90" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fpe/test_fpe_profile03_h03_application_host_timing.f90").read_text()
src=src.replace("program test_fkt22_fmr_serialized_trajectory_runtime","program test_fpe_approx01_tangent_sweep",1)
src=src.replace("end program test_fkt22_fmr_serialized_trajectory_runtime","end program test_fpe_approx01_tangent_sweep",1)
src=src.replace("SW_STEP_CONTROL_BOTTOM_FLUX","SW_STEP_CONTROL_BOTTOM_HEAD")
src=src.replace("  real(real64), parameter :: h0 = -75.0_real64","  real(real64) :: h0, bottom_head_value",1)
needle="""  if (command_argument_count() >= 3) then
    call get_command_argument(3, arg)
    skip_workspace_reset_observation = trim(arg) == 'zero-waste-paired'
  end if
"""
replacement=needle+"""  h0 = -75.0_real64
  bottom_head_value = h0
  if (command_argument_count() >= 4) then
    call get_command_argument(4, arg)
    read(arg,*) h0
    bottom_head_value = h0
  end if
  if (command_argument_count() >= 5) then
    call get_command_argument(5, arg)
    read(arg,*) bottom_head_value
  end if
"""
if needle not in src: raise SystemExit("argument seam missing")
src=src.replace(needle,replacement,1)
src=src.replace("    forcing%bottom_head = -999999.0_real64","    forcing%bottom_head = bottom_head_value",1)
outneedle="""  write(*,'(A,ES26.17E3)') 'FKT22_FMR_BOTTOM_EXCHANGE_DERIVATIVE=', &
       result_on%accepted_trajectory_direction%accepted_bottom_exchange_derivative
"""
outrep=outneedle+"""  write(*,'(A,ES26.17E3)') 'APPROX01_BOTTOM_HEAD_CM=', bottom_head_value
  write(*,'(A,ES26.17E3)') 'APPROX01_BOTTOM_EXCHANGE_CM=', result_on%bottom_outward_exchange_native
"""
if outneedle not in src: raise SystemExit("output seam missing")
src=src.replace(outneedle,outrep,1)
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
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
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
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_b110_root_sink_provider.f90
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

RESULT="$BUILD/results.csv"
echo 'regime,point,offset_cm,bottom_head_cm,tangent,bottom_exchange_cm' > "$RESULT"

run_point(){
  local regime="$1" h0="$2" point="$3" offset="$4" hbot raw der exch
  hbot="$(python3 - <<PY
print(float("$h0")+float("$offset"))
PY
)"
  raw="$("$BUILD/test" 1 directional zero-waste-paired "$h0" "$hbot")"
  der="$(printf '%s\n' "$raw" | grep '^FKT22_FMR_BOTTOM_EXCHANGE_DERIVATIVE=' | cut -d= -f2-)"
  exch="$(printf '%s\n' "$raw" | grep '^APPROX01_BOTTOM_EXCHANGE_CM=' | cut -d= -f2-)"
  printf '%s,%s,%s,%s,%s,%s\n' "$regime" "$point" "$offset" "$hbot" "$der" "$exch" >> "$RESULT"
  printf 'APPROX01_POINT|REGIME=%s|POINT=%s|OFFSET_CM=%s|BOTTOM_HEAD_CM=%s|TANGENT=%s|BOTTOM_EXCHANGE_CM=%s\n'     "$regime" "$point" "$offset" "$hbot" "$der" "$exch"
}

offsets=(0 0.1 0.25 0.5 0.25 0.1 0 -0.1 -0.25 -0.5 -0.25 -0.1)
for spec in "wet -10" "mid -75" "dry -500"; do
  read -r regime h0 <<< "$spec"
  point=0
  for offset in "${offsets[@]}"; do
    point=$((point+1))
    run_point "$regime" "$h0" "$point" "$offset"
  done
done

python3 - "$RESULT" <<'PY'
import csv,statistics,sys
rows=list(csv.DictReader(open(sys.argv[1])))
if len(rows)!=36: raise SystemExit(f"expected 36 points, got {len(rows)}")
for regime in ("wet","mid","dry"):
    rr=[r for r in rows if r["regime"]==regime]
    tang=[float(r["tangent"]) for r in rr]
    print(f"APPROX01_EVOLUTION|REGIME={regime}|MIN={min(tang):.17e}|MAX={max(tang):.17e}|SPAN={max(tang)-min(tang):.17e}")
    for cadence in (2,4,8):
        ae=[]; re=[]; qe=[]
        for i,t in enumerate(tang):
            refresh=(i//cadence)*cadence
            lag=tang[refresh]
            err=abs(lag-t)
            ae.append(err)
            re.append(err/max(abs(t),1e-30))
            qe.append(err*0.01)
        print(
            f"APPROX01_LAG|REGIME={regime}|CADENCE={cadence}"
            f"|FRESH_FRACTION={1/cadence:.6f}"
            f"|AVOIDED_TANGENT_FRACTION={1-1/cadence:.6f}"
            f"|MAX_ABS_TANGENT_ERROR={max(ae):.17e}"
            f"|MEAN_ABS_TANGENT_ERROR={statistics.mean(ae):.17e}"
            f"|MAX_REL_TANGENT_ERROR={max(re):.17e}"
            f"|MEAN_REL_TANGENT_ERROR={statistics.mean(re):.17e}"
            f"|MAX_Q_PRED_ERROR_AT_DH_0P01M={max(qe):.17e}"
        )
print("FPE_APPROX01_TANGENT_SWEEP=PASS")
PY
