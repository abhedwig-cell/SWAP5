#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-eb-i19-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "EB_I19_GATE_FAIL $*" >&2; exit 190; }

CANONICAL="5e5e498dc56d1df1dd7ebebbf9901c946445a1ab"
OWNER="15184dd06c1d0f8accc0d306a12d25a3568f1f2e"
OLD_BACKEND_BLOB="21e0e4229f202f1a3a74c4da004aa32a2c855f03"
OLD_RUNTIME_BLOB="f06a2eef7b47880e449cf9b201342d7bd1e197e1"
BACKEND="src/runtime/mod_fmr_serialized_reference_backend.f90"
RUNTIME="src/runtime/mod_fmr_serialized_multiswap_runtime.f90"
TEST="tests/eb/test_eb_i18_transaction_publication.f90"
ADAPTER="src/adapter/mod_b110_serialized_context_binding.f90"
TEMPORAL="src/solver/mod_reference_richards_temporal_indicator.f90"

git fetch -q origin integration/f-ci-canonical
LIVE_CANONICAL="$(git rev-parse origin/integration/f-ci-canonical)"
[[ "$LIVE_CANONICAL" == "$CANONICAL" ]] || fail "live canonical moved: $LIVE_CANONICAL != $CANONICAL"
git merge-base --is-ancestor "$CANONICAL" HEAD || fail 'branch is not descended from pinned canonical'
git merge-base --is-ancestor "$OWNER" HEAD || fail 'branch is not descended from exact EB-I18R2 owner candidate'
echo "EB_I19_LIVE_CANONICAL_LOCK=PASS sha=$CANONICAL"

# Frozen EB authorities remain byte-identical to F-VQ77-qualified owner input.
declare -A EB_BLOBS=(
  [src/process/mod_liquid_water_sensible_enthalpy.f90]=2247370ee34fac73a0e2d0b9fa15e171467aded3
  [src/runtime/mod_fmr_bottom_thermal_carrier.f90]=c371be3e22eaa6da70ca8cbb060bc42d1e0e0bfb
  [src/runtime/mod_fmr_bottom_external_thermal_binding.f90]=ed2a2ee36add299ebb5f8bde276da2f3b360cc28
  [src/runtime/mod_fmr_bottom_external_thermal_provider.f90]=885cc50ad1f5cfc17843e412c0f5dfdb989d553b
  [src/runtime/mod_fmr_bottom_sensible_energy.f90]=1f3d6f975278f960feac4388b0cdd36a0f5f162d
)
for path in "${!EB_BLOBS[@]}"; do
  [[ "$(git hash-object "$path")" == "${EB_BLOBS[$path]}" ]] || fail "frozen EB authority blob drift: $path"
done
echo 'EB_I19_FROZEN_EB_AUTHORITY_BLOBS=PASS'

# This gate qualifies real production source. The historical staging blobs must
# no longer be present and the exact materialization delta is bounded to the
# serialized backend plus MultiSWAP runtime.
BACKEND_BLOB="$(git hash-object "$BACKEND")"
RUNTIME_BLOB="$(git hash-object "$RUNTIME")"
[[ "$BACKEND_BLOB" != "$OLD_BACKEND_BLOB" ]] || fail 'backend still historical pre-materialization blob'
[[ "$RUNTIME_BLOB" != "$OLD_RUNTIME_BLOB" ]] || fail 'runtime still historical pre-materialization blob'
materialized_src="$(git diff --name-only "$OWNER" HEAD -- src | sort)"
expected_materialized_src=$'src/runtime/mod_fmr_serialized_multiswap_runtime.f90\nsrc/runtime/mod_fmr_serialized_reference_backend.f90'
[[ "$materialized_src" == "$expected_materialized_src" ]] || {
  printf '%s\n' "$materialized_src" >&2
  fail 'production materialization changed unexpected src files'
}
git diff --quiet "$OWNER" HEAD -- reference || fail 'production materialization changed reference source'
echo "EB_I19_BACKEND_BLOB=$BACKEND_BLOB"
echo "EB_I19_RUNTIME_BLOB=$RUNTIME_BLOB"
echo 'EB_I19_EXACT_TWO_FILE_PRODUCTION_MATERIALIZATION=PASS'

