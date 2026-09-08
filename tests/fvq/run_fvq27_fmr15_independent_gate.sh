#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq27-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FMR15_CLOSEOUT="6d915141d42f3db469c2da689aabd4ca4836c23c"
FMR15_OWNER_TESTED="ee34be5346865e28fa71df6ddd48f8cc482fac78"
FSI19_CLOSEOUT="d3a1bc8eef243b6109af8871398c06e1840fb367"

fail() { echo "FVQ27_GATE_FAIL $*" >&2; exit 1; }
check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || fail "blob mismatch $path expected=$expected actual=$actual"
  echo "FVQ27_SOURCE_LOCK=PASS path=$path blob=$actual"
}

# The qualification branch must remain production-identical to the exact F-MR15 closeout.
for path in \
  src/adapter/mod_b110_serialized_context_binding.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/legacy/b1_10_port/headcalc.f90 \
  src/runtime/mod_fmr_serialized_reference_backend.f90 \
  src/solver/mod_reference_richards_workspace.f90 \
  src/solver/mod_soil_water_solver_contract.f90 \
  src/kernel/mod_kernel_transactions.f90 \
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90 \
  src/solver/mod_reference_linear_solver.f90 \
  src/runtime/mod_fmr_checkpoint_orchestrator.f90 \
  src/runtime/mod_fmr_root_uptake_process_binding.f90; do
  [[ "$(git hash-object "$path")" == "$(git rev-parse "$FMR15_CLOSEOUT:$path")" ]] || fail "production drift $path"
done
echo 'FVQ27_PRODUCTION_IMMUTABILITY_TO_FMR15_CLOSEOUT=PASS'

# Closeout after the owner-tested candidate changed only the persisted owner status.
mapfile -t closeout_delta < <(git diff --name-only "$FMR15_OWNER_TESTED" "$FMR15_CLOSEOUT")
[[ "${#closeout_delta[@]}" -eq 1 ]] || fail "unexpected F-MR15 closeout delta count=${#closeout_delta[@]}"
[[ "${closeout_delta[0]}" == 'integration/f-mr/F-MR15_STATUS.json' ]] || fail "unexpected F-MR15 closeout delta=${closeout_delta[0]}"
echo 'FVQ27_FMR15_CLOSEOUT_ONLY_STATUS_AFTER_OWNER_TEST=PASS'

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
check_blob tests/fmr/run_fmr15_owner_composition_gate.sh ae81257e1d53e88c3f4aa095def628b6a80a6c37
echo 'FVQ27_EXACT_COMPOSED_SOURCE_AND_OWNER_GATE_LOCKS=PASS'

# Re-run the full source-bound owner workload matrix on the independent branch.
bash tests/fmr/run_fmr15_owner_composition_gate.sh > "$BUILD/fmr15-owner-replay.log" 2>&1 || {
  cat "$BUILD/fmr15-owner-replay.log" >&2
  exit 1
}
cat "$BUILD/fmr15-owner-replay.log"
for marker in \
  'FMR15_EXACT_COMPOSED_SOURCE_LOCKS=PASS' \
  'FMR15_FMR14_OBSERVER_ASSIGNMENTS_EXACTLY_ONCE=PASS' \
  'FMR15_DIAGNOSTICS_DECISION_NEUTRAL_BY_INDEPENDENT_BLOB_LOCK=PASS' \
  'FMR15_ACCEPTED_TWO_SIGN_MODE5_DIAGNOSTICS=PASS' \
  'FVQ26V2_ACCEPTED_NEGATIVE_QBOT=PASS' \
  'FVQ26V2_ACCEPTED_POSITIVE_QBOT=PASS' \
  'FVQ26V2_QBOT_MASS_EXACTLY_ONCE=PASS' \
  'FVQ26V2_TRANSACTION_DISCARD_ISOLATION=PASS' \
  'FVQ26V2_A_B_A_REPLAY=PASS' \
  'FVQ26V2_ZERO_TOLERANCE_TEMPORAL_ACCEPTANCE=PASS' \
  'FMR15_O0_O2_OUTPUT_AND_DIAGNOSTIC_IDENTITY=PASS' \
  'FMR15_FMR09_REGRESSION=PASS' \
  'FMR15_FMR10_REGRESSION=PASS' \
  'FMR15_FMR07_REGRESSION=PASS' \
  'FMR15_FMR06_REGRESSION=PASS' \
  'FMR15_FVQ22_REGRESSION=PASS' \
  'FMR15_FMR12_REGRESSION=PASS' \
  'FMR15_FSI16_PARENT_REPLAY=PASS' \
  'FMR15_OWNER_COMPOSITION_GATE PASS'; do
  grep -Fq "$marker" "$BUILD/fmr15-owner-replay.log" || fail "missing owner replay marker: $marker"
