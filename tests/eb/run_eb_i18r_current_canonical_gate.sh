#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-eb-i18r-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "EB_I18R_GATE_FAIL $*" >&2; exit 188; }

CANONICAL="6425fb3290da637357e47618b459f4caf65a78d8"
I13_PARENT="81e3357c06f1fa5b68ce758af583d07b36f5f688"
I13_BACKEND_COMMIT="a21c52ced2e7ce76fbb7be595df7c8b467a3f075"

# This workunit is explicitly current-canonical bound. Do not silently qualify
# against a stale integration spine if another admission has moved canonical.
git fetch -q origin integration/f-ci-canonical
LIVE_CANONICAL="$(git rev-parse origin/integration/f-ci-canonical)"
[[ "$LIVE_CANONICAL" == "$CANONICAL" ]] || fail "live canonical moved: $LIVE_CANONICAL != $CANONICAL"
[[ "$(git merge-base "$CANONICAL" HEAD)" == "$CANONICAL" ]] || fail 'branch is not descended from pinned canonical'
echo "EB_I18R_LIVE_CANONICAL_LOCK=PASS sha=$CANONICAL"

# Immutable, already-qualified EB-owned components are reused byte-for-byte.
declare -A EB_BLOBS=(
  [src/process/mod_liquid_water_sensible_enthalpy.f90]=2247370ee34fac73a0e2d0b9fa15e171467aded3
  [src/runtime/mod_fmr_bottom_thermal_carrier.f90]=c371be3e22eaa6da70ca8cbb060bc42d1e0e0bfb
  [src/runtime/mod_fmr_bottom_external_thermal_binding.f90]=ed2a2ee36add299ebb5f8bde276da2f3b360cc28
  [src/runtime/mod_fmr_bottom_sensible_energy.f90]=1f3d6f975278f960feac4388b0cdd36a0f5f162d
  [src/runtime/mod_fmr_bottom_external_thermal_provider.f90]=885cc50ad1f5cfc17843e412c0f5dfdb989d553b
)
for path in "${!EB_BLOBS[@]}"; do
  actual="$(git hash-object "$path")"
  [[ "$actual" == "${EB_BLOBS[$path]}" ]] || fail "EB authority blob drift $path $actual"
done
echo 'EB_I18R_ISOLATED_EB_AUTHORITY_BLOBS=PASS'

# Project ONLY the qualified I13 backend integration delta onto the current
# backend. A whole historical backend is forbidden because canonical has since
# gained drainage, temporal-certificate and prescribed-qbot functionality.
BACKEND_PATCH="$BUILD/i13-backend.patch"
git diff --binary "$I13_PARENT" "$I13_BACKEND_COMMIT" -- \
  src/runtime/mod_fmr_serialized_reference_backend.f90 > "$BACKEND_PATCH"
[[ -s "$BACKEND_PATCH" ]] || fail 'I13 backend authority patch is empty'
git apply --3way --index "$BACKEND_PATCH" || fail 'I13 backend delta conflicts with current canonical'
echo 'EB_I18R_I13_BACKEND_THREE_WAY_PROJECTION=PASS'

# Materialize the I18 transaction-owner seam and normalize only the obsolete
# qualification fixture/API details to current-canonical semantics.
python3 tests/eb/_apply_eb_i18_runtime_patch.py
python3 tests/eb/_normalize_eb_i18r_current_canonical_fixture.py
python3 tests/eb/_strengthen_eb_i18r_hydrology_assertions.py

BACKEND=src/runtime/mod_fmr_serialized_reference_backend.f90
RUNTIME=src/runtime/mod_fmr_serialized_multiswap_runtime.f90
ADAPTER=src/adapter/mod_b110_serialized_context_binding.f90
TEMPORAL=src/solver/mod_reference_richards_temporal_indicator.f90
TEST=tests/eb/test_eb_i18_transaction_publication.f90

