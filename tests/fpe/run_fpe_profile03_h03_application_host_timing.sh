#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-profile03-h03-e1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/baseline" "$BUILD/candidate" "$BUILD/src"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASELINE_COMMIT=0b373c6cdaed53e26a1acb917f096bf20256f12a
git show "${BASELINE_COMMIT}:src/legacy/b1_10_port/headcalc.f90" > "$BUILD/src/headcalc_baseline.f90"

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
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  HEAD_CALC_PLACEHOLDER
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
)

compile_variant() {
  local name="$1"
  local headcalc="$2"
  local out="$BUILD/$name"
  local objects=()
  mkdir -p "$out"

  for source in "${MODULE_SRC[@]}"; do
    if [[ "$source" == "HEAD_CALC_PLACEHOLDER" ]]; then
      source="$headcalc"
    fi
    local stem
    stem="$(basename "${source%.*}")"
    local obj="$out/${stem}.o"
    gfortran -std=f2008 -ffree-line-length-none -O2 -J"$out" -I"$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done

  gfortran -std=f2008 -ffree-line-length-none -O2 -J"$out" -I"$out" \
    -c tests/fpe/test_fpe_profile03_h03_application_host_timing.f90 -o "$out/test.o"
  gfortran -O2 "${objects[@]}" "$out/test.o" -o "$out/test"
}

compile_variant baseline "$BUILD/src/headcalc_baseline.f90"
compile_variant candidate "src/legacy/b1_10_port/headcalc.f90"

CALLS=4000
PAIRS=8
: > "$BUILD/results.csv"
echo 'pair,order,variant,seconds,ns_per_interval,nonlinear_iterations_per_solve,constitutive_evaluations_per_solve,checksum' >> "$BUILD/results.csv"

run_one() {
  local pair="$1" order="$2" variant="$3"
  local line
  line="$("$BUILD/$variant/test" "$CALLS" | grep '^PROFILE03_E1_TIMING')"
  python3 - "$pair" "$order" "$variant" "$line" "$BUILD/results.csv" <<'PY'
import sys,re,csv
pair,order,variant,line,path=sys.argv[1:]
def val(key):
    m=re.search(rf'{key}=\s*([^,]+)',line)
    if not m: raise SystemExit(f'missing {key}: {line}')
    return m.group(1).strip()
with open(path,'a',newline='') as f:
    csv.writer(f).writerow([pair,order,variant,val('seconds'),val('ns_per_interval'),
                            val('nonlinear_iterations_per_solve'),val('constitutive_evaluations_per_solve'),val('checksum')])
print(line)
PY
}

for pair in $(seq 1 "$PAIRS"); do
  if (( pair % 2 == 1 )); then
    run_one "$pair" BC baseline
    run_one "$pair" BC candidate
  else
    run_one "$pair" CB candidate
    run_one "$pair" CB baseline
  fi
done

python3 - "$BUILD/results.csv" <<'PY'
import sys,csv,statistics,math
p=sys.argv[1]
rows=list(csv.DictReader(open(p)))
by_pair={}
for r in rows:
    by_pair.setdefault(int(r['pair']),{})[r['variant']]=r
ratios=[]
deltas=[]
for pair,v in sorted(by_pair.items()):
    b=float(v['baseline']['ns_per_interval']); c=float(v['candidate']['ns_per_interval'])
    ratios.append(c/b)
    deltas.append(c-b)
    if v['baseline']['nonlinear_iterations_per_solve'] != v['candidate']['nonlinear_iterations_per_solve']:
        raise SystemExit('nonlinear iteration drift')
    if v['baseline']['checksum'] != v['candidate']['checksum']:
        raise SystemExit('checksum drift')
    if int(v['candidate']['constitutive_evaluations_per_solve']) >= int(v['baseline']['constitutive_evaluations_per_solve']):
        raise SystemExit('constitutive count did not decrease')
mean_ratio=statistics.mean(ratios)
med_ratio=statistics.median(ratios)
mean_delta=statistics.mean(deltas)
print(f'PROFILE03_E1_PAIRED_MEAN_RATIO={mean_ratio:.9f}')
print(f'PROFILE03_E1_PAIRED_MEDIAN_RATIO={med_ratio:.9f}')
print(f'PROFILE03_E1_PAIRED_MEAN_SPEEDUP_PERCENT={(1-mean_ratio)*100:.6f}')
print(f'PROFILE03_E1_PAIRED_MEAN_DELTA_NS_PER_INTERVAL={mean_delta:.6f}')
print(f'PROFILE03_E1_PAIRED_N={len(ratios)}')
print('PROFILE03_E1_PAIRED_RUNTIME=PASS')
PY
