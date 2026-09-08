#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CANDIDATE="${1:?candidate checkout required}"
RESULTS="${2:-${TMPDIR:-/tmp}/swap5-fvq15-results}"
mkdir -p "$RESULTS"

EXPECTED_HEAD="c28e7a2810b4a3678c577335a6a3086b173eb976"
EXPECTED_TREE="a1a161e5e33fc143a7dc7f3c1b9749fc96f861f6"
EXPECTED_RUNTIME_BLOB="e4f5bc0bf47e2721d689e62107b5224196a093d9"

actual_head="$(git -C "$CANDIDATE" rev-parse HEAD)"
actual_tree="$(git -C "$CANDIDATE" rev-parse HEAD^{tree})"
actual_blob="$(git -C "$CANDIDATE" hash-object src/runtime/mod_fmr_serialized_multiswap_runtime.f90)"
[[ "$actual_head" == "$EXPECTED_HEAD" ]] || { echo "FVQ15_CANDIDATE_HEAD_MISMATCH $actual_head" >&2; exit 1; }
[[ "$actual_tree" == "$EXPECTED_TREE" ]] || { echo "FVQ15_CANDIDATE_TREE_MISMATCH $actual_tree" >&2; exit 1; }
[[ "$actual_blob" == "$EXPECTED_RUNTIME_BLOB" ]] || { echo "FVQ15_RUNTIME_BLOB_MISMATCH $actual_blob" >&2; exit 1; }

# Qualification branch may add only qualification contracts/tests/workflow/evidence.
if [[ -n "$(git -C "$ROOT" diff --name-only "$EXPECTED_HEAD" HEAD -- src reference)" ]]; then
  echo 'FVQ15_PRODUCTION_OR_REFERENCE_SOURCE_CHANGED FAIL' >&2
  git -C "$ROOT" diff --name-only "$EXPECTED_HEAD" HEAD -- src reference >&2
  exit 1
fi

echo 'FVQ15_EXACT_CANDIDATE_LOCK PASS'
echo 'FVQ15_PRODUCTION_REFERENCE_SOURCE_UNCHANGED PASS'

# Re-run the exact candidate's own production engineering gate as supporting evidence.
(
  cd "$CANDIDATE"
  bash tests/fmr/run_fmr05_gate.sh
) > "$RESULTS/fmr05_engineering_replay.log" 2>&1
for marker in \
  'FMR05_FMR04_SINGLE_COLUMN_REGRESSION_O0_O2_IDENTITY PASS' \
  'FMR05_O0_O2_OUTPUT_IDENTITY PASS' \
  'FMR05_CROSS_COLUMN_CHECKPOINT_REJECTION=PASS' \
  'FMR05_STALE_CHECKPOINT_REJECTION=PASS' \
  'FMR05_ROLLBACK_A_LEAVES_A_B_UNCHANGED=PASS' \
  'FMR05_COMMIT_A_LEAVES_B_UNCHANGED=PASS' \
  'FMR05_UNSUPPORTED_ROOT_EXTRACTION=PASS' \
  'FMR05_UNSUPPORTED_MACROPORE=PASS' \
  'FMR05_UNSUPPORTED_SNOW=PASS' \
  'FMR05_UNSUPPORTED_SWKIMPL=PASS' \
  'FMR05_MAX_SIMULTANEOUS_REAL_PHYSICAL_SOLVES=1' \
  'FMR05_SINGLE_COLUMN_FMR04_MASS_BITWISE_IDENTITY=PASS' \
  'FMR05_GATE PASS_STRICT_RUNTIME_CANDIDATE_REQUIRES_FVQ15'; do
  grep -Fq "$marker" "$RESULTS/fmr05_engineering_replay.log"
