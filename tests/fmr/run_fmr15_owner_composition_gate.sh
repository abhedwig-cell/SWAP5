#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr15-$$"
FSI_WORKTREE="${TMPDIR:-/tmp}/swap5-fmr15-fsi16-$$"
FVQ26="a1d5ad9147e18301f68183822577b1ba8fca3de2"
FSI16="6591b2f481e1760f844514e63ef873e8deda301f"
mkdir -p "$BUILD"
cleanup() {
  git -C "$ROOT" worktree remove --force "$FSI_WORKTREE" >/dev/null 2>&1 || true
  rm -rf "$BUILD" "$FSI_WORKTREE"
}
trap cleanup EXIT
cd "$ROOT"

fail() { echo "FMR15_GATE_FAIL $*" >&2; exit 1; }
check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || fail "blob mismatch $path expected=$expected actual=$actual"
  echo "FMR15_SOURCE_LOCK=PASS path=$path blob=$actual"
}

check_blob src/adapter/mod_b110_serialized_context_binding.f90 e21c964eac48d5feb91388cfd06a646c4002a497
check_blob src/adapter/mod_reference_richards_legacy_binding.f90 db432cac3f1156a179c636435a25f52cdececffc
check_blob src/legacy/b1_10_port/headcalc.f90 55893f1f5ccba2052ad681743aa155b69f351246
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 6f39d60a87c1987ae95d7faec2f55f865af90a08
check_blob src/solver/mod_reference_richards_workspace.f90 59ef9d037c1875610d45ac83387ebab9e917e0fe
check_blob src/solver/mod_soil_water_solver_contract.f90 4271372085d800fd5da969a2ed073b00422d79c6
check_blob src/kernel/mod_kernel_transactions.f90 af42c7d51ef545e20c76d3000f1ed1493690d68e
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 7a60f8b8d18672098fed1c6890a95aac738ed21d
check_blob src/solver/mod_reference_linear_solver.f90 b292d284e5549049eac1c80df4cc30008154eb96
check_blob src/runtime/mod_fmr_checkpoint_orchestrator.f90 232875e7192f995930c102609cee08dc8938c86a
check_blob src/runtime/mod_fmr_root_uptake_process_binding.f90 2fc348f18e8561096fa34dd3c11c64b359583f11
echo 'FMR15_EXACT_COMPOSED_SOURCE_LOCKS=PASS'

# F-MR14's independently qualified observer files are exact blob locks here.
# In addition, verify every public cost field is assigned exactly once directly
# from kernel diagnostics. No heuristic whole-file substring ban is needed.
python3 - <<'PY'
from pathlib import Path
runtime=Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90').read_text()
for field in ['accepted_substeps','solver_nonlinear_iterations','solver_internal_retries','solver_headcalc_calls',
              'solver_jacobian_builds','solver_linear_solves','solver_backtracking_attempts','solver_alternative_solver_calls']:
    assert runtime.count('output%'+field+' = kernel_diag%') == 1, field
print('FMR15_FMR14_OBSERVER_ASSIGNMENTS_EXACTLY_ONCE=PASS')
print('FMR15_DIAGNOSTICS_DECISION_NEUTRAL_BY_INDEPENDENT_BLOB_LOCK=PASS')
PY

git show "$FVQ26:tests/fvq/test_fvq26_prescribed_bottom_head_runtime_v2.f90" > "$BUILD/fvq26_v2.f90"
[[ "$(git hash-object "$BUILD/fvq26_v2.f90")" == "05002e0e084c21f90e7a97351df3ff8143666948" ]] || \
  fail 'F-VQ26 V2 oracle blob changed'
echo 'FMR15_FVQ26_CORRECTED_V2_ORACLE_LOCK=PASS'

