#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq48-$$"
BASE=e3964ec0ef312f974461aeac70fb9bc5720803e3
OWNER_CANDIDATE=95e31ca4aa7d9a6a3cfe5f563c2a5ef02255125c
OWNER_HANDOFF=c908621d10868b5e265a8835ea2c0c56ee202ef6
SOURCE=src/runtime/mod_fmr_root_uptake_attribution_receipt.f90
SOURCE_BLOB=886d251908126693b6fe035e065a872ce5ff4e29
mkdir -p "$BUILD/o0" "$BUILD/o2" "$BUILD/owner"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FVQ48_GATE_FAIL $*" >&2; exit 1; }

[[ "$(git rev-parse "$OWNER_CANDIDATE:$SOURCE")" == "$SOURCE_BLOB" ]] || fail 'owner candidate blob mismatch'
[[ "$(git rev-parse "HEAD:$SOURCE")" == "$SOURCE_BLOB" ]] || fail 'qualification head candidate blob drift'
git merge-base --is-ancestor "$OWNER_HANDOFF" HEAD || fail 'qualification branch lost owner handoff ancestry'
git diff --quiet "$OWNER_CANDIDATE"..HEAD -- src || fail 'production source changed after owner candidate'
mapfile -t src_delta < <(git diff --name-only "$BASE"..HEAD -- src | sort)
printf '%s\n' "${src_delta[@]}" > "$BUILD/src-delta.txt"
printf '%s\n' "$SOURCE" > "$BUILD/expected-src-delta.txt"
cmp -s "$BUILD/src-delta.txt" "$BUILD/expected-src-delta.txt" || {
  cat "$BUILD/src-delta.txt" >&2
  fail 'F-VQ48 does not preserve exact one-file production delta'
}
echo 'FVQ48_EXACT_PINNED_CANDIDATE_BLOB=PASS'
echo 'FVQ48_NO_QUALIFICATION_PRODUCTION_MUTATION=PASS'

for independent_source in \
  tests/fvq/mod_fvq48_independent_root_mass_model.f90 \
  tests/fvq/test_fvq48_independent_root_uptake_attribution.f90; do
  if grep -Fq 'mod_fmr30_root_attribution_test_backend' "$independent_source" || \
     grep -Fq 'test_fmr30_root_uptake_attribution_receipt' "$independent_source"; then
    fail "owner oracle dependency leaked into $independent_source"
  fi
done
echo 'FVQ48_INDEPENDENT_ORACLE_HAS_NO_OWNER_TEST_DEPENDENCY=PASS'

COMMON=(-std=f2008 -Wall -Wextra -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
REAL_MODULES=(
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
  src/process/mod_root_water_uptake_process.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  objects=()
  for src in "${REAL_MODULES[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  obj="$OUT/mod_fmr_root_uptake_attribution_receipt.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$SOURCE" -o "$obj"
  objects+=("$obj")

  obj="$OUT/mod_fvq48_independent_root_mass_model.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fvq/mod_fvq48_independent_root_mass_model.f90 -o "$obj"
  objects+=("$obj")

  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fvq/test_fvq48_independent_root_uptake_attribution.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "independent oracle O$opt"; }

  for marker in \
    'FVQ48_INDEPENDENT_QROT_INTERVAL_MATRIX=PASS' \
    'FVQ48_INVALID_FORCING_FAIL_CLOSED=PASS' \
    'FVQ48_PRECOMMIT_PUBLICATION_FAIL_CLOSED=PASS' \
    'FVQ48_LINEAGE_REVISION_MISMATCH_FAIL_CLOSED=PASS' \
    'FVQ48_INTERVAL_MISMATCH_FAIL_CLOSED=PASS' \
    'FVQ48_A_B_A_PREPARED_CONTEXT_INDEPENDENCE=PASS' \
    'FVQ48_CORRECT_PAIRING_RECONCILES_WITH_BOOKED_ROOT_MASS=PASS' \
    'FVQ48_VALID_FORCING_MISPAIR_NOT_DETECTABLE=OBSERVED' \
    'FVQ48_STANDALONE_CALLER_PAIRING_PRECONDITION=UNENFORCED' \
    'FVQ48_INDEPENDENT_ROOT_UPTAKE_ATTRIBUTION_ORACLE PASS'; do
    grep -Fq "$marker" "$OUT/out.txt" || { cat "$OUT/out.txt" >&2; fail "missing O$opt marker: $marker"; }
  done
done
cmp -s "$BUILD/o0/out.txt" "$BUILD/o2/out.txt" || fail 'independent O0/O2 output mismatch'
echo 'FVQ48_O0_O2_INDEPENDENT_ORACLE_IDENTITY=PASS'
echo 'FVQ48_REAL_CANONICAL_BACKEND_LINKED_IN_INDEPENDENT_ORACLE=PASS'

bash tests/fmr/run_fmr30_root_uptake_attribution_receipt_gate.sh > "$BUILD/owner/out.txt" 2>&1 || {
  cat "$BUILD/owner/out.txt" >&2
  fail 'F-MR30 owner-gate preservation replay'
}
grep -Fq 'FMR30_RESTRICTED_ROOT_UPTAKE_ATTRIBUTION_RECEIPT_GATE PASS' "$BUILD/owner/out.txt" || \
  fail 'owner gate final marker absent'
echo 'FVQ48_FMR30_OWNER_GATE_PRESERVATION=PASS'

# The independent evidence gate is green when it successfully characterizes
# both the qualified local semantics and the unresolved caller-pairing seam.
# A green workflow is therefore not itself a scientific admission decision.
echo 'FVQ48_INDEPENDENT_EVIDENCE_GATE PASS'
