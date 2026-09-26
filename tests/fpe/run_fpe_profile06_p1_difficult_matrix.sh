#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-profile06-p1-difficult-${GITHUB_RUN_ID:-local}-$"
CANDIDATE_TOL="${APPROX02_CANDIDATE_TOL:-1e-4}"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "PROFILE06_P1_FAIL $*" >&2; exit 1; }

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
reps=5
for material in B01 B12 O05 O14; do
  for spec in "wet -10" "mid -75" "dry -500"; do
    read -r regime h0 <<< "$spec"
    for rep in $(seq 1 "$reps"); do
      raw="$("$BUILD/test" "$material" "$h0" "$CANDIDATE_TOL" 2>&1)" || { printf '%s\n' "$raw" >&2; fail "$material $regime rep $rep"; }
      line="$(printf '%s\n' "$raw" | grep '^PROFILE06_P1|')"
      printf '%s|REGIME=%s|REP=%s\n' "$line" "$regime" "$rep" | tee -a "$OUT"
    done
  done
done

python3 - "$OUT" <<'PY'
import statistics,sys
rows=[]
for line in open(sys.argv[1]):
    if not line.startswith('PROFILE06_P1|'): continue
    d={}
    for p in line.strip().split('|')[1:]:
        k,v=p.split('=',1); d[k]=v
    rows.append(d)
if len(rows)!=60: raise SystemExit(f'expected 60 rows, got {len(rows)}')

groups={}
for r in rows:
    key=(r['MATERIAL'],r['REGIME'])
    groups.setdefault(key,[]).append(r)

summaries=[]
for key,rs in sorted(groups.items()):
    if len(rs)!=5: raise SystemExit(f'{key}: expected 5 reps')
    exact=[float(r['EXACT_SECONDS']) for r in rs]
    a2=[float(r['A2_SECONDS']) for r in rs]
    ratios=[a/e for a,e in zip(a2,exact)]
    speed=[100*(1-x) for x in ratios]
    r=rs[0]
    vals=dict(
      material=key[0], regime=key[1],
      exact_median=statistics.median(exact),
      a2_median=statistics.median(a2),
      ratio_median=statistics.median(ratios),
      speed_median=statistics.median(speed),
      speed_mean=statistics.mean(speed),
      speed_positive=sum(x>0 for x in speed),
      exact_nl=int(r['EXACT_NONLINEAR']), a2_nl=int(r['A2_NONLINEAR']),
      exact_bt=int(r['EXACT_BACKTRACK']), a2_bt=int(r['A2_BACKTRACK']),
      max_head_rel=max(float(x['MAX_HEAD_REL']) for x in rs),
      max_theta_rel=max(float(x['MAX_THETA_REL']) for x in rs),
      max_flux_rel=max(float(x['MAX_FLUX_REL']) for x in rs),
      cum_rel=max(float(x['CUM_BOTTOM_REL']) for x in rs),
    )
    summaries.append(vals)
    print(
      f"PROFILE06_P1_CASE|MATERIAL={vals['material']}|REGIME={vals['regime']}"
      f"|EXACT_MEDIAN_SECONDS={vals['exact_median']:.17e}|A2C_MEDIAN_SECONDS={vals['a2_median']:.17e}"
      f"|MEDIAN_SPEEDUP_PERCENT={vals['speed_median']:.6f}|MEAN_SPEEDUP_PERCENT={vals['speed_mean']:.6f}"
      f"|SPEED_POSITIVE_REPS={vals['speed_positive']}/5"
      f"|EXACT_NONLINEAR={vals['exact_nl']}|A2C_NONLINEAR={vals['a2_nl']}"
      f"|NONLINEAR_REDUCTION_PERCENT={(1-vals['a2_nl']/vals['exact_nl'])*100:.6f}"
      f"|EXACT_BACKTRACK={vals['exact_bt']}|A2C_BACKTRACK={vals['a2_bt']}"
      f"|MAX_HEAD_REL={vals['max_head_rel']:.17e}|MAX_THETA_REL={vals['max_theta_rel']:.17e}"
      f"|MAX_FLUX_REL={vals['max_flux_rel']:.17e}|MAX_CUM_BOTTOM_REL={vals['cum_rel']:.17e}"
    )

# Freeze P2 difficult set from exact nonlinear work.
# Easy floor is the minimum exact nonlinear count present on this postimage.
floor=min(x['exact_nl'] for x in summaries)
# Materially difficult = at least 2x floor and at least 20% A2C nonlinear reduction.
selected=[x for x in summaries if x['exact_nl']>=2*floor and x['a2_nl']<=0.8*x['exact_nl']]
selected=sorted(selected,key=lambda x:(-x['exact_nl'],x['material'],x['regime']))
print(f"PROFILE06_P1_SUMMARY|CASES={len(summaries)}|EASY_FLOOR_NONLINEAR={floor}|SELECTED={len(selected)}")
for x in selected:
    print(
      f"PROFILE06_P2_SELECTED|MATERIAL={x['material']}|REGIME={x['regime']}"
      f"|EXACT_NONLINEAR={x['exact_nl']}|A2C_NONLINEAR={x['a2_nl']}"
      f"|MEDIAN_SPEEDUP_PERCENT={x['speed_median']:.6f}"
    )
print('FPE_PROFILE06_P1=PASS')
PY
