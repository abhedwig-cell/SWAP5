#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-eb-i21r-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"
fail(){ echo "EB_I21R_GATE_FAIL $*" >&2; exit 212; }

CANONICAL="b162e98cc4ad6f85b741a21bd41f3db3d213559b"
AUDIT_AUTH="aa4b536a2dcf0df7a17eda64701856ca4a7cb45c"
OWNED="src/runtime/mod_fmr_owned_commit_receipt.f90"
LEDGER="src/runtime/mod_energy_conservation_ledger.f90"
RUNTIME="src/runtime/mod_fmr_serialized_multiswap_runtime.f90"
TEST="tests/eb/test_eb_i21r_owned_receipt_association.f90"

git fetch -q origin integration/f-ci-canonical
git rev-parse --verify "$AUDIT_AUTH^{commit}" >/dev/null
[[ "$(git rev-parse origin/integration/f-ci-canonical)" == "$CANONICAL" ]] || fail 'canonical drift'
git merge-base --is-ancestor "$AUDIT_AUTH" HEAD || fail 'not descended from EB-I21 negative authority'
changed_src="$(git diff --name-only "$AUDIT_AUTH" -- src | LC_ALL=C sort)"
expected_src=$'src/runtime/mod_energy_conservation_ledger.f90\nsrc/runtime/mod_fmr_owned_commit_receipt.f90\nsrc/runtime/mod_fmr_serialized_multiswap_runtime.f90'
[[ "$changed_src" == "$expected_src" ]] || { printf '%s\n' "$changed_src" >&2; fail 'unexpected production source delta'; }
git diff --quiet "$AUDIT_AUTH" -- reference || fail 'reference source changed'
echo 'EB_I21R_EXACT_THREE_FILE_SOURCE_SCOPE=PASS'

# Architecture/static obligations.
grep -Fq 'public :: fmr_commit_candidate_with_owned_receipt' "$OWNED" || fail 'owned commit producer missing'
grep -Fq 'owner_instance_id_value' "$OWNED" || fail 'owned receipt owner storage missing'
grep -Fq 'deliberately no public routine that can bind an already-existing generic' "$OWNED" || fail 'no-after-the-fact-binding contract missing'
! grep -Eiq '^[[:space:]]*save\b|random_number|system_clock|atomic_' "$OWNED" || fail 'hidden/global owner identity mechanism detected'
grep -Fq 'use mod_fmr_owned_commit_receipt, only: fmr_owned_commit_receipt_t' "$LEDGER" || fail 'ledger does not consume owned receipt'
grep -Fq 'receipt%owner_instance_id() /= prepared%owner_instance_id' "$LEDGER" || fail 'ledger owner association guard missing'
grep -Fq 'fmr_commit_candidate_with_owned_receipt(column%column_id' "$RUNTIME" || fail 'runtime does not derive owner from executing logical column'
grep -Fq "local_energy_receipt%owner_instance_id() /= column%column_id" "$RUNTIME" || fail 'runtime postcommit owner assertion missing'
grep -Fq "receipt%owner_instance_id() /= column_id" "$RUNTIME" || fail 'bottom energy finalizer owner assertion missing'
grep -Fq 'call local_energy_receipt%export_accepted_receipt' "$RUNTIME" || fail 'generic receipt export compatibility missing'
echo 'EB_I21R_RUNTIME_OWNER_BINDING_STATIC=PASS'

STRICT=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace)
BASE=(-std=f2008 -Wall -Wextra -Werror -Wno-error=compare-reals -ffree-line-length-none -fcheck=all -fbacktrace)
BASE_MODULES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
)

