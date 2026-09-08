#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq23-$$"
CANDIDATE=985058c0261d284424432a65bded16b7fc9107cb
CANDIDATE_TREE=310b0b419181456b7c0af029e42de742fa96f19d
FSI18_CLOSEOUT=8c5438a73e8ae4c9fcbd9de9fdd82d9a600626b2
FVQ21_CLOSEOUT=f7cdccf11d21c31494b328251b001d474170c0c7
FVQ21_ORACLE_BLOB=ecbe077da9241fb47b36a7f3c5ec54fb8aa18b6b
mkdir -p "$BUILD"
trap 'git -C "$ROOT" worktree remove --force "$BUILD/fsi18" >/dev/null 2>&1 || true; rm -rf "$BUILD"' EXIT
cd "$ROOT"

[[ "$(git rev-parse "$CANDIDATE^{tree}")" == "$CANDIDATE_TREE" ]] || {
  echo 'FVQ23_CANDIDATE_TREE_LOCK=FAIL' >&2; exit 1; }
git diff --quiet "$CANDIDATE" -- src || {
  echo 'FVQ23_CANDIDATE_PRODUCTION_IMMUTABILITY=FAIL' >&2
  git diff --name-only "$CANDIDATE" -- src >&2
  exit 1
}
echo 'FVQ23_CANDIDATE_PRODUCTION_IMMUTABILITY=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FVQ23_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/legacy/b1_10_port/headcalc.f90 1ab0a7dec7a1ca785c01540ebe1c6f3342a1773b
check_blob src/solver/mod_reference_linear_solver.f90 b292d284e5549049eac1c80df4cc30008154eb96
check_blob src/solver/mod_reference_richards_workspace.f90 178d3289e09583c256b1aa400407d468d9c18e68
check_blob src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90 9105126c219cbd06fadfa7757ba95d7b7bd0499b
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 fe1c1cf19d3702114cf7598e227d56f7dbc1e267
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 1bb0c6d4683db2729d48de31babcea72bc1a6caf
check_blob src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f
check_blob src/solver/mod_process_hydraulic_view.f90 d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
check_blob src/solver/mod_b110_root_sink_provider.f90 ef2d2fd883d116c314b98e8f0f14330150b4778a
check_blob tests/fsi/fsi04_real_headcalc_stubs.f90 23c00e4a188e88bc36ef95cbe4faaacdd6aad639
echo 'FVQ23_SOURCE_LOCKS=PASS'

# ---------------------------------------------------------------------------
# Oracle A: independent pre-seam F-SI18 nonzero HeadCalc reference.
# Run the exact F-SI18 reference-TRIDAG control in a detached worktree, then
# compile the same immutable probe against the F-MR13 production postimage.
# The F-SI19 producer gate is deliberately not invoked.
# ---------------------------------------------------------------------------

echo 'FVQ23_FSI18_REFERENCE_BEGIN'
git worktree add --detach "$BUILD/fsi18" "$FSI18_CLOSEOUT" >/dev/null
(
  cd "$BUILD/fsi18"
  FSI18_TRIDAG_EVIDENCE_DIR="$BUILD/fsi18-evidence" \
    bash tests/fsi/run_fsi18_reference_tridag_control_gate.sh > "$BUILD/fsi18-control.log"
)
grep -Fq 'FSI18_REFERENCE_TRIDAG_CONTROL_GATE=PASS_DIAGNOSTIC_ONLY' "$BUILD/fsi18-control.log"
grep -Fq 'FSI18_REFERENCE_TRIDAG_ALL_NONZERO_CONVERGED=YES' "$BUILD/fsi18-control.log"
echo 'FVQ23_FSI18_REFERENCE_CONTROL=PASS'

[[ "$(git rev-parse "$FSI18_CLOSEOUT:tests/fsi/test_fsi18_reference_convergence_cliff.F90")" == \
   '1a0898cfd927455d9219db0f59ac238943cd1435' ]] || {
  echo 'FVQ23_FSI18_PROBE_SOURCE_LOCK=FAIL' >&2; exit 1; }
git show "$FSI18_CLOSEOUT:tests/fsi/test_fsi18_reference_convergence_cliff.F90" \
  > "$BUILD/test_fsi18_reference_convergence_cliff.F90"

# Independently remove only the three legacy external linear-solver stubs from
# the support fixture. This avoids using the F-SI19 producer helper as the
# F-VQ decision procedure while retaining the exact qualified support modules.
python3 - "$BUILD/current-stubs.f90" <<'PY'
from pathlib import Path
import re
import sys
src = Path('tests/fsi/fsi04_real_headcalc_stubs.f90').read_text(encoding='utf-8')
for name in ('tridag', 'bandec', 'banbks'):
    pat = re.compile(rf'(?ims)^subroutine\s+{name}\b.*?^end\s+subroutine\s+{name}\s*\n')
    hits = list(pat.finditer(src))
    if len(hits) != 1:
        raise SystemExit(f'FVQ23 expected one {name} support routine, found {len(hits)}')
    src = pat.sub('', src, count=1)
for forbidden in ('subroutine tridag', 'subroutine bandec', 'subroutine banbks'):
    if forbidden in src.lower():
        raise SystemExit(f'FVQ23 solver support routine remains: {forbidden}')