# New EB seam must be present.
grep -Fq 'set_bottom_thermal_carrier_enabled' "$BACKEND" || fail 'thermal backend control missing'
grep -Fq 'bottom_thermal_snapshot' "$BACKEND" || fail 'thermal candidate snapshot missing'
grep -Fq 'capture_attempt_context => fmr_serialized_capture_attempt_context' "$BACKEND" || fail 'thermal rollback capture missing'
grep -Fq 'restore_attempt_context => fmr_serialized_restore_attempt_context' "$BACKEND" || fail 'thermal rollback restore missing'
grep -Fq 'fmr_execute_serialized_column_with_bottom_energy' "$RUNTIME" || fail 'energy publication entrypoint missing'
grep -Fq 'thermal_candidate = backend%bottom_thermal_snapshot()' "$RUNTIME" || fail 'candidate thermal snapshot binding missing'
grep -Fq 'call prepare_candidate_bound_bottom_energy' "$RUNTIME" || fail 'candidate-bound energy preparation missing'
grep -Fq 'call fmr_commit_candidate_with_receipt' "$RUNTIME" || fail 'accepted receipt commit seam missing'
grep -Fq 'call finalize_bottom_energy_publication' "$RUNTIME" || fail 'accepted-only publication finalization missing'
! grep -Fq 'fmr_execute_serialized_resolved_physical_column_with_bottom_energy' "$RUNTIME" || fail 'obsolete I18 entrypoint remains'
! grep -Fq 'thermal_candidate = fmr_bottom_thermal_candidate_t()' "$RUNTIME" || fail 'private candidate constructor remains'

echo 'EB_I18R_TRANSACTIONAL_PUBLICATION_STATIC_CONTRACT=PASS'

# Current-canonical preservation: mode 2, certificate semantics and drainage
# composition must survive the EB projection unchanged in ownership semantics.
grep -Fq 'request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2' "$ADAPTER" || \
  fail 'serialized prescribed-qbot mode2 admission lost'
grep -Fq 'parameters%bottom_mode == 2' "$BACKEND" || fail 'backend mode2 execution admission lost'
grep -Fq 'self%bottom_mode /= 2' "$BACKEND" || fail 'backend mode2 temporal route lost'
grep -Fq '(request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2)' "$TEMPORAL" || \
  fail 'F-SI38 mode2 certificate admission lost'
grep -Fq 'if (request%boundary%bottom_mode == 5) then' "$TEMPORAL" || fail 'F-SI38 Dirichlet-only stiffness guard lost'
grep -Fq 'use mod_fmr_drainage_response_binding' "$BACKEND" || fail 'current drainage response binding lost'
grep -Fq 'drainage_response_active' "$BACKEND" || fail 'current drainage response state/config seam lost'
echo 'EB_I18R_CURRENT_CANONICAL_PRESERVATION_STATIC=PASS'