done
echo 'FVQ15_FMR05_ENGINEERING_REPLAY PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SRC=(
  "$CANDIDATE/tests/fsi/fsi04_real_headcalc_stubs.f90"
  "$CANDIDATE/src/runtime/mod_a23bu_worker_execution_context.f90"
  "$CANDIDATE/src/transaction/mod_transaction_reference.f90"
  "$CANDIDATE/src/runtime/mod_canonical_contracts.f90"
  "$CANDIDATE/src/runtime/mod_canonical_interval_runtime.f90"
  "$CANDIDATE/src/kernel/mod_kernel_transactions.f90"
  "$CANDIDATE/src/runtime/mod_fmr_runtime_core.f90"
  "$CANDIDATE/src/runtime/mod_fmr_checkpoint_orchestrator.f90"
  "$CANDIDATE/src/solver/mod_soil_water_solver_contract.f90"
  "$CANDIDATE/src/solver/mod_reference_richards_workspace.f90"
  "$CANDIDATE/src/solver/mod_reference_richards_state_binding.f90"
  "$CANDIDATE/src/solver/mod_b110_default_mvg_provider.f90"
  "$CANDIDATE/src/solver/mod_b110_source_sink_provider.f90"
  "$CANDIDATE/src/legacy/b1_10_port/headcalc.f90"
  "$CANDIDATE/src/adapter/mod_reference_richards_legacy_binding.f90"
  "$CANDIDATE/src/adapter/mod_b110_serialized_context_binding.f90"
  "$CANDIDATE/src/runtime/mod_fmr_serialized_reference_backend.f90"
  "$CANDIDATE/src/runtime/mod_fmr_serialized_multiswap_runtime.f90"
  "$CANDIDATE/tests/fmr/mod_fmr04_fixed_top_provider.f90"
)

for opt in 0 2; do
  OUT="$RESULTS/vq_o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c "$ROOT/tests/fvq/test_fvq15_multicolumn_reference.f90" -o "$OUT/test_fvq15.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_fvq15.o" -o "$OUT/fvq15_multicolumn_reference"
  "$OUT/fvq15_multicolumn_reference" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }

  for n in 1 2 17 31; do
    grep -Fq "FVQ15_DIRECT_REFERENCE_COLUMNS_${n}=PASS" "$OUT/output.txt"
    grep -Fq "FVQ15_REVERSE_ORDER_COLUMNS_${n}=PASS" "$OUT/output.txt"
  done
  grep -Fq 'FVQ15_A_B_A_EXACT=PASS' "$OUT/output.txt"
  grep -Fq 'FVQ15_GENERIC_TIME_1000_125_TO_1000_625=PASS' "$OUT/output.txt"
  grep -Fq 'FVQ15_MAX_SCIENTIFIC_DIFFERENCE=0.0' "$OUT/output.txt"
  grep -Fq 'FVQ15_MULTICOLUMN_DIRECT_REFERENCE_TEST PASS' "$OUT/output.txt"
  sha256sum "$OUT/fvq15_multicolumn_reference" > "$OUT/executable.sha256"
  sha256sum "$OUT/output.txt" > "$OUT/output.sha256"
  echo "FVQ15_O${opt} PASS"
done

cmp "$RESULTS/vq_o0/output.txt" "$RESULTS/vq_o2/output.txt"
echo 'FVQ15_O0_O2_OUTPUT_IDENTITY PASS'
cat "$RESULTS/vq_o0/output.txt"
echo "FVQ15_O0_EXECUTABLE_SHA256=$(cut -d' ' -f1 "$RESULTS/vq_o0/executable.sha256")"
echo "FVQ15_O2_EXECUTABLE_SHA256=$(cut -d' ' -f1 "$RESULTS/vq_o2/executable.sha256")"
echo "FVQ15_OUTPUT_SHA256=$(cut -d' ' -f1 "$RESULTS/vq_o0/output.sha256")"
echo 'FVQ15_GATE PASS_INDEPENDENT_SERIALIZED_MULTICOLUMN_SCIENTIFIC_ADMISSION'
