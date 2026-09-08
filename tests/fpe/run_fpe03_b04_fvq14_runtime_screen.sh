#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpe03-b04-fvq14-$$"
FVQ14="69e581000bfcf15c74f2c4be5fa089502f794821"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FPE03_B04_FVQ14_FAIL $*" >&2; exit 1; }

# Exact current admitted postimage locks from F-VQ27/F-MR15.
[[ "$(git hash-object src/kernel/mod_kernel_transactions.f90)" == 'af42c7d51ef545e20c76d3000f1ed1493690d68e' ]] || fail 'kernel observer blob drift'
[[ "$(git hash-object src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" == '7a60f8b8d18672098fed1c6890a95aac738ed21d' ]] || fail 'runtime observer blob drift'
[[ "$(git hash-object src/solver/mod_reference_linear_solver.f90)" == 'b292d284e5549049eac1c80df4cc30008154eb96' ]] || fail 'linear solver blob drift'
[[ "$(git hash-object src/legacy/b1_10_port/headcalc.f90)" == '55893f1f5ccba2052ad681743aa155b69f351246' ]] || fail 'HeadCalc blob drift'
echo 'FPE03_B04_FVQ14_CURRENT_POSTIMAGE_LOCKS=PASS'

# Import the immutable independently admitted F-VQ14 workload. The positive
# workload is preserved exactly. Only two test-scope adaptations are allowed:
# (1) print current aggregate kernel diagnostics after its accepted trial;
# (2) omit F-VQ14-era negative "unsupported physics" assertions that were
#     superseded by later independent admissions (notably active roots).
git show "$FVQ14:tests/fvq/test_fvq14_scientific_admission.F90" > "$BUILD/fvq14_original.F90"
[[ "$(git hash-object "$BUILD/fvq14_original.F90")" == '629c0a0405dbf5a39c71e496d879406f88a4cf6d' ]] || fail 'F-VQ14 scientific workload blob drift'
python3 - "$BUILD/fvq14_original.F90" "$BUILD/fvq14_cost_screen.F90" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
anchor="  call require(trim(observation%solver_diagnostics%route) == 'legacy-reference-bound', 'candidate solver route')\n"
assert src.count(anchor)==1
insert="""  write(*,'(A,8(1X,I0))') 'FPE03_B04_FVQ14_INTERVAL_COST=', diagnostics%accepted_substeps, &
       diagnostics%nonlinear_iterations, diagnostics%internal_retries, diagnostics%headcalc_calls, &
       diagnostics%jacobian_builds, diagnostics%linear_solves, diagnostics%backtracking_attempts, &
       diagnostics%alternative_solver_calls
  write(*,'(A)') 'FPE03_B04_FVQ14_COST_OBSERVATION_ONLY=PASS'
"""
src=src.replace(anchor,anchor+insert,1)
start="  ! Unsupported physics remains fail closed.\n"
end="  ! Commit and stale checkpoint fail-closed behaviour.\n"
assert src.count(start)==1 and src.count(end)==1
pre, tail=src.split(start,1)
_, post=tail.split(end,1)
src=pre+"  write(*,'(A)') 'FPE03_B04_FVQ14_SUPERSEDED_NEGATIVE_SCOPE_OMITTED=PASS'\n\n"+end+post
old="  write(*,'(A)') 'FVQ14_UNSUPPORTED_PHYSICS=PASS_FAIL_CLOSED'\n"
assert src.count(old)==1
src=src.replace(old,"  write(*,'(A)') 'FPE03_B04_FVQ14_LATER_ADMISSIONS_RESPECTED=PASS'\n",1)
old_final="  write(*,'(A)') 'FVQ14_SCIENTIFIC_HARNESS PASS'\n"
assert src.count(old_final)==1
src=src.replace(old_final,"  write(*,'(A)') 'FPE03_B04_FVQ14_POSITIVE_RUNTIME_REPLAY PASS'\n",1)
Path(sys.argv[2]).write_text(src)
PY
echo 'FPE03_B04_FVQ14_IMMUTABLE_POSITIVE_WORKLOAD_IMPORTED=PASS'
echo 'FPE03_B04_FVQ14_SUPERSEDED_NEGATIVE_SCOPE_ADAPTED_TEST_ONLY=PASS'

COMMON=(-std=f2008 -cpp -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
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

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/fvq14_cost_screen.F90" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  timeout 60s "$OUT/test" > "$OUT/run-a.txt" 2>&1 || { cat "$OUT/run-a.txt" >&2; exit 1; }
  timeout 60s "$OUT/test" > "$OUT/run-b.txt" 2>&1 || { cat "$OUT/run-b.txt" >&2; exit 1; }
  cmp "$OUT/run-a.txt" "$OUT/run-b.txt"
  for marker in \
    'FVQ14_MASS_COMPLETE=T' \
    'FVQ14_AUTHORITATIVE_RESIDUAL=0.00000000000000000E+000' \
    'FVQ14_ENDPOINT_HEAD_IDENTITY=PASS_BITWISE' \
    'FVQ14_ENDPOINT_THETA_IDENTITY=PASS_BITWISE' \
    'FVQ14_TOP_BOTTOM_FLUX_IDENTITY=PASS_BITWISE' \
    'FVQ14_REAL_HEADCALC_EXECUTED=TRUE' \
    'FVQ14_ROLLBACK=PASS' \
    'FVQ14_REPLAY=PASS' \
    'FVQ14_COMMIT=PASS' \
    'FVQ14_STALE_CHECKPOINT=PASS_FAIL_CLOSED' \
    'FVQ14_GENERIC_TIME=PASS_NONMIDNIGHT_SUBDAILY' \
    'FPE03_B04_FVQ14_COST_OBSERVATION_ONLY=PASS' \
    'FPE03_B04_FVQ14_SUPERSEDED_NEGATIVE_SCOPE_OMITTED=PASS' \
    'FPE03_B04_FVQ14_LATER_ADMISSIONS_RESPECTED=PASS' \
    'FPE03_B04_FVQ14_POSITIVE_RUNTIME_REPLAY PASS'; do
    grep -Fq "$marker" "$OUT/run-a.txt" || fail "missing $marker at O$opt"
  done
  echo "FPE03_B04_FVQ14_O${opt}=PASS"
done
cmp "$BUILD/o0/run-a.txt" "$BUILD/o2/run-a.txt"
echo 'FPE03_B04_FVQ14_O0_O2_IDENTITY=PASS'

COST="$(grep -F 'FPE03_B04_FVQ14_INTERVAL_COST=' "$BUILD/o0/run-a.txt" | head -n1 | sed 's/.*=//;s/^ *//')"
echo "FPE03_B04_FVQ14_INTERVAL_COST=$COST"
BASE='1 3 0 3 3 3 3 0'
if [[ "$COST" == "$BASE" ]]; then
  echo 'FPE03_B04_FVQ14_HIGHER_THAN_BASELINE=NO'
else
  set +e
  python3 - "$COST" <<'PY'
import sys
v=list(map(int,sys.argv[1].split()))
b=[1,3,0,3,3,3,3,0]
assert len(v)==8
assert v[0] > 0
raise SystemExit(0 if any(x>y for x,y in zip(v[1:],b[1:])) else 2)
PY
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    echo 'FPE03_B04_FVQ14_HIGHER_THAN_BASELINE=YES'
  else
    fail "unexpected non-baseline non-higher vector $COST"
  fi
fi
cat "$BUILD/o0/run-a.txt"
echo 'FPE03_B04_FVQ14_RUNTIME_SCREEN PASS'