# Worker-local attempt scratch and opt-in runtime publication semantics.
grep -Fq 'type, extends(transaction_attempt_context_t) :: fmr_serialized_attempt_context_t' "$BACKEND" || fail 'attempt context type missing'
grep -Fq 'capture_attempt_context => fmr_serialized_capture_attempt_context' "$BACKEND" || fail 'attempt capture missing'
grep -Fq 'restore_attempt_context => fmr_serialized_restore_attempt_context' "$BACKEND" || fail 'attempt restore missing'
grep -Fq 'set_bottom_thermal_carrier_enabled' "$BACKEND" || fail 'thermal carrier opt-in control missing'
grep -Fq 'bottom_thermal_snapshot' "$BACKEND" || fail 'thermal candidate snapshot missing'
grep -Fq 'fmr_execute_serialized_column_with_bottom_energy' "$RUNTIME" || fail 'production energy publication entrypoint missing'
! grep -Fq 'fmr_execute_serialized_resolved_physical_column_with_bottom_energy' "$RUNTIME" || fail 'obsolete staged entrypoint remains'
grep -Fq 'thermal_candidate = backend%bottom_thermal_snapshot()' "$RUNTIME" || fail 'candidate thermal snapshot binding missing'
grep -Fq 'call prepare_candidate_bound_bottom_energy' "$RUNTIME" || fail 'candidate-bound preparation missing'
grep -Fq 'call fmr_commit_candidate_with_receipt' "$RUNTIME" || fail 'accepted receipt commit seam missing'
grep -Fq 'call finalize_bottom_energy_publication' "$RUNTIME" || fail 'accepted-only publication finalization missing'
! grep -Fq 'thermal_candidate = fmr_bottom_thermal_candidate_t()' "$RUNTIME" || fail 'private candidate constructor remains'
echo 'EB_I19_PRODUCTION_TRANSACTIONAL_PUBLICATION_STATIC=PASS'

# Current-canonical prescribed-qbot, temporal-certificate and drainage ownership
# must survive materialization unchanged.
grep -Fq 'request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2' "$ADAPTER" || fail 'mode2 adapter admission lost'
grep -Fq 'parameters%bottom_mode == 2' "$BACKEND" || fail 'backend mode2 execution admission lost'
grep -Fq 'self%bottom_mode /= 2' "$BACKEND" || fail 'backend mode2 temporal route lost'
grep -Fq '(request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2)' "$TEMPORAL" || fail 'F-SI38 mode2 certificate admission lost'
grep -Fq 'if (request%boundary%bottom_mode == 5) then' "$TEMPORAL" || fail 'Dirichlet-only stiffness guard lost'
grep -Fq 'use mod_fmr_drainage_response_binding' "$BACKEND" || fail 'drainage response binding lost'
grep -Fq 'drainage_response_active' "$BACKEND" || fail 'drainage response runtime seam lost'
echo 'EB_I19_CURRENT_CANONICAL_PRESERVATION_STATIC=PASS'

