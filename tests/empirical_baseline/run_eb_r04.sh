#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap431-eb-r04-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

HISTORICAL_REF=origin/qualification/f-vq14-fmr04-physical-runtime
HISTORICAL_TEST_BLOB=11981391d0a504a66473c0281bf51defa6d1eac8
HISTORICAL_BACKEND_BLOB=ade399a1df4b582c9038442093ccacce034f923d
CURRENT_BACKEND_BLOB=3506b453ba6a00111d182f29db8cbfb288001854
BACKEND=src/runtime/mod_fmr_serialized_reference_backend.f90

git cat-file -e "$HISTORICAL_REF^{commit}"
test "$(git rev-parse "$HISTORICAL_REF:$BACKEND")" = "$HISTORICAL_BACKEND_BLOB"
test "$(git hash-object "$BACKEND")" = "$CURRENT_BACKEND_BLOB"
test "$HISTORICAL_BACKEND_BLOB" != "$CURRENT_BACKEND_BLOB"
echo 'EB_R04_HISTORICAL_FMR04_USED_AS_ORACLE_NOT_INHERITED=PASS'
echo 'EB_R04_CURRENT_SERIALIZED_BACKEND_PINNED=PASS'

git show "$HISTORICAL_REF:tests/fmr/test_fmr04_serialized_physical.F90" > "$BUILD/fmr04-historical.F90"
test "$(git hash-object "$BUILD/fmr04-historical.F90")" = "$HISTORICAL_TEST_BLOB"
echo 'EB_R04_HISTORICAL_FIXTURE_BLOB_IDENTITY=PASS'

python3 - "$BUILD/fmr04-historical.F90" "$BUILD/eb-r04-observer.F90" <<'PY'
from pathlib import Path
import sys

src = Path(sys.argv[1]).read_text(encoding='utf-8')
first_call = src.index('  call configure_fixture(')
contains = src.index('\ncontains\n')
prefix = src[:first_call]
helpers = src[contains + len('\ncontains\n'):]

