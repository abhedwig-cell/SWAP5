#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-eb-i19r-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "EB_I19R_GATE_FAIL $*" >&2; exit 192; }

CANONICAL="5e5e498dc56d1df1dd7ebebbf9901c946445a1ab"
BASE="b2ba462cfade41eb68643db75ca28e234a123a02"
BACKEND="src/runtime/mod_fmr_serialized_reference_backend.f90"
RUNTIME="src/runtime/mod_fmr_serialized_multiswap_runtime.f90"
ENERGY="src/runtime/mod_fmr_bottom_sensible_energy.f90"
TEST="tests/eb/test_eb_i18_transaction_publication.f90"

git fetch -q origin integration/f-ci-canonical
[[ "$(git rev-parse origin/integration/f-ci-canonical)" == "$CANONICAL" ]] || fail 'live canonical moved'
git merge-base --is-ancestor "$BASE" HEAD || fail 'branch is not descended from exact EB-I19 candidate'

changed_src="$(git diff --name-only "$BASE" HEAD -- src | sort)"
expected_src=$'src/runtime/mod_fmr_bottom_sensible_energy.f90\nsrc/runtime/mod_fmr_serialized_multiswap_runtime.f90\nsrc/runtime/mod_fmr_serialized_reference_backend.f90'
[[ "$changed_src" == "$expected_src" ]] || { printf '%s\n' "$changed_src" >&2; fail 'warning remediation changed unexpected production source'; }
git diff --quiet "$BASE" HEAD -- reference || fail 'warning remediation changed reference source'
git diff --quiet "$BASE" HEAD -- tests/eb/test_eb_i18_transaction_publication.f90 || fail 'warning remediation changed EB-I19 qualification fixture'
echo 'EB_I19R_EXACT_THREE_FILE_WARNING_REMEDIATION_SCOPE=PASS'

# Static proof that the warned expressions were replaced by explicit evaluation
# order without changing the physical branch decisions.
grep -Fq 'config%max_committed_substeps <= ishft(huge(0), -1)' "$BACKEND" || fail 'overflow-safe carrier bound missing'
! grep -Fq 'config%max_committed_substeps <= huge(0)/2' "$BACKEND" || fail 'old integer-division guard remains'
grep -Fq 'if (candidate%ready()) then' "$BACKEND" || fail 'explicit candidate readiness check missing'
! grep -Fq 'result%completed .and. candidate%ready()' "$BACKEND" || fail 'old candidate short-circuit expression remains'
grep -Fq 'if (.not. response%ready()) then' "$RUNTIME" || fail 'explicit response readiness guard missing'
grep -Fq 'if (.not. response%identity_matches(request)) then' "$RUNTIME" || fail 'explicit response identity guard missing'
! grep -Fq 'response%ready() .or. .not. response%identity_matches(request)' "$RUNTIME" || fail 'old response short-circuit expression remains'
grep -Fq 'if (.not. candidate%ready()) return' "$ENERGY" || fail 'explicit energy candidate readiness guard missing'
grep -Fq 'if (.not. parameters%ready()) return' "$ENERGY" || fail 'explicit energy parameter readiness guard missing'
! grep -Fq 'candidate%ready() .or. .not. parameters%ready()' "$ENERGY" || fail 'old energy readiness short-circuit expression remains'
echo 'EB_I19R_WARNING_SOURCE_TRANSFORMATION_STATIC=PASS'

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
    extra=()
    case "$source" in
      "$ENERGY"|"$BACKEND"|"$RUNTIME")
        extra=(-Werror=function-elimination -Werror=integer-division)
        ;;
    esac
    gfortran "${COMMON[@]}" "${extra[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  echo "EB_I19R_AFFECTED_PRODUCTION_WARNING_HYGIENE_O${opt}=PASS"

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
  "$OUT/fmr44r_test" > "$OUT/fmr44r_output.txt" 2>&1 || { cat "$OUT/fmr44r_output.txt" >&2; fail "FMR44R preservation O$opt"; }
  grep -Fq 'FMR44R_POSITIVE_QBOT_ACCEPTED_INFLOW=PASS' "$OUT/fmr44r_output.txt" || fail "FMR44R positive qbot marker O$opt"
  grep -Fq 'FMR44R_SERIALIZED_PRESCRIBED_QBOT_RUNTIME_GATE=PASS' "$OUT/fmr44r_output.txt" || fail "FMR44R final marker O$opt"

  cat "$OUT/transaction_output.txt"
  cat "$OUT/fmr44r_output.txt"
  echo "EB_I19R_TRANSACTION_O${opt}=PASS"
  echo "EB_I19R_FMR44R_PRESERVATION_O${opt}=PASS"
done

cmp -s "$BUILD/o0/provider_output.txt" "$BUILD/o2/provider_output.txt" || fail 'provider O0/O2 semantic drift'
cmp -s "$BUILD/o0/transaction_output.txt" "$BUILD/o2/transaction_output.txt" || fail 'transaction O0/O2 semantic drift'
cmp -s "$BUILD/o0/fmr44r_output.txt" "$BUILD/o2/fmr44r_output.txt" || fail 'FMR44R O0/O2 semantic drift'
echo 'EB_I19R_O0_O2_SEMANTIC_IDENTITY=PASS'

git diff --check "$BASE"...HEAD -- "$ENERGY" "$BACKEND" "$RUNTIME"
echo 'EB_I19R_WARNING_HYGIENE_QUALIFICATION=PASS'