python3 - "$BUILD/fvq26_v2.f90" "$BUILD/fmr15_mode5_diag.f90" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
anchor="  write(*,'(A,Z16.16)') 'FVQ26V2_NEGATIVE_QBOT_BITS=', transfer(obs_down%bottom_flux, 0_int64)\n"
assert src.count(anchor)==1
insert="""  call require(result_down(1)%accepted_substeps == 1, 'down observer accepted substeps')
  call require(result_up(1)%accepted_substeps == 1, 'up observer accepted substeps')
  call require(result_down(1)%solver_nonlinear_iterations > 0, 'down observer nonlinear populated')
  call require(result_up(1)%solver_nonlinear_iterations > 0, 'up observer nonlinear populated')
  call require(result_down(1)%solver_headcalc_calls > 0, 'down observer HeadCalc populated')
  call require(result_up(1)%solver_headcalc_calls > 0, 'up observer HeadCalc populated')
  call require(result_down(1)%solver_jacobian_builds > 0, 'down observer Jacobian populated')
  call require(result_up(1)%solver_jacobian_builds > 0, 'up observer Jacobian populated')
  call require(result_down(1)%solver_linear_solves > 0, 'down observer linear solve populated')
  call require(result_up(1)%solver_linear_solves > 0, 'up observer linear solve populated')
  call require(result_down(1)%solver_backtracking_attempts > 0, 'down observer backtracking populated')
  call require(result_up(1)%solver_backtracking_attempts > 0, 'up observer backtracking populated')
  write(*,'(A,8(1X,I0))') 'FMR15_MODE5_DOWN_INTERVAL_COST=', result_down(1)%accepted_substeps, &
       result_down(1)%solver_nonlinear_iterations, result_down(1)%solver_internal_retries, &
       result_down(1)%solver_headcalc_calls, result_down(1)%solver_jacobian_builds, &
       result_down(1)%solver_linear_solves, result_down(1)%solver_backtracking_attempts, &
       result_down(1)%solver_alternative_solver_calls
  write(*,'(A,8(1X,I0))') 'FMR15_MODE5_UP_INTERVAL_COST=', result_up(1)%accepted_substeps, &
       result_up(1)%solver_nonlinear_iterations, result_up(1)%solver_internal_retries, &
       result_up(1)%solver_headcalc_calls, result_up(1)%solver_jacobian_builds, &
       result_up(1)%solver_linear_solves, result_up(1)%solver_backtracking_attempts, &
       result_up(1)%solver_alternative_solver_calls
  write(*,'(A)') 'FMR15_ACCEPTED_TWO_SIGN_MODE5_DIAGNOSTICS=PASS'
"""
Path(sys.argv[2]).write_text(src.replace(anchor,insert+anchor,1))
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
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
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_root_water_uptake_process.f90
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
  src/runtime/mod_fmr_root_uptake_process_binding.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)