# The committed EB-I19 fixture is the qualified bounded mode-2 route. No
# runtime source or test patching occurs in this gate.
grep -Fq 'parameters%bottom_mode = 2' "$TEST" || fail 'mode2 fixture missing'
grep -Fq 'FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY' "$TEST" || fail 'temporal history fixture missing'
grep -Fq 'config%model_temporal_indicator_budget = 2.5e-11_real64' "$TEST" || fail 'explicit qualification budget missing'
grep -Fq 'q = 1.0e-10_real64' "$TEST" || fail 'bounded prescribed qbot fixture missing'
grep -Fq "abs(output%mass%residual) <= 1.0e-12_real64" "$TEST" || fail 'hard water mass assertion missing'
grep -Fq 'output%accepted_substeps == 1' "$TEST" || fail 'single accepted substep assertion missing'
grep -Fq 'output%solver_headcalc_calls == 1' "$TEST" || fail 'bounded HeadCalc assertion missing'
! grep -Fq 'parameters%bottom_mode = 7' "$TEST" || fail 'historical pseudo-inflow fixture remains'
echo 'EB_I19_COMMITTED_QUALIFICATION_FIXTURE_STATIC=PASS'

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
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/eb/test_eb_i18_external_bottom_thermal_provider.f90 -o "$OUT/provider_test.o"
  gfortran -O"$opt" "$OUT/mod_fmr_bottom_external_thermal_provider.o" "$OUT/provider_test.o" -o "$OUT/provider_test"
  "$OUT/provider_test" > "$OUT/provider_output.txt" 2>&1 || { cat "$OUT/provider_output.txt" >&2; fail "provider oracle O$opt"; }
  grep -Fq 'EB_I18_EXTERNAL_BOTTOM_THERMAL_PROVIDER_GATE PASS' "$OUT/provider_output.txt" || fail "provider marker O$opt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/transaction_test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/transaction_test.o" -o "$OUT/transaction_test"
  "$OUT/transaction_test" > "$OUT/transaction_output.txt" 2>&1 || { cat "$OUT/transaction_output.txt" >&2; fail "transaction oracle O$opt"; }
  for marker in \
    'EB_I18_EXTERNAL_COMPLETE_ACCEPTED_PUBLICATION=PASS' \
    'EB_I18_EXTERNAL_UNAVAILABLE_HYDROLOGY_COMMIT=PASS' \
    'EB_I18_EXTERNAL_STALE_HYDROLOGY_COMMIT=PASS' \
    'EB_I18_EXTERNAL_IDENTITY_MISMATCH_FAIL_CLOSED=PASS' \
    'EB_I18_EXTERNAL_INVALID_RESPONSE_FAIL_CLOSED=PASS' \
    'EB_I18_REJECTED_TRIAL_NO_PUBLICATION=PASS' \
    'EB_I18_BACKEND_REUSE_NO_STALE_PUBLICATION=PASS' \
    'EB_I18_TRANSACTION_PUBLICATION_GATE PASS'; do
    grep -Fq "$marker" "$OUT/transaction_output.txt" || { cat "$OUT/transaction_output.txt" >&2; fail "missing transaction marker O$opt: $marker"; }
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr44r_serialized_prescribed_qbot_runtime.f90 -o "$OUT/fmr44r_test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/fmr44r_test.o" -o "$OUT/fmr44r_test"
  "$OUT/fmr44r_test" > "$OUT/fmr44r_output.txt" 2>&1 || { cat "$OUT/fmr44r_output.txt" >&2; fail "FMR44R preservation oracle O$opt"; }
  grep -Fq 'FMR44R_POSITIVE_QBOT_ACCEPTED_INFLOW=PASS' "$OUT/fmr44r_output.txt" || fail "FMR44R positive qbot marker O$opt"
  grep -Fq 'FMR44R_SERIALIZED_PRESCRIBED_QBOT_RUNTIME_GATE=PASS' "$OUT/fmr44r_output.txt" || fail "FMR44R final marker O$opt"

  cat "$OUT/transaction_output.txt"
  cat "$OUT/fmr44r_output.txt"
  echo "EB_I19_PROVIDER_O${opt}=PASS"
  echo "EB_I19_TRANSACTION_O${opt}=PASS"
  echo "EB_I19_FMR44R_PRESERVATION_O${opt}=PASS"
done

cmp -s "$BUILD/o0/provider_output.txt" "$BUILD/o2/provider_output.txt" || fail 'provider O0/O2 semantic drift'
cmp -s "$BUILD/o0/transaction_output.txt" "$BUILD/o2/transaction_output.txt" || fail 'transaction O0/O2 semantic drift'
cmp -s "$BUILD/o0/fmr44r_output.txt" "$BUILD/o2/fmr44r_output.txt" || fail 'FMR44R O0/O2 semantic drift'
echo 'EB_I19_O0_O2_SEMANTIC_IDENTITY=PASS'

git diff --check "$OWNER"...HEAD -- "$BACKEND" "$RUNTIME" "$TEST"
echo 'EB_I19_PRODUCTION_MATERIALIZATION_QUALIFICATION=PASS'