# Fixture must now be the already-qualified mode-2 bounded inflow route, not
# the historical free-drainage pseudo-inflow.
grep -Fq 'parameters%bottom_mode = 2' "$TEST" || fail 'mode2 fixture missing'
grep -Fq 'FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY' "$TEST" || fail 'temporal history fixture missing'
grep -Fq 'config%model_temporal_indicator_budget = 2.5e-11_real64' "$TEST" || fail 'explicit test budget missing'
grep -Fq 'q = 1.0e-10_real64' "$TEST" || fail 'bounded positive qbot fixture missing'
grep -Fq "abs(output%mass%residual) <= 1.0e-12_real64" "$TEST" || fail 'hard publication mass assertion missing'
grep -Fq "output%accepted_substeps == 1" "$TEST" || fail 'single accepted substep assertion missing'
grep -Fq "output%solver_headcalc_calls == 1" "$TEST" || fail 'bounded HeadCalc assertion missing'
! grep -Fq 'parameters%bottom_mode = 7' "$TEST" || fail 'historical mode7 pseudo-inflow remains'
echo 'EB_I18R_MODE2_PUBLICATION_FIXTURE_STATIC=PASS'

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

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/eb/test_eb_i18_external_bottom_thermal_provider.f90 -o "$OUT/provider_test.o"
  gfortran -O"$opt" "$OUT/mod_fmr_bottom_external_thermal_provider.o" "$OUT/provider_test.o" -o "$OUT/provider_test"
  "$OUT/provider_test" > "$OUT/provider_output.txt" 2>&1 || { cat "$OUT/provider_output.txt" >&2; fail "provider oracle O$opt"; }
  grep -Fq 'EB_I18_EXTERNAL_BOTTOM_THERMAL_PROVIDER_GATE PASS' "$OUT/provider_output.txt" || fail "provider marker O$opt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/eb/test_eb_i18_transaction_publication.f90 -o "$OUT/transaction_test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/transaction_test.o" -o "$OUT/transaction_test"
  "$OUT/transaction_test" > "$OUT/transaction_output.txt" 2>&1 || {
    cat "$OUT/transaction_output.txt" >&2
    fail "transaction publication oracle O$opt"
  }
  for marker in \
    'EB_I18_EXTERNAL_COMPLETE_ACCEPTED_PUBLICATION=PASS' \
    'EB_I18_EXTERNAL_UNAVAILABLE_HYDROLOGY_COMMIT=PASS' \
    'EB_I18_EXTERNAL_STALE_HYDROLOGY_COMMIT=PASS' \
    'EB_I18_EXTERNAL_IDENTITY_MISMATCH_FAIL_CLOSED=PASS' \
    'EB_I18_EXTERNAL_INVALID_RESPONSE_FAIL_CLOSED=PASS' \
    'EB_I18_REJECTED_TRIAL_NO_PUBLICATION=PASS' \
    'EB_I18_BACKEND_REUSE_NO_STALE_PUBLICATION=PASS' \
    'EB_I18_TRANSACTION_PUBLICATION_GATE PASS'; do
    grep -Fq "$marker" "$OUT/transaction_output.txt" || {
      cat "$OUT/transaction_output.txt" >&2
      fail "missing transaction marker O$opt: $marker"
    }
  done

  # Preservation replay of the already-canonical prescribed-qbot capability on
  # the exact EB-staged backend/runtime composition.
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fmr/test_fmr44r_serialized_prescribed_qbot_runtime.f90 -o "$OUT/fmr44r_test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/fmr44r_test.o" -o "$OUT/fmr44r_test"
  "$OUT/fmr44r_test" > "$OUT/fmr44r_output.txt" 2>&1 || {
    cat "$OUT/fmr44r_output.txt" >&2
    fail "FMR44R preservation oracle O$opt"
  }
  grep -Fq 'FMR44R_POSITIVE_QBOT_ACCEPTED_INFLOW=PASS' "$OUT/fmr44r_output.txt" || fail "FMR44R positive qbot marker O$opt"
  grep -Fq 'FMR44R_SERIALIZED_PRESCRIBED_QBOT_RUNTIME_GATE=PASS' "$OUT/fmr44r_output.txt" || fail "FMR44R final marker O$opt"

  cat "$OUT/transaction_output.txt"
  cat "$OUT/fmr44r_output.txt"
  echo "EB_I18R_PROVIDER_O${opt}=PASS"
  echo "EB_I18R_TRANSACTION_O${opt}=PASS"
  echo "EB_I18R_FMR44R_PRESERVATION_O${opt}=PASS"
done

cmp -s "$BUILD/o0/provider_output.txt" "$BUILD/o2/provider_output.txt" || {
  diff -u "$BUILD/o0/provider_output.txt" "$BUILD/o2/provider_output.txt" >&2 || true
  fail 'provider O0/O2 semantic drift'
}
cmp -s "$BUILD/o0/transaction_output.txt" "$BUILD/o2/transaction_output.txt" || {
  diff -u "$BUILD/o0/transaction_output.txt" "$BUILD/o2/transaction_output.txt" >&2 || true
  fail 'transaction O0/O2 semantic drift'
}
cmp -s "$BUILD/o0/fmr44r_output.txt" "$BUILD/o2/fmr44r_output.txt" || {
  diff -u "$BUILD/o0/fmr44r_output.txt" "$BUILD/o2/fmr44r_output.txt" >&2 || true
  fail 'FMR44R preservation O0/O2 semantic drift'
}
echo 'EB_I18R_O0_O2_SEMANTIC_IDENTITY=PASS'

git diff HEAD --check -- "$BACKEND" "$RUNTIME" "$TEST"
echo 'EB_I18R_CURRENT_CANONICAL_STAGED_QUALIFICATION=PASS'
