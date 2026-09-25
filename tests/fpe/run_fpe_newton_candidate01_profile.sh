#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-newton-candidate01-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
COMMON=(-std=f2008 -ffree-line-length-none -O2 -pg)
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
  src/runtime/mod_fmr_drainage_response_binding.f90
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
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  extra=()
  [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
  gfortran "${COMMON[@]}" "${extra[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c tests/fpe/test_fpe_newton_candidate01_profile.f90 -o "$BUILD/test.o"
gfortran -O2 -pg "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test"

(
  cd "$BUILD"
  rm -f gmon.out
  ./test easy 50000 | tee easy.txt
  mv gmon.out easy.gmon
  gprof -b ./test easy.gmon > easy.gprof.txt
  rm -f gmon.out
  ./test hard 5000 | tee hard.txt
  mv gmon.out hard.gmon
  gprof -b ./test hard.gmon > hard.gprof.txt
)

grep -Fq 'NEWTON_CANDIDATE01_PROFILE|MODE=easy' "$BUILD/easy.txt"
grep -Fq '|ITER=3|' "$BUILD/easy.txt"
grep -Fq '|BACKTRACK=3|' "$BUILD/easy.txt"
grep -Fq 'NEWTON_CANDIDATE01_PROFILE|MODE=hard' "$BUILD/hard.txt"
grep -Fq '|ITER=16|' "$BUILD/hard.txt"

python3 - "$BUILD/easy.gprof.txt" "$BUILD/hard.gprof.txt" <<'PY'
import re,sys
for label,path in [('easy',sys.argv[1]),('hard',sys.argv[2])]:
    text=open(path).read()
    names=['headcalc','vector_f','evaluate_demand','reference_tridag','jacobian_f']
    print(f'NEWTON_CANDIDATE01_GPROF_BEGIN|MODE={label}')
    for line in text.splitlines():
        low=line.lower()
        if any(n in low for n in names):
            print(line)
    print(f'NEWTON_CANDIDATE01_GPROF_END|MODE={label}')
print('NEWTON_CANDIDATE01_PROFILE=PASS')
PY