Path(sys.argv[1]).write_text(src, encoding='utf-8')
print('FVQ23_SOLVERLESS_SUPPORT_FIXTURE=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
HEADCALC_SRC=(
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  tests/fsi/mod_fsi07_top_provider.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
)

for opt in 0 2; do
  OUT="$BUILD/headcalc-o$opt"
  mkdir -p "$OUT"
  objects=()
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c "$BUILD/current-stubs.f90" -o "$OUT/current-stubs.o"
  objects+=("$OUT/current-stubs.o")
  for src in "${HEADCALC_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$OUT" -I "$OUT" \
    -c "$BUILD/test_fsi18_reference_convergence_cliff.F90" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/run-a.txt" 2>&1 || { cat "$OUT/run-a.txt" >&2; exit 1; }
  "$OUT/test" > "$OUT/run-b.txt" 2>&1 || { cat "$OUT/run-b.txt" >&2; exit 1; }
  cmp "$OUT/run-a.txt" "$OUT/run-b.txt"
  grep -Fq 'FSI18_REFERENCE_CONVERGENCE_CLIFF_PROBE PASS' "$OUT/run-a.txt"
  for i in 1 2 3 4 5; do
    grep -Fq "FSI18_CASE_${i}_CONVERGED=T" "$OUT/run-a.txt"
  done
  cmp "$OUT/run-a.txt" "$BUILD/fsi18-evidence/reference-tridag-o${opt}.txt"
  echo "FVQ23_HEADCALC_O${opt}=PASS_BITWISE_FSI18_REFERENCE"
done
cmp "$BUILD/headcalc-o0/run-a.txt" "$BUILD/headcalc-o2/run-a.txt"
echo 'FVQ23_HEADCALC_O0_O2_IDENTITY=PASS'
echo "FVQ23_HEADCALC_OUTPUT_SHA256=$(sha256sum "$BUILD/headcalc-o0/run-a.txt" | cut -d' ' -f1)"

# ---------------------------------------------------------------------------
# Oracle B: independently authored F-VQ21 mass/transaction scientific oracle.
# Use its exact qualified test program, but compile it against the F-MR13
# postimage. Only the compile closure changes by adding the admitted reference
# linear-solver module required by the new HeadCalc seam.
# ---------------------------------------------------------------------------

[[ "$(git rev-parse "$FVQ21_CLOSEOUT:tests/fvq/test_fvq21_root_sink_runtime_oracle.f90")" == \
   "$FVQ21_ORACLE_BLOB" ]] || {
  echo 'FVQ23_FVQ21_ORACLE_SOURCE_LOCK=FAIL' >&2; exit 1; }
git show "$FVQ21_CLOSEOUT:tests/fvq/test_fvq21_root_sink_runtime_oracle.f90" \
  > "$BUILD/test_fvq21_root_sink_runtime_oracle.f90"

RUNTIME_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

for opt in 0 2; do
  OUT="$BUILD/runtime-o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${RUNTIME_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$OUT" -I "$OUT" \
    -c "$BUILD/test_fvq21_root_sink_runtime_oracle.f90" -o "$OUT/oracle.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/oracle.o" -o "$OUT/oracle"
  "$OUT/oracle" > "$OUT/run-a.txt" 2>&1 || { cat "$OUT/run-a.txt" >&2; exit 1; }
  "$OUT/oracle" > "$OUT/run-b.txt" 2>&1 || { cat "$OUT/run-b.txt" >&2; exit 1; }
  cmp "$OUT/run-a.txt" "$OUT/run-b.txt"
  for marker in \
    'FVQ21_NODEWISE_ROOT_QSSDI_HYDRAULIC_CANCELLATION=PASS' \
    'FVQ21_ROOT_AUTHORITATIVE_TOTAL_OUT_EXACTLY_ONCE=PASS' \
    'FVQ21_QSSDI_AUTHORITATIVE_TOTAL_IN_EXACTLY_ONCE=PASS' \
    'FVQ21_HARD_MASS_CONSERVATION=PASS' \
    'FVQ21_ROOT_ROLLBACK_REPLAY=PASS' \
    'FVQ21_ROOT_A_B_A_IDENTITY=PASS' \
    'FVQ21_INACTIVE_NONZERO_ROOT_FAIL_CLOSED=PASS' \
    'FVQ21_NEGATIVE_ROOT_FAIL_CLOSED=PASS' \
    'FVQ21_ROOT_SINK_RUNTIME_SCIENTIFIC_ORACLE PASS'; do
    grep -Fq "$marker" "$OUT/run-a.txt"
  done
  echo "FVQ23_MASS_TRANSACTION_ORACLE_O${opt}=PASS"
done
cmp "$BUILD/runtime-o0/run-a.txt" "$BUILD/runtime-o2/run-a.txt"
echo 'FVQ23_MASS_TRANSACTION_O0_O2_IDENTITY=PASS'
echo "FVQ23_RUNTIME_OUTPUT_SHA256=$(sha256sum "$BUILD/runtime-o0/run-a.txt" | cut -d' ' -f1)"

# Candidate remains byte-identical under src after all verifier execution.
git diff --quiet "$CANDIDATE" -- src || {
  echo 'FVQ23_POST_TEST_PRODUCTION_IMMUTABILITY=FAIL' >&2; exit 1; }
echo 'FVQ23_POST_TEST_PRODUCTION_IMMUTABILITY=PASS'
echo 'FVQ23_FMR13_REFERENCE_LINEAR_SOLVER_RUNTIME_SCIENTIFIC_GATE PASS'
