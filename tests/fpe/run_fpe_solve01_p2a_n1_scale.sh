#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-solve01-p2a-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "SOLVE01_P2A_FAIL $*" >&2; exit 1; }

# Replay the already-qualified BALTOL02 Reference balance floor only inside
# this research harness. SOLVE01 does not modify production source.
cp src/runtime/mod_fmr_serialized_reference_backend.f90 "$BUILD/mod_fmr_serialized_reference_backend.f90"
python3 - "$BUILD/mod_fmr_serialized_reference_backend.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()
old="""    request%numerical%compartment_balance_tolerance = self%compartment_balance_tolerance
    request%numerical%total_balance_tolerance = self%total_balance_tolerance
"""
new="""    request%numerical%compartment_balance_tolerance = max(self%compartment_balance_tolerance, 2.8e-16_real64 / step_duration)
    request%numerical%total_balance_tolerance = max(self%total_balance_tolerance, 2.8e-16_real64 / step_duration)
"""
if old not in src:
    raise SystemExit("BALTOL02 request seam missing")
p.write_text(src.replace(old,new,1))
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
  "$BUILD/mod_fmr_serialized_reference_backend.f90"
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_swap_transaction_participant.f90
  src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90
  src/runtime/mod_fmr_groundwater_swap_participant.f90
  src/runtime/mod_fmr_groundwater_participant_registry.f90
  src/runtime/mod_groundwater_interface_mass_ledger.f90
  src/runtime/mod_groundwater_tile_aggregation.f90
  src/runtime/mod_groundwater_multiswap_types.f90
  src/runtime/mod_modflow6_swap_predictor_response.f90
  src/runtime/mod_modflow6_multiswap_cell_response.f90
  src/runtime/mod_modflow6_linear_response_backend.f90
  src/runtime/mod_modflow6_api_binding.f90
  src/runtime/mod_groundwater_topology_composition.f90
  src/runtime/mod_groundwater_application_plan.f90
  src/runtime/mod_fmr_groundwater_application_context.f90
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done

gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c tests/fpe/test_fpe_solve01_p2a_nscale.f90 -o "$BUILD/test.o" || fail "compile fixture"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test" || fail "link"

OUT="$BUILD/results.txt"
: > "$OUT"
for n in 1 100 1000; do
  case "$n" in
    1) blocks=400 ;;
    100) blocks=20 ;;
    1000) blocks=4 ;;
  esac
  for rep in 1 2 3; do
    if (( rep % 2 == 1 )); then modes=(e0 e4); else modes=(e4 e0); fi
    for mode in "${modes[@]}"; do
      raw="$("$BUILD/test" "$n" "$mode" "$blocks" 2>&1)" || {
        printf '%s\n' "$raw" >&2
        fail "N=$n mode=$mode rep=$rep"
      }
      line="$(printf '%s\n' "$raw" | grep '^SOLVE01_P2A|' | tail -1)"
      [[ -n "$line" ]] || fail "missing P2A record"
      printf '%s|REP=%s\n' "$line" "$rep" | tee -a "$OUT"
    done
  done
done

python3 - "$OUT" <<'PY'
import statistics,sys
rows=[]
for line in open(sys.argv[1]):
    if not line.startswith("SOLVE01_P2A|"): continue
    d={}
    for p in line.strip().split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    rows.append(d)
if len(rows)!=18: raise SystemExit(f"expected 18 rows, got {len(rows)}")

for n in (1,100,1000):
    rr=[r for r in rows if int(r["N"])==n]
    by={m:[r for r in rr if r["MODE"]==m] for m in ("e0","e4")}
    if any(len(v)!=3 for v in by.values()): raise SystemExit(f"missing reps N={n}")
    e0=by["e0"][0]; e4=by["e4"][0]
    for key in ("QFINAL","PRESSURE_SUM","THETA_SUM"):
        if float(e0[key]) != float(e4[key]):
            raise SystemExit(f"{key} final authority mismatch N={n}")
    e0t=statistics.median(float(r["ELAPSED_S"]) for r in by["e0"])
    e4t=statistics.median(float(r["ELAPSED_S"]) for r in by["e4"])
    ratio=e4t/e0t
    solve_reduction=1-int(e4["EXACT_TILE_TRIALS"])/int(e0["EXACT_TILE_TRIALS"])
    print(
      f"SOLVE01_P2A_SCALE|N={n}|E0_SECONDS={e0t:.9f}|E4_SECONDS={e4t:.9f}"
      f"|RUNTIME_RATIO={ratio:.9f}|SPEEDUP_PERCENT={(1-ratio)*100:.6f}"
      f"|E0_TILE_TRIALS={e0['EXACT_TILE_TRIALS']}|E4_TILE_TRIALS={e4['EXACT_TILE_TRIALS']}"
      f"|SOLVE_REDUCTION_PERCENT={solve_reduction*100:.6f}"
      f"|FINAL_Q_IDENTITY=TRUE|FINAL_STATE_IDENTITY=TRUE"
    )
    if n==1000:
        if solve_reduction < 0.50:
            raise SystemExit("N=1000 solve-reduction gate failed")
        if 1-ratio < 0.30:
            raise SystemExit("N=1000 runtime-gain gate failed")
print("FPE_SOLVE01_P2A=PASS")
PY