done

DOWN="$(grep -F 'FMR15_MODE5_DOWN_INTERVAL_COST=' "$BUILD/fmr15-owner-replay.log" | head -n1 | sed 's/.*=//;s/^ *//')"
UP="$(grep -F 'FMR15_MODE5_UP_INTERVAL_COST=' "$BUILD/fmr15-owner-replay.log" | head -n1 | sed 's/.*=//;s/^ *//')"
EXPECTED='1 3 0 3 3 3 3 0'
[[ "$DOWN" == "$EXPECTED" ]] || fail "unexpected down cost vector: $DOWN"
[[ "$UP" == "$EXPECTED" ]] || fail "unexpected up cost vector: $UP"
echo "FVQ27_MODE5_DOWN_INTERVAL_COST=$DOWN"
echo "FVQ27_MODE5_UP_INTERVAL_COST=$UP"
echo 'FVQ27_STATIONARY_MODE5_COST_EQUALS_REFERENCE_BASELINE=PASS'

# Independent F-SI19 direct oracle: immutable oracle source from exact F-SI19 closeout,
# compiled against the current F-MR15 production module under O0 and O2.
git show "$FSI19_CLOSEOUT:tests/fsi/test_fsi19_reference_linear_solver.f90" > "$BUILD/test_fsi19_reference_linear_solver.f90"
[[ "$(git hash-object "$BUILD/test_fsi19_reference_linear_solver.f90")" == 'bf8c9d85c98157d128086d2c2fb20f6129b98e63' ]] || fail 'F-SI19 direct oracle blob changed'
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/fsi19-o$opt"; mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    src/solver/mod_reference_linear_solver.f90 "$BUILD/test_fsi19_reference_linear_solver.f90" \
    -o "$OUT/test"
  "$OUT/test" > "$OUT/run-a.txt"
  "$OUT/test" > "$OUT/run-b.txt"
  cmp "$OUT/run-a.txt" "$OUT/run-b.txt"
  grep -Fq 'FSI19_TRIDAG_SUCCESS_N1=PASS_BITWISE' "$OUT/run-a.txt"
  grep -Fq 'FSI19_TRIDAG_SUCCESS_N7=PASS_BITWISE' "$OUT/run-a.txt"
  grep -Fq 'FSI19_TRIDAG_IERROR_1000=PASS' "$OUT/run-a.txt"
  grep -Fq 'FSI19_TRIDAG_IERROR_1002=PASS' "$OUT/run-a.txt"
  grep -Fq 'FSI19_BAND_N4_FORCE_PIVOT_T=PASS_BITWISE_PADDED_ORACLE' "$OUT/run-a.txt"
  grep -Fq 'FSI19_BAND_N5_FORCE_PIVOT_T=PASS_BITWISE_PADDED_ORACLE' "$OUT/run-a.txt"
  grep -Fq 'FSI19_DIRECT_REFERENCE_LINEAR_SOLVER_ORACLE PASS' "$OUT/run-a.txt"
  echo "FVQ27_FSI19_DIRECT_ORACLE_O${opt}=PASS"
done
cmp "$BUILD/fsi19-o0/run-a.txt" "$BUILD/fsi19-o2/run-a.txt"
echo 'FVQ27_FSI19_DIRECT_ORACLE_O0_O2_IDENTITY=PASS'
cat "$BUILD/fsi19-o0/run-a.txt"

# Scientific scope guards.
echo 'FVQ27_PHYSICS_CHANGED=NO'
echo 'FVQ27_NUMERICAL_CONTROLS_CHANGED=NO'
echo 'FVQ27_ACCEPTANCE_CHANGED=NO'
echo 'FVQ27_RETRY_POLICY_CHANGED=NO'
echo 'FVQ27_MASS_REQUIREMENT_RELAXED=NO'
echo 'FVQ27_TRANSACTION_SEMANTICS_CHANGED=NO'
echo 'FVQ27_PARALLEL_REFERENCE_ADMISSION=NO'
echo 'FVQ27_FPE03_B04_RESOLVED=NO'
echo 'FVQ27_FMR15_INDEPENDENT_SCIENTIFIC_ADMISSION_GATE PASS'
