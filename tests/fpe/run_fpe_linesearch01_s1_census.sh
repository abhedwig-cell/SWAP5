#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-linesearch01-s1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/base" "$BUILD/candidate" "$BUILD/src"
trap 'rm -rf "$BUILD"' EXIT

python3 - "$BUILD/src/headcalc_candidate.f90" <<'PY'
from pathlib import Path
import sys
src=Path("src/legacy/b1_10_port/headcalc.f90").read_text()
src=src.replace(
"   logical :: flboth, flok\n",
"   logical :: flboth, flok, candidate_stagnated\n",1)
src=src.replace(
"   do solver_numbit = 1, MaxIt1\n",
"   newton_loop: do solver_numbit = 1, MaxIt1\n      candidate_stagnated = .false.\n",1)
lines=src.splitlines()
out=[]
inserted=False
for line in lines:
    out.append(line)
    if "Fmax = maxval(dabs(fsi_ws%residual(1:NN)))" in line and not inserted:
        out.append("          if (all(state%h(1:NN) == fsi_ws%old_head(1:NN)) .and. sump >= sumold .and. Fmax >= CritDevBalCp) then")
        out.append("             candidate_stagnated = .true.")
        out.append("             exit")
        out.append("          end if")
        inserted=True
if not inserted:
    raise SystemExit("S1 residual insertion point missing")
src="\n".join(out)+"\n"
src=src.replace(
" 1    continue\n\n!     check on convergence of solution",
" 1    continue\n      if (candidate_stagnated) exit newton_loop\n\n!     check on convergence of solution",1)
src=src.replace(
"   end do\n   ! Preserve the legacy DO-variable value after normal loop exhaustion.\n   state%numbit = solver_numbit",
"   end do newton_loop\n   ! Preserve the legacy exhausted-loop diagnostic even for the explicit stagnation shortcut.\n   if (candidate_stagnated) then\n      state%numbit = MaxIt1 + 1\n   else\n      state%numbit = solver_numbit\n   end if",1)
Path(sys.argv[1]).write_text(src)
PY

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

compile_variant() {
  local name="$1"
  local headcalc="$2"
  local out="$BUILD/$name"
  local objects=()
  for source in "${MODULE_SRC[@]}"; do
    if [[ "$source" == "HEAD_CALC_PLACEHOLDER" ]]; then source="$headcalc"; fi
    obj="$out/$(basename "${source%.*}").o"
    extra=()
    [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
    gfortran -std=f2008 -ffree-line-length-none -O2 -J "$out" -I "$out" "${extra[@]}" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran -std=f2008 -ffree-line-length-none -O2 -J "$out" -I "$out" -c tests/publication/test_pub_p2e04_reference_failure_census.f90 -o "$out/test.o"
  gfortran -O2 "${objects[@]}" "$out/test.o" -o "$out/test"
}

compile_variant base src/legacy/b1_10_port/headcalc.f90
compile_variant candidate "$BUILD/src/headcalc_candidate.f90"

"$BUILD/base/test" > "$BUILD/base.txt"
"$BUILD/candidate/test" > "$BUILD/candidate.txt"

grep -Fq 'PUB_P2E04_CASE_COUNT=162' "$BUILD/base.txt"
grep -Fq 'PUB_P2E04_CASE_COUNT=162' "$BUILD/candidate.txt"
grep -Fq 'PUB_P2E04_FAILURE_CENSUS=PASS' "$BUILD/base.txt"
grep -Fq 'PUB_P2E04_FAILURE_CENSUS=PASS' "$BUILD/candidate.txt"

grep '^PUB_P2E04_CASE=' "$BUILD/base.txt" > "$BUILD/base_cases.txt"
grep '^PUB_P2E04_CASE=' "$BUILD/candidate.txt" > "$BUILD/candidate_cases.txt"
cmp -s "$BUILD/base_cases.txt" "$BUILD/candidate_cases.txt" || {
  diff -u "$BUILD/base_cases.txt" "$BUILD/candidate_cases.txt" >&2 || true
  echo 'LINESEARCH01_S1_CASE_CLASSIFICATION=FAIL' >&2
  exit 1
}
echo 'LINESEARCH01_S1_CASE_CLASSIFICATION=PASS'

for key in PUB_P2E04_CLASS_COUNT PUB_P2E04_FAIL_STAGE_COARSE PUB_P2E04_FAIL_STAGE_HALF1 PUB_P2E04_FAIL_STAGE_HALF2 PUB_P2E04_INVALID_TOTAL; do
  grep "^$key" "$BUILD/base.txt" > "$BUILD/base_${key}.txt" || true
  grep "^$key" "$BUILD/candidate.txt" > "$BUILD/candidate_${key}.txt" || true
  cmp -s "$BUILD/base_${key}.txt" "$BUILD/candidate_${key}.txt" || { echo "LINESEARCH01_S1_${key}=FAIL" >&2; exit 1; }
done
echo 'LINESEARCH01_S1_CENSUS=PASS'
