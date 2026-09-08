#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

CANDIDATE="ffab7d705928170db3e76a5d346caafeb560e605"
EXPECTED_TREE="06bd92b2cf96b7bc6eb6978250017cd054547a56"
FVQ16_CLOSEOUT="98712959d811c788c77842eede4c6f558cca1c11"
ARTIFACTS=".fvq17-artifacts"
BUILD="${TMPDIR:-/tmp}/swap5-fvq17-$$"
rm -rf "$ARTIFACTS" "$BUILD"
mkdir -p "$ARTIFACTS" "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

check_candidate_blob() {
  local path="$1" expected="$2" candidate_blob head_blob
  candidate_blob="$(git rev-parse "${CANDIDATE}:${path}")"
  head_blob="$(git hash-object "$path")"
  [[ "$candidate_blob" == "$expected" ]] || {
    echo "FVQ17_CANDIDATE_BLOB_MISMATCH $path expected=$expected candidate=$candidate_blob" >&2
    exit 1
  }
  [[ "$head_blob" == "$expected" ]] || {
    echo "FVQ17_HEAD_BLOB_MISMATCH $path expected=$expected head=$head_blob" >&2
    exit 1
  }
}

actual_tree="$(git rev-parse "${CANDIDATE}^{tree}")"
[[ "$actual_tree" == "$EXPECTED_TREE" ]] || {
  echo "FVQ17_CANDIDATE_TREE_MISMATCH expected=$EXPECTED_TREE actual=$actual_tree" >&2
  exit 1
}

check_candidate_blob src/process/mod_snow_process.f90 54702d71b4c84dce2842813549bd14c57301a383
check_candidate_blob src/runtime/mod_fmr_serialized_reference_backend.f90 202ab846cbd30d149d0d450249b3d517e333994f
check_candidate_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 1bb0c6d4683db2729d48de31babcea72bc1a6caf

git diff --exit-code "$CANDIDATE"..HEAD -- src reference
printf '%s\n' "$CANDIDATE" > "$ARTIFACTS/candidate.txt"
printf '%s\n' "$EXPECTED_TREE" > "$ARTIFACTS/candidate-tree.txt"
printf '%s\n' "$FVQ16_CLOSEOUT" > "$ARTIFACTS/fvq16-closeout.txt"
git rev-parse "${CANDIDATE}:src/process/mod_snow_process.f90" > "$ARTIFACTS/process-blob.txt"
git rev-parse "${CANDIDATE}:src/runtime/mod_fmr_serialized_reference_backend.f90" > "$ARTIFACTS/backend-blob.txt"
git rev-parse "${CANDIDATE}:src/runtime/mod_fmr_serialized_multiswap_runtime.f90" > "$ARTIFACTS/runtime-blob.txt"

echo 'FVQ17_SOURCE_IMMUTABILITY=PASS'
echo 'FVQ17_CANDIDATE_LOCK=PASS'

# Supporting evidence only: replay the exact engineering gate on the immutable candidate postimage.
bash tests/fmr/run_fmr06_gate.sh > "$ARTIFACTS/fmr06-engineering-gate.out" 2>&1
grep -Fq 'FMR06_GATE PASS_RUNTIME_CANDIDATE_REQUIRES_INDEPENDENT_FVQ' "$ARTIFACTS/fmr06-engineering-gate.out"
echo 'FVQ17_FMR06_ENGINEERING_REPLAY=PASS'

