#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-approx02-a2-multistep-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "APPROX02_A2_MULTISTEP_FAIL $*" >&2; exit 1; }

COMMON=(-std=f2008 -ffree-line-length-none -O2)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
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
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c tests/fpe/test_fpe_approx02_a2_multistep.f90 -o "$BUILD/test.o" || fail "compile fixture"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test" || fail "link"

OUT="$BUILD/results.txt"
: > "$OUT"
for material in B01 B12 O05 O14; do
  for spec in "wet -10" "mid -75" "dry -500"; do
    read -r regime h0 <<< "$spec"
    raw="$("$BUILD/test" "$material" "$h0" 2>&1)" || { printf '%s\n' "$raw" >&2; fail "$material $regime"; }
    line="$(printf '%s\n' "$raw" | grep '^APPROX02_A2_MULTISTEP|')"
    printf '%s|REGIME=%s\n' "$line" "$regime" | tee -a "$OUT"
  done
done

python3 - "$OUT" <<'PY'
import statistics,sys
rows=[]
for line in open(sys.argv[1]):
    if not line.startswith('APPROX02_A2_MULTISTEP|'): continue
    d={}
    for p in line.strip().split('|')[1:]:
        k,v=p.split('=',1); d[k]=v
    rows.append(d)
if len(rows)!=12: raise SystemExit(f'expected 12 multi-step rows, got {len(rows)}')
for r in rows:
    print(
      f"APPROX02_A2_MULTI_CASE|MATERIAL={r['MATERIAL']}|REGIME={r['REGIME']}"
      f"|SPEEDUP_PERCENT={float(r['SPEEDUP_PERCENT']):.6f}"
      f"|EXACT_NONLINEAR={r['EXACT_NONLINEAR']}|A2_NONLINEAR={r['A2_NONLINEAR']}"
      f"|MAX_HEAD_REL={float(r['MAX_HEAD_REL']):.17e}|FINAL_HEAD_REL={float(r['FINAL_HEAD_REL']):.17e}"
      f"|MAX_THETA_REL={float(r['MAX_THETA_REL']):.17e}|FINAL_THETA_REL={float(r['FINAL_THETA_REL']):.17e}"
      f"|MAX_FLUX_REL={float(r['MAX_FLUX_REL']):.17e}|CUM_BOTTOM_REL={float(r['CUM_BOTTOM_REL']):.17e}"
    )
print(
  f"APPROX02_A2_MULTI_SUMMARY|MEDIAN_SPEEDUP_PERCENT={statistics.median(float(r['SPEEDUP_PERCENT']) for r in rows):.6f}"
  f"|MIN_SPEEDUP_PERCENT={min(float(r['SPEEDUP_PERCENT']) for r in rows):.6f}"
  f"|MAX_HEAD_REL={max(float(r['MAX_HEAD_REL']) for r in rows):.17e}"
  f"|MAX_FINAL_HEAD_REL={max(float(r['FINAL_HEAD_REL']) for r in rows):.17e}"
  f"|MAX_THETA_REL={max(float(r['MAX_THETA_REL']) for r in rows):.17e}"
  f"|MAX_FLUX_REL={max(float(r['MAX_FLUX_REL']) for r in rows):.17e}"
  f"|MAX_CUM_BOTTOM_REL={max(float(r['CUM_BOTTOM_REL']) for r in rows):.17e}"
)
print('FPE_APPROX02_A2_MULTISTEP_MATRIX=PASS')
PY
