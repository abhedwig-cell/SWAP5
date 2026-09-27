#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-dir01-repair01-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/base" "$BUILD/candidate" "$BUILD/src"
trap 'rm -rf "$BUILD"' EXIT

BASE=0fc57e27bb1d1abd8cdd4f516e6066d55e8a44d8
git fetch --no-tags --depth=1 origin "$BASE"
git show "$BASE:src/transaction/mod_accepted_trajectory_directional_sensitivity.f90" > "$BUILD/src/mod_accepted_trajectory_directional_sensitivity.f90"

python3 - "$BUILD/test.f90" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fpe/test_fpe_profile03_h03_application_host_timing.f90").read_text()
src=src.replace("SW_STEP_CONTROL_BOTTOM_FLUX", "SW_STEP_CONTROL_BOTTOM_HEAD")
src=src.replace("forcing%bottom_head = -999999.0_real64", "forcing%bottom_head = h0")
Path(sys.argv[1]).write_text(src)
PY

COMMON=(-std=f2008 -ffree-line-length-none -O2)
SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/transaction/mod_transaction_reference.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  DIRECTION_STATE_PLACEHOLDER
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
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
  src/process/mod_snow_process.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_soil_water_application_host.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
  src/solver/mod_rossfast_d3r_table_kernel.f90
  src/solver/mod_rossfast_d3r_table_provider.f90
  src/solver/mod_rossfast_d3r_soil_water_solver.f90
  src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
)

compile_variant() {
  local name="$1"
  local out="$BUILD/$name"
  local objects=()
  for source in "${SRC[@]}"; do
    if [[ "$source" == DIRECTION_STATE_PLACEHOLDER ]]; then
      if [[ "$name" == base ]]; then
        source="$BUILD/src/mod_accepted_trajectory_directional_sensitivity.f90"
      else
        source="src/transaction/mod_accepted_trajectory_directional_sensitivity.f90"
      fi
    fi
    local obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -J "$out" -I "$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -J "$out" -I "$out" -c "$BUILD/test.f90" -o "$out/test.o"
  gfortran -O2 "${objects[@]}" "$out/test.o" -o "$out/test"
}

compile_variant base
compile_variant candidate

CALLS=10000
PAIRS=10
OUT="$BUILD/results.csv"
echo 'pair,variant,ns,checksum,derivative,accepted_steps,accepted_backsolves' > "$OUT"

run_one() {
  local pair="$1" variant="$2" raw timing derivative steps backsolves
  raw="$("$BUILD/$variant/test" "$CALLS" directional zero-waste-paired)"
  timing="$(printf '%s\n' "$raw" | grep '^PROFILE03_E1_TIMING')"
  derivative="$(printf '%s\n' "$raw" | grep '^FKT22_FMR_BOTTOM_EXCHANGE_DERIVATIVE=' | cut -d= -f2-)"
  steps="$(printf '%s\n' "$raw" | grep '^FKT22_FMR_ACCEPTED_STEPS=' | cut -d= -f2-)"
  backsolves="$(printf '%s\n' "$raw" | grep '^FKT22_FMR_ACCEPTED_BACKSOLVES=' | cut -d= -f2-)"
  python3 - "$pair" "$variant" "$timing" "$derivative" "$steps" "$backsolves" "$OUT" <<'PY'
import csv,re,sys
pair,variant,line,derivative,steps,backsolves,path=sys.argv[1:]
def v(k):
    m=re.search(rf'{k}=\s*([^,]+)',line)
    if not m: raise SystemExit(f'missing {k}: {line}')
    return m.group(1).strip()
with open(path,'a',newline='') as f:
    csv.writer(f).writerow([pair,variant,v('ns_per_interval'),v('checksum'),derivative.strip(),steps.strip(),backsolves.strip()])
print(line)
PY
}

for pair in $(seq 1 "$PAIRS"); do
  if (( pair % 2 == 1 )); then
    run_one "$pair" base
    run_one "$pair" candidate
  else
    run_one "$pair" candidate
    run_one "$pair" base
  fi
done

python3 - "$OUT" <<'PY'
import csv,statistics,sys
rows=list(csv.DictReader(open(sys.argv[1])))
by={}
for r in rows: by.setdefault(int(r['pair']),{})[r['variant']]=r
ratios=[]; deltas=[]
for pair,v in sorted(by.items()):
    if set(v)!={'base','candidate'}: raise SystemExit(f'incomplete pair {pair}')
    b=v['base']; c=v['candidate']
    for k in ('checksum','derivative','accepted_steps','accepted_backsolves'):
        if b[k]!=c[k]: raise SystemExit(f'preservation drift pair={pair} field={k}: {b[k]} != {c[k]}')
    bn=float(b['ns']); cn=float(c['ns'])
    ratios.append(cn/bn); deltas.append(cn-bn)
print(f'DIR01_REPAIR01_MEAN_RATIO={statistics.mean(ratios):.9f}')
print(f'DIR01_REPAIR01_MEDIAN_RATIO={statistics.median(ratios):.9f}')
print(f'DIR01_REPAIR01_MEAN_SPEEDUP_PERCENT={(1-statistics.mean(ratios))*100:.6f}')
print(f'DIR01_REPAIR01_MEDIAN_SPEEDUP_PERCENT={(1-statistics.median(ratios))*100:.6f}')
print(f'DIR01_REPAIR01_MEAN_DELTA_NS={statistics.mean(deltas):.6f}')
print(f'DIR01_REPAIR01_PAIRS={len(ratios)}')
print('FPE_DIR01_REPAIR01_PAIRED_RUNTIME=PASS')
PY