# Independent scientific process oracle: execute the exact F-VQ16 closeout in a detached worktree.
# Candidate relevance is guaranteed by the already-locked identical process blob above.
FVQ16_WORKTREE="$BUILD/fvq16-worktree"
git worktree add --detach "$FVQ16_WORKTREE" "$FVQ16_CLOSEOUT" > "$ARTIFACTS/fvq16-worktree-add.out" 2>&1
(
  cd "$FVQ16_WORKTREE"
  bash tests/vq/fvq16/run_fvq16_gate.sh
) > "$ARTIFACTS/fvq16-scientific-gate.out" 2>&1
mkdir -p "$ARTIFACTS/fvq16"
cp -a "$FVQ16_WORKTREE/.fvq16-artifacts/." "$ARTIFACTS/fvq16/"
git worktree remove --force "$FVQ16_WORKTREE" > "$ARTIFACTS/fvq16-worktree-remove.out" 2>&1
echo 'FVQ17_DIRECT_FVQ16_ORACLE_REPLAY=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/vq/fvq17/test_fvq17_snow_multiswap_reference.f90 -o "$OUT/fvq17_multiswap.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/fvq17_multiswap.o" -o "$OUT/fvq17_multiswap"
  "$OUT/fvq17_multiswap" > "$OUT/multiswap.out" 2>&1 || { cat "$OUT/multiswap.out" >&2; exit 1; }

  for marker in \
    'FVQ17_PROFILE_ALL_INACTIVE_1_2_17_31=PASS' \
    'FVQ17_PROFILE_ALL_ACTIVE_1_2_17_31=PASS' \
    'FVQ17_PROFILE_MIXED_1_2_17_31=PASS' \
    'FVQ17_DIRECT_FVQ16_SNOW_STATE_IDENTITY=PASS' \
    'FVQ17_NONZERO_MELT_INTERNAL_TRANSFER=PASS' \
    'FVQ17_SNOW_INACTIVE_ZERO_STATE=PASS' \
    'FVQ17_REVERSE_ORDER_COLUMN_IDENTITY=PASS' \
    'FVQ17_REVERSE_ORDER_AGGREGATE_MASS_IDENTITY=PASS' \
    'FVQ17_A_B_A_EXACT=PASS' \
    'FVQ17_AUTHORITATIVE_MASS_COMPLETE=PASS' \
    'FVQ17_SUBDAILY_RUNTIME_FAIL_CLOSED=PASS' \
    'FVQ17_MULTIDAY_RUNTIME_FAIL_CLOSED=PASS' \
    'FVQ17_MAX_SIMULTANEOUS_REAL_PHYSICAL_SOLVES=1' \
    'FVQ17_INDEPENDENT_SNOW_MULTISWAP_REFERENCE PASS'; do
      grep -Fq "$marker" "$OUT/multiswap.out"
  done

  # Independently execute the transaction/checkpoint regression against this exact source postimage.
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fmr/test_fmr06_snow_smoke.f90 -o "$OUT/transactional.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/transactional.o" -o "$OUT/transactional"
  "$OUT/transactional" > "$OUT/transactional.out" 2>&1 || { cat "$OUT/transactional.out" >&2; exit 1; }
  grep -Fq 'FMR06_SNOW_ONE_CALL_DAILY_TRIAL=PASS' "$OUT/transactional.out"
  grep -Fq 'FMR06_SNOW_ROLLBACK=PASS' "$OUT/transactional.out"
  grep -Fq 'FMR06_SNOW_REPLAY_BITWISE=PASS' "$OUT/transactional.out"
  grep -Fq 'FMR06_SNOW_COMMIT=PASS' "$OUT/transactional.out"
  grep -Fq 'FMR06_SNOW_AUTHORITATIVE_MASS_COMPLETE=PASS' "$OUT/transactional.out"
  grep -Fq 'FMR06_SNOW_SUBDAILY_FAIL_CLOSED=PASS' "$OUT/transactional.out"
  grep -Fq 'FMR06_SNOW_MULTIDAY_FAIL_CLOSED=PASS' "$OUT/transactional.out"

  # Independently preserve the exact F-MR05 snow-inactive route/mass/state identity gate.
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fmr/test_fmr05_single_fmr04_identity.f90 -o "$OUT/inactive.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/inactive.o" -o "$OUT/inactive"
  "$OUT/inactive" > "$OUT/inactive.out" 2>&1 || { cat "$OUT/inactive.out" >&2; exit 1; }
  grep -Fq 'FMR05_SINGLE_COLUMN_FMR04_ROUTE_IDENTITY=PASS' "$OUT/inactive.out"
  grep -Fq 'FMR05_SINGLE_COLUMN_FMR04_MASS_BITWISE_IDENTITY=PASS' "$OUT/inactive.out"
  grep -Fq 'FMR05_SINGLE_COLUMN_FMR04_COMMITTED_STATE_IDENTITY=PASS' "$OUT/inactive.out"

  cat "$OUT/multiswap.out" "$OUT/transactional.out" "$OUT/inactive.out" > "$OUT/qualification.out"
  sha256sum "$OUT/fvq17_multiswap" "$OUT/transactional" "$OUT/inactive" > "$ARTIFACTS/o${opt}-executables.sha256"
  sha256sum "$OUT/qualification.out" > "$ARTIFACTS/o${opt}-qualification-output.sha256"
  cp "$OUT/multiswap.out" "$ARTIFACTS/o${opt}-multiswap.out"
  cp "$OUT/transactional.out" "$ARTIFACTS/o${opt}-transactional.out"
  cp "$OUT/inactive.out" "$ARTIFACTS/o${opt}-inactive.out"
  cp "$OUT/qualification.out" "$ARTIFACTS/o${opt}-qualification.out"
  echo "FVQ17_O${opt}=PASS"
done

cmp "$BUILD/o0/multiswap.out" "$BUILD/o2/multiswap.out"
cmp "$BUILD/o0/transactional.out" "$BUILD/o2/transactional.out"
cmp "$BUILD/o0/inactive.out" "$BUILD/o2/inactive.out"
cmp "$BUILD/o0/qualification.out" "$BUILD/o2/qualification.out"
echo 'FVQ17_O0_O2_OUTPUT_IDENTITY=PASS'

# Reassert immutability after all executable checks.
git diff --exit-code "$CANDIDATE"..HEAD -- src reference
sha256sum "$ARTIFACTS/o0-qualification.out" > "$ARTIFACTS/qualification-output.sha256"
cat "$BUILD/o0/qualification.out"
echo "FVQ17_QUALIFICATION_OUTPUT_SHA256=$(cut -d' ' -f1 "$ARTIFACTS/qualification-output.sha256")"
echo 'FVQ17_GATE PASS_INDEPENDENT_FMR06_SNOW_MULTISWAP_SCIENTIFIC_ADMISSION'
