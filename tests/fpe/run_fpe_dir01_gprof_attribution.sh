#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-dir01-gprof-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

command -v gprof >/dev/null

python3 - "$BUILD/test.f90" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fpe/test_fpe_profile03_h03_application_host_timing.f90").read_text()
src=src.replace("SW_STEP_CONTROL_BOTTOM_FLUX", "SW_STEP_CONTROL_BOTTOM_HEAD")
src=src.replace("forcing%bottom_head = -999999.0_real64", "forcing%bottom_head = h0")
Path(sys.argv[1]).write_text(src)
PY

COMMON=(-std=f2008 -ffree-line-length-none -O2 -pg -fno-omit-frame-pointer)
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

objects=()
for source in "${SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$BUILD/test.f90" -o "$BUILD/test.o"
gfortran -O2 -pg "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test"

CALLS=750000

run_profile() {
  local mode="$1"
  rm -f "$BUILD/gmon.out"
  (
    cd "$BUILD"
    ./test "$CALLS" "$mode" zero-waste-paired > "$mode.out"
  )
  mv "$BUILD/gmon.out" "$BUILD/$mode.gmon"
  gprof -b "$BUILD/test" "$BUILD/$mode.gmon" > "$BUILD/$mode.gprof"
  grep '^PROFILE03_E1_TIMING' "$BUILD/$mode.out"
}

run_profile reference
run_profile directional

python3 - "$BUILD/reference.gprof" "$BUILD/directional.gprof" <<'PY'
import re,sys

def flat(path):
    lines=open(path,errors='replace').read().splitlines()
    start=None
    for i,line in enumerate(lines):
        if line.strip()=="Flat profile:":
            start=i
            break
    if start is None:
        raise SystemExit(f'no flat profile in {path}')
    rows=[]
    active=False
    for line in lines[start+1:]:
        if line.startswith("Call graph"):
            break
        if "name" in line and "self" in line and "seconds" in line:
            active=True
            continue
        if not active or not line.strip() or line.lstrip().startswith("Each sample"):
            continue
        m=re.match(r'^\s*([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)(?:\s+([0-9]+))?(?:\s+[0-9.]+)?(?:\s+[0-9.]+)?\s+(.+?)\s*$',line)
        if not m:
            continue
        pct=float(m.group(1)); self_s=float(m.group(3)); calls=int(m.group(4)) if m.group(4) else 0
        name=m.group(5)
        rows.append((pct,self_s,calls,name))
    return rows

r=flat(sys.argv[1]); d=flat(sys.argv[2])
print("DIR01_GPROF_REFERENCE_TOP")
for row in r[:30]:
    print("DIR01_GPROF_REF|PCT=%.3f|SELF_S=%.6f|CALLS=%d|NAME=%s"%row)
print("DIR01_GPROF_DIRECTIONAL_TOP")
for row in d[:40]:
    print("DIR01_GPROF_DIR|PCT=%.3f|SELF_S=%.6f|CALLS=%d|NAME=%s"%row)

rd={x[3]:x for x in r}; dd={x[3]:x for x in d}
names=set(rd)|set(dd)
delta=[]
for name in names:
    rs=rd.get(name,(0,0,0,name))[1]
    ds=dd.get(name,(0,0,0,name))[1]
    delta.append((ds-rs,ds,rs,name,dd.get(name,(0,0,0,name))[2]))
delta.sort(reverse=True)
print("DIR01_GPROF_SELF_TIME_DELTA_TOP")
for ds,dir_s,ref_s,name,calls in delta[:40]:
    print(f"DIR01_GPROF_DELTA|DELTA_S={ds:.6f}|DIR_S={dir_s:.6f}|REF_S={ref_s:.6f}|CALLS={calls}|NAME={name}")
print("FPE_DIR01_GPROF_ATTRIBUTION=PASS")
PY