compile_owned_oracle(){
  local opt="$1" out="$2" src obj
  mkdir -p "$out"; local objects=()
  for src in "${BASE_MODULES[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${BASE[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  for src in "$OWNED" src/kernel/mod_energy_conservation_types.f90 "$LEDGER"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fvq/mod_fvq84_receipt_model.f90 -o "$out/model.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c "$TEST" -o "$out/test.o"
  gfortran -O"$opt" "${objects[@]}" "$out/model.o" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/out.txt"
}
compile_owned_oracle 0 "$BUILD/owned_o0"
compile_owned_oracle 2 "$BUILD/owned_o2"
cmp -s "$BUILD/owned_o0/out.txt" "$BUILD/owned_o2/out.txt" || fail 'owned receipt oracle O0/O2 drift'
cat "$BUILD/owned_o0/out.txt"
for marker in \
  'EBI21R_DISTINCT_COLUMNS_SAME_SCALAR_RECEIPT_TUPLE=CONFIRMED' \
  'EBI21R_GENERIC_RECEIPT_EXPORT_PRESERVED=PASS' \
  'EBI21R_OWN_HANDLE_FOREIGN_COLUMN_RECEIPT_FAIL_CLOSED=PASS' \
  'EBI21R_RIGHTFUL_OWNER_COMMIT_EXACTLY_ONCE=PASS' \
  'EBI21R_CROSS_COLUMN_RECEIPT_ASSOCIATION_REMEDIATION=PASS'; do
  grep -Fq "$marker" "$BUILD/owned_o0/out.txt" || fail "missing owned oracle marker: $marker"
done
echo 'EB_I21R_OWNED_RECEIPT_ORACLE_O0_O2=PASS'

# Re-run the admitted bottom-energy publication path against the remediated
# runtime. This proves the existing candidate-bound accepted-only semantics are
# preserved while the receipt is now owner-bound internally.
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
  src/runtime/mod_fmr_owned_commit_receipt.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
)
TX_TEST=tests/eb/test_eb_i18_transaction_publication.f90
for opt in 0 2; do
  OUT="$BUILD/runtime_o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TX_TEST" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "bottom-energy runtime O$opt"; }
  for marker in \
    'EB_I18_EXTERNAL_COMPLETE_ACCEPTED_PUBLICATION=PASS' \
    'EB_I18_EXTERNAL_UNAVAILABLE_HYDROLOGY_COMMIT=PASS' \
    'EB_I18_EXTERNAL_STALE_HYDROLOGY_COMMIT=PASS' \
    'EB_I18_EXTERNAL_IDENTITY_MISMATCH_FAIL_CLOSED=PASS' \
    'EB_I18_EXTERNAL_INVALID_RESPONSE_FAIL_CLOSED=PASS' \
    'EB_I18_REJECTED_TRIAL_NO_PUBLICATION=PASS' \
    'EB_I18_BACKEND_REUSE_NO_STALE_PUBLICATION=PASS' \
    'EB_I18_TRANSACTION_PUBLICATION_GATE PASS'; do
    grep -Fq "$marker" "$OUT/out.txt" || { cat "$OUT/out.txt" >&2; fail "missing bottom-energy marker O$opt: $marker"; }
  done
  echo "EB_I21R_BOTTOM_ENERGY_RUNTIME_O${opt}=PASS"
done
cmp -s "$BUILD/runtime_o0/out.txt" "$BUILD/runtime_o2/out.txt" || fail 'bottom-energy runtime O0/O2 drift'
echo 'EB_I21R_BOTTOM_ENERGY_RUNTIME_O0_O2=PASS'

FVQ67_TAG=ebi21r bash tests/fvq/run_fvq67_mass_completeness_independent.sh > "$BUILD/mass.txt"
grep -Fq 'FVQ67_EBI21R_O0=PASS' "$BUILD/mass.txt" || fail 'F-KT18 mass O0 missing'
grep -Fq 'FVQ67_EBI21R_O2=PASS' "$BUILD/mass.txt" || fail 'F-KT18 mass O2 missing'
grep -Fq 'FVQ67_EBI21R_O0_O2_IDENTITY=PASS' "$BUILD/mass.txt" || fail 'F-KT18 mass identity missing'
grep -Fq 'FVQ67_REJECTED_COMMITTED_STATE_BITWISE_IMMUTABLE=PASS' "$BUILD/mass.txt" || fail 'rejected committed-state immutability missing'
echo 'EB_I21R_FKT18_MASS_PRESERVATION=PASS'

git diff --check "$AUDIT_AUTH" -- "$OWNED" "$LEDGER" "$RUNTIME" "$TEST"
echo 'EB_I21R_OWNER_QUALIFICATION=PASS'
echo 'EB_I21R_CANONICAL_ADMISSION=NOT_AUTHORIZED'