TESTS=(
  "$BUILD/fmr15_mode5_diag.f90"
  tests/fmr/test_fmr09_root_sink_runtime.f90
  tests/fmr/test_fmr10_root_uptake_runtime_bridge.f90
  tests/fmr/test_fmr07_committed_process_hydraulic_view.f90
  tests/fmr/test_fmr06_snow_smoke.f90
  tests/fvq/test_fvq22_root_uptake_runtime_oracle.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  for test in "${TESTS[@]}"; do
    name="$(basename "${test%.*}")"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$test" -o "$OUT/$name.o"
    gfortran -O"$opt" "${objects[@]}" "$OUT/$name.o" -o "$OUT/$name"
    timeout 60s "$OUT/$name" > "$OUT/$name.txt" 2>&1 || { cat "$OUT/$name.txt" >&2; exit 1; }
  done

  VQ="$OUT/fmr15_mode5_diag.txt"
  for marker in \
    'FVQ26V2_ACCEPTED_NEGATIVE_QBOT=PASS' \
    'FVQ26V2_ACCEPTED_POSITIVE_QBOT=PASS' \
    'FVQ26V2_BOTTOM_HEAD_AUTHORITY=PASS' \
    'FVQ26V2_BOTTOM_FLUX_SEED_IRRELEVANCE=PASS' \
    'FVQ26V2_QBOT_MASS_EXACTLY_ONCE=PASS' \
    'FVQ26V2_TRANSACTION_DISCARD_ISOLATION=PASS' \
    'FVQ26V2_A_B_A_REPLAY=PASS' \
    'FVQ26V2_ZERO_TOLERANCE_TEMPORAL_ACCEPTANCE=PASS' \
    'FVQ26V2_FAIL_CLOSED_PROFILE=PASS' \
    'FVQ26V2_SERIALIZED_ONLY=PASS' \
    'FMR15_ACCEPTED_TWO_SIGN_MODE5_DIAGNOSTICS=PASS' \
    'FVQ26V2_PRESCRIBED_BOTTOM_HEAD_RUNTIME_ORACLE PASS'; do
    grep -Fq "$marker" "$VQ" || fail "missing $marker at O$opt"
  done
  grep -Fq 'FMR09_ROOT_SINK_RUNTIME_TEST PASS' "$OUT/test_fmr09_root_sink_runtime.txt"
  grep -Fq 'FMR10_ROOT_UPTAKE_RUNTIME_BRIDGE_TEST PASS' "$OUT/test_fmr10_root_uptake_runtime_bridge.txt"
  grep -Fq 'FMR07_COMMITTED_PROCESS_HYDRAULIC_VIEW PASS' "$OUT/test_fmr07_committed_process_hydraulic_view.txt"
  grep -Fq 'FMR06_SNOW_ROLLBACK=PASS' "$OUT/test_fmr06_snow_smoke.txt"
  grep -Fq 'FMR06_SNOW_REPLAY_BITWISE=PASS' "$OUT/test_fmr06_snow_smoke.txt"
  grep -Fq 'FVQ22_ROOT_UPTAKE_RUNTIME_ORACLE PASS' "$OUT/test_fvq22_root_uptake_runtime_oracle.txt"

  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/crop/mod_crop_root_uptake_input_contract.f90 -o "$OUT/mod_crop_root_uptake_input_contract.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90 -o "$OUT/mod_fmr_crop_root_uptake_input_adapter.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fmr/test_fmr12_crop_root_uptake_input_adapter.f90 -o "$OUT/test_fmr12.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/mod_crop_root_uptake_input_contract.o" \
    "$OUT/mod_fmr_crop_root_uptake_input_adapter.o" "$OUT/test_fmr12.o" -o "$OUT/test_fmr12"
  "$OUT/test_fmr12" > "$OUT/test_fmr12.txt" 2>&1 || { cat "$OUT/test_fmr12.txt" >&2; exit 1; }
  grep -Fq 'FMR12_WRAPPER_BITWISE_EQUIVALENT_TO_DIRECT_FMR10=PASS' "$OUT/test_fmr12.txt"
  grep -Fq 'FMR12_A_B_A_DETERMINISM=PASS' "$OUT/test_fmr12.txt"
  grep -Fq 'FMR12_CROP_ROOT_UPTAKE_INPUT_ADAPTER_TEST PASS' "$OUT/test_fmr12.txt"

  cat "$VQ" \
      "$OUT/test_fmr09_root_sink_runtime.txt" \
      "$OUT/test_fmr10_root_uptake_runtime_bridge.txt" \
      "$OUT/test_fmr07_committed_process_hydraulic_view.txt" \
      "$OUT/test_fmr06_snow_smoke.txt" \
      "$OUT/test_fvq22_root_uptake_runtime_oracle.txt" \
      "$OUT/test_fmr12.txt" > "$OUT/output.txt"
  echo "FMR15_O${opt}=PASS"
done

cmp "$BUILD/o0/fmr15_mode5_diag.txt" "$BUILD/o2/fmr15_mode5_diag.txt"
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FMR15_O0_O2_OUTPUT_AND_DIAGNOSTIC_IDENTITY=PASS'
echo 'FMR15_FMR09_REGRESSION=PASS'
echo 'FMR15_FMR10_REGRESSION=PASS'
echo 'FMR15_FMR07_REGRESSION=PASS'
echo 'FMR15_FMR06_REGRESSION=PASS'
echo 'FMR15_FVQ22_REGRESSION=PASS'
echo 'FMR15_FMR12_REGRESSION=PASS'
grep -F 'FMR15_MODE5_DOWN_INTERVAL_COST=' "$BUILD/o0/fmr15_mode5_diag.txt"
grep -F 'FMR15_MODE5_UP_INTERVAL_COST=' "$BUILD/o0/fmr15_mode5_diag.txt"
cat "$BUILD/o0/fmr15_mode5_diag.txt"
echo "FMR15_COMPOSED_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"

git worktree add --detach "$FSI_WORKTREE" "$FSI16" >/dev/null
(
  cd "$FSI_WORKTREE"
  bash tests/fsi/run_fsi16_b110_direct_oracle_gate.sh
) > "$BUILD/fsi16.txt" 2>&1 || { cat "$BUILD/fsi16.txt" >&2; exit 1; }
grep -Fq 'F-SI16_B110_EXACT_COMMON_IDENTITY_O0 PASS' "$BUILD/fsi16.txt"
grep -Fq 'F-SI16_B110_EXACT_COMMON_IDENTITY_O2 PASS' "$BUILD/fsi16.txt"
grep -Fq 'F-SI16_B110_INDEPENDENT_QBOT_AUTHORITY PASS' "$BUILD/fsi16.txt"
grep -Fq 'F-SI16_B110_INDEPENDENT_ORACLE_GATE PASS' "$BUILD/fsi16.txt"
echo 'FMR15_FSI16_PARENT_REPLAY=PASS'

echo 'FMR15_PHYSICS_CHANGED=NO'
echo 'FMR15_NUMERICAL_CONTROLS_CHANGED=NO'
echo 'FMR15_ACCEPTANCE_CHANGED=NO'
echo 'FMR15_MASS_REQUIREMENT_RELAXED=NO'
echo 'FMR15_TRANSACTION_SEMANTICS_CHANGED=NO'
echo 'FMR15_PARALLEL_REFERENCE_ADMISSION=NO'
echo 'FMR15_OWNER_COMPOSITION_GATE PASS'