# Keep the exact historical declarations and fixture/helper implementation, but
# replace the historical admission-policy checks with a bounded current-canonical
# hydraulic observation. Later capabilities changed admission semantics; they
# are not part of this empirical slice.
main = r'''  call configure_fixture(column, template, parameters, forcing, initial_state, initial_storage)
  call configure_transaction(config)
  call backend%initialize(top_provider)
  call fmr_new_b110_committed_state(committed, lineage_id, initial_state, t0, ok)
  call require(ok, 'committed state initialization')
  revision0 = committed%current_revision()
  call require(revision0 == 0_int64, 'initial revision')
  committed_fp0 = committed_fingerprint(committed)

  call fmr_capture_checkpoint(committed, checkpoint, ok)
  call require(ok .and. checkpoint%ready(), 'checkpoint capture')
  call backend%run_trial(column, template, parameters, committed, forcing, config, t0, t1, checkpoint, &
       result, candidate, diagnostics)
  call require(result%completed .and. candidate%ready(), 'physical candidate materialized')
  call require(result%mass%complete, 'authoritative full interval mass complete')
  call require(result%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'no missing mass contribution')
  call require(result%mass%origin_lineage_id == lineage_id .and. result%mass%origin_revision == revision0, &
       'mass committed provenance')
  call require(result%mass%accepted_transaction_count > 0, 'accepted transaction accounting')
  call require(diagnostics%mass_rejections == 0, 'per-trial mass gate accepted physical route')
  call require(diagnostics%max_abs_step_mass_residual <= 1.0e-12_real64, 'per-trial mass residual')
  call require(committed%current_revision() == revision0, 'trial did not mutate committed revision')
  call require(committed_fingerprint(committed) == committed_fp0, 'trial did not mutate committed physics')

  observation = backend%observation()
  call require(observation%solver_executed, 'real soil-water solver executed')
  call require(trim(observation%solver_diagnostics%route) == 'legacy-reference-bound', 'real HeadCalc route')
  call require(observation%solver_diagnostics%nonlinear_iterations >= 1, 'solver iterations recorded')

  candidate_fp1 = candidate_fingerprint(candidate)
  endpoint_storage = candidate_storage(candidate, parameters%dz)
  call shadow_profile_mass(forcing, observation, t1-t0, initial_storage, endpoint_storage, &
       shadow_total_in, shadow_total_out, shadow_residual)
  call require(abs(shadow_residual) <= 1.0e-12_real64, 'diagnostic profile accounting closes')
  call require(same_real(result%mass%storage_start,initial_storage), 'authoritative storage start identity')
  call require(same_real(result%mass%storage_end,endpoint_storage), 'authoritative storage end identity')
  call require(same_real(result%mass%storage_change,endpoint_storage-initial_storage), &
       'authoritative storage change identity')
  call require(same_real(result%mass%total_in,shadow_total_in), 'authoritative total inflow identity')
  call require(same_real(result%mass%total_out,shadow_total_out), 'authoritative total outflow identity')
  call require(abs(result%mass%residual) <= 1.0e-12_real64, 'authoritative full interval mass residual')

  call fmr_discard_candidate(transaction_control, candidate, diagnostics)
  call require(.not. candidate%ready(), 'candidate discarded')
  call require(committed_fingerprint(committed) == committed_fp0, 'rollback committed state unchanged')
  call require(committed%current_revision() == revision0, 'rollback revision unchanged')

  call backend%run_trial(column, template, parameters, committed, forcing, config, t0, t1, checkpoint, &
       replay_result, replay_candidate, replay_diagnostics)
  call require(replay_result%completed .and. replay_candidate%ready(), 'replay candidate materialized')
  call require(replay_result%mass%complete, 'replay preserves authoritative full mass')
  call require(replay_result%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'replay no missing contribution')
  candidate_fp2 = candidate_fingerprint(replay_candidate)
  call require(candidate_fp2 == candidate_fp1, 'checkpoint replay candidate identity')
  call require(same_real(replay_result%mass%storage_start,result%mass%storage_start), 'replay storage start identity')
  call require(same_real(replay_result%mass%storage_end,result%mass%storage_end), 'replay storage end identity')
  call require(same_real(replay_result%mass%total_in,result%mass%total_in), 'replay inflow identity')
  call require(same_real(replay_result%mass%total_out,result%mass%total_out), 'replay outflow identity')
  call require(same_real(replay_result%mass%residual,result%mass%residual), 'replay residual identity')

  write(*,'(A)') 'case_id,t0,t1,storage_start,storage_end,storage_change,total_in,total_out,residual,top_flux,bottom_flux,iterations,accepted_transactions,candidate_fingerprint'
  write(*,'(A,",",2(F0.12,","),8(ES25.17E3,","),I0,",",I0,",",I0)') &
       'b110_uniform_head_balanced_forcing', t0, t1, result%mass%storage_start, result%mass%storage_end, &
       result%mass%storage_change, result%mass%total_in, result%mass%total_out, result%mass%residual, &
       observation%top_flux, observation%bottom_flux, observation%solver_diagnostics%nonlinear_iterations, &
       result%mass%accepted_transaction_count, candidate_fp2
  write(*,'(A)') 'EB_R04_REAL_HEADCALC_EXECUTED=PASS'
  write(*,'(A)') 'EB_R04_AUTHORITATIVE_MASS_CLOSURE=PASS'
  write(*,'(A)') 'EB_R04_ROLLBACK_REPLAY_IDENTITY=PASS'
  write(*,'(A)') 'EB_R04_CURRENT_CANONICAL_B110_WATER_BALANCE_OBSERVATION PASS'

'''

Path(sys.argv[2]).write_text(prefix + main + 'contains\n\n' + helpers, encoding='utf-8')
PY

echo 'EB_R04_CURRENT_OBSERVER_DERIVED_FROM_HISTORICAL_FIXTURE=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
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
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -Wno-error=compare-reals -Wno-error=unused-dummy-argument \
      -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -Wno-error=unused-dummy-argument \
    -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/eb-r04-observer.F90" -o "$OUT/observer.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/observer.o" -o "$OUT/observer"
  "$OUT/observer" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  grep -Fq 'EB_R04_REAL_HEADCALC_EXECUTED=PASS' "$OUT/output.txt"
  grep -Fq 'EB_R04_AUTHORITATIVE_MASS_CLOSURE=PASS' "$OUT/output.txt"
  grep -Fq 'EB_R04_ROLLBACK_REPLAY_IDENTITY=PASS' "$OUT/output.txt"
  grep -Fq 'EB_R04_CURRENT_CANONICAL_B110_WATER_BALANCE_OBSERVATION PASS' "$OUT/output.txt"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'EB_R04_O0_O2_OBSERVATION_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "EB_R04_OBSERVATION_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
