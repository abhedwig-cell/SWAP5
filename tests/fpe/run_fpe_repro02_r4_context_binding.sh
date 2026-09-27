#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-repro02-r4-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "REPRO02_R4_FAIL $*" >&2; exit 1; }

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
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
python3 - "$BUILD/test.f90" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fpe/test_fpe_approx01_tangent_matrix.f90").read_text()
src=src.replace(
"  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX\n",
"  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX\n"
"  use mod_b110_serialized_context_binding, only: bind_b110_serialized_legacy_context\n",1)
src=src.replace(
"  character(len=64) :: arg,material\n  integer :: i\n",
"  character(len=64) :: arg,material,bind_mode\n  integer :: i\n  logical :: context_ok\n",1)
src=src.replace(
"  if(command_argument_count()/=3) error stop 'usage: test MATERIAL H0_CM HBOT_CM'\n",
"  if(command_argument_count()/=4) error stop 'usage: test MATERIAL H0_CM HBOT_CM BIND_MODE'\n",1)
src=src.replace(
"  call get_command_argument(3,arg); read(arg,*) hbot\n",
"  call get_command_argument(3,arg); read(arg,*) hbot\n  call get_command_argument(4,bind_mode)\n",1)
needle="""  dreq%incoming_ponding_depth=0.0_real64; dreq%direct_control_derivative=1.0_real64

  call solve_with_accepted_step_direction(solver,request,workspace,dreq,solve_result,dres)
"""
rep="""  dreq%incoming_ponding_depth=0.0_real64; dreq%direct_control_derivative=1.0_real64

  context_ok=.true.
  if(trim(bind_mode)=='BOUND') call bind_b110_serialized_legacy_context(request,context_ok)
  if(.not.context_ok) error stop 'serialized legacy context bind failed'
  call solve_with_accepted_step_direction(solver,request,workspace,dreq,solve_result,dres)
"""
if needle not in src: raise SystemExit("solve seam missing")
src=src.replace(needle,rep,1)
src=src.replace(
"       '|NONLINEAR=',solve_result%diagnostics%nonlinear_iterations,'|BACKTRACK=',solve_result%diagnostics%backtracking_attempts\n",
"       '|NONLINEAR=',solve_result%diagnostics%nonlinear_iterations,'|BACKTRACK=',solve_result%diagnostics%backtracking_attempts, &\n"
"       '|BIND_MODE=',trim(bind_mode)\n",1)
start=src.index("  if(solve_result%status/=SW_SOLVE_CONVERGED)")
end=src.index("  print '(A)','FPE_APPROX01_TANGENT_MATRIX_POINT=PASS'",start)
src=src[:start]+"  ! R4 records both converged and retry-advised outcomes without converting them to process failure.\n"+src[end:]
Path(sys.argv[1]).write_text(src)
PY
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$BUILD/test.f90" -o "$BUILD/test.o" || fail "compile fixture"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test" || fail "link"

OUT="$BUILD/r4.txt"; : > "$OUT"
cases=("B01|wet|-10" "B01|mid|-75" "B12|wet|-10" "O05|wet|-10" "O14|wet|-10" "O14|mid|-75")
offsets=(-0.001 0 0.001)
modes=(DIRECT BOUND)
reps=3
for case_spec in "${cases[@]}"; do
  IFS='|' read -r material regime h0 <<< "$case_spec"
  for offset in "${offsets[@]}"; do
    hbot="$(python3 - <<PY
print(float("$h0")+float("$offset"))
PY
)"
    for mode in "${modes[@]}"; do
      for rep in $(seq 1 "$reps"); do
        raw="$("$BUILD/test" "$material" "$h0" "$hbot" "$mode" 2>&1)" || { printf '%s\n' "$raw" >&2; fail "$material $regime $offset $mode"; }
        line="$(printf '%s\n' "$raw" | grep '^APPROX01_MATRIX_POINT|' | tail -1)"
        [[ -n "$line" ]] || fail "missing R4 record"
        printf '%s|REGIME=%s|OFFSET_CM=%s|REP=%s\n' "${line/APPROX01_MATRIX_POINT/REPRO02_R4_RAW}" "$regime" "$offset" "$rep" | tee -a "$OUT"
      done
    done
  done
done

python3 - "$OUT" <<'PY'
import collections,sys
rows=[]
for line in open(sys.argv[1]):
    if not line.startswith("REPRO02_R4_RAW|"): continue
    d={}
    for p in line.strip().split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    rows.append(d)
if len(rows)!=108: raise SystemExit(f"expected 108 rows, got {len(rows)}")
groups=collections.defaultdict(list)
for d in rows:
    groups[(d["MATERIAL"],d["REGIME"],d["OFFSET_CM"],d["BIND_MODE"])].append(d)
for key,rs in sorted(groups.items()):
    sig=collections.Counter((r["SOLVE_STATUS"],r["DIRECTION_STATUS"],r["NONLINEAR"],r["BACKTRACK"]) for r in rs)
    if len(sig)!=1: raise SystemExit(f"nondeterministic R4 signature {key}: {sig}")
    r=rs[0]
    print(
      f"REPRO02_R4_POINT|MATERIAL={key[0]}|REGIME={key[1]}|OFFSET_CM={float(key[2]):.6f}|MODE={key[3]}"
      f"|SOLVE_STATUS={r['SOLVE_STATUS']}|DIRECTION_STATUS={r['DIRECTION_STATUS']}|NONLINEAR={r['NONLINEAR']}|BACKTRACK={r['BACKTRACK']}"
    )
direct_pass=sum(1 for k,rs in groups.items() if k[3]=="DIRECT" and rs[0]["SOLVE_STATUS"]=="1")
bound_pass=sum(1 for k,rs in groups.items() if k[3]=="BOUND" and rs[0]["SOLVE_STATUS"]=="1")
print(f"REPRO02_R4_SUMMARY|DIRECT_PASS={direct_pass}|BOUND_PASS={bound_pass}|POINTS_PER_ARM=18")
print("FPE_REPRO02_R4=PASS")
PY
