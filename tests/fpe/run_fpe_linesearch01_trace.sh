#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-linesearch01-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

python3 - <<'PY' "$BUILD/headcalc_trace.f90"
from pathlib import Path
import sys
src=Path("src/legacy/b1_10_port/headcalc.f90").read_text().splitlines()
out=[]
inserted=False
for line in src:
    out.append(line)
    if "Fmax = maxval(dabs(fsi_ws%residual(1:NN)))" in line and not inserted:
        out.append("          write(*,'(*(g0))') 'LINESEARCH01_CANDIDATE|ITER=',state%numbit,'|TRY=',itry,'|FACTOR=',factor, &")
        out.append("               '|SUMOLD=',sumold,'|SUMP=',sump,'|FMAX=',Fmax,'|ACCEPT=',(sump < sumold .OR. Fmax < CritDevBalCp)")
        inserted=True
if not inserted:
    raise SystemExit("trace insertion point not found")
Path(sys.argv[1]).write_text("\n".join(out)+"\n")
PY

COMMON=(-std=f2008 -ffree-line-length-none -O2)
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
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  HEAD_CALC_PLACEHOLDER
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
)

objects=()
for source in "${MODULE_SRC[@]}"; do
  if [[ "$source" == "HEAD_CALC_PLACEHOLDER" ]]; then source="$BUILD/headcalc_trace.f90"; fi
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
  objects+=("$obj")
done

gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c tests/fpe/test_fpe_linesearch01_trace.f90 -o "$BUILD/test.o"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test"

"$BUILD/test" easy 1 | tee "$BUILD/easy.txt"
"$BUILD/test" hard 1 | tee "$BUILD/hard.txt"

python3 - "$BUILD/easy.txt" "$BUILD/hard.txt" <<'PY'
import re,sys,collections
for label,path in [('easy',sys.argv[1]),('hard',sys.argv[2])]:
    rows=[]
    for line in open(path):
        if not line.startswith('LINESEARCH01_CANDIDATE|'):
            continue
        d={}
        for part in line.strip().split('|')[1:]:
            k,v=part.split('=',1); d[k]=v
        rows.append(d)
    if not rows:
        raise SystemExit(f'no trace rows for {label}')
    by=collections.defaultdict(list)
    for d in rows: by[int(d['ITER'])].append(d)
    exhausted=0; first_accept=[]
    print(f'LINESEARCH01_ANALYSIS_BEGIN|MODE={label}|CANDIDATES={len(rows)}|ITERATIONS={len(by)}')
    for it,rr in sorted(by.items()):
        acc=[x for x in rr if x['ACCEPT'].strip().upper().startswith('T')]
        if acc:
            fa=acc[0]
            first_accept.append(int(fa['TRY']))
            print(f"LINESEARCH01_ITER|MODE={label}|ITER={it}|TRIES={len(rr)}|FIRST_ACCEPT={fa['TRY']}|FACTOR={fa['FACTOR']}|SUMP={fa['SUMP']}")
        else:
            exhausted+=1
            print(f'LINESEARCH01_ITER|MODE={label}|ITER={it}|TRIES={len(rr)}|FIRST_ACCEPT=NONE')
    print(f'LINESEARCH01_SUMMARY_ANALYSIS|MODE={label}|EXHAUSTED={exhausted}|MEAN_FIRST_ACCEPT={sum(first_accept)/len(first_accept) if first_accept else -1}')
    print(f'LINESEARCH01_ANALYSIS_END|MODE={label}')
print('LINESEARCH01_TRACE=PASS')
PY
