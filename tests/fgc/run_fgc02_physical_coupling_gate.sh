#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fgc02-physical-$$"
FMR_WORKTREE="${TMPDIR:-/tmp}/swap5-fgc02-fmr11-$$"
FMR11_CANDIDATE="194f66d413fdfc3b75fc12125412539ea2fc7d2d"
FMR11_CLOSEOUT="86924e93ee81f8c246c28e8277b8ade6079ebaa7"
DRIVER="$ROOT/tests/fgc/test_fgc02_physical_coupling.f90"
RESPONSE_STUB="$BUILD/fsi16_response_headcalc_stubs.f90"
mkdir -p "$BUILD"
cleanup() {
  git -C "$ROOT" worktree remove --force "$FMR_WORKTREE" >/dev/null 2>&1 || true
  rm -rf "$BUILD" "$FMR_WORKTREE"
}
trap cleanup EXIT

fail() { echo "FGC02_PHYSICAL_GATE_FAIL $*" >&2; exit 1; }
check_blob() {
  local tree="$1" path="$2" expected="$3" actual
  actual="$(git -C "$tree" hash-object "$path")"
  [[ "$actual" == "$expected" ]] || fail "blob mismatch $path expected=$expected actual=$actual"
  echo "FGC02_FMR11_SOURCE_LOCK PASS $path $actual"
}

cd "$ROOT"
git cat-file -e "$FMR11_CANDIDATE^{commit}"
git cat-file -e "$FMR11_CLOSEOUT^{commit}"
if ! git diff --quiet "$FMR11_CANDIDATE" "$FMR11_CLOSEOUT" -- src; then
  fail 'F-MR11 closeout changed production source after candidate'
fi
git worktree add --detach "$FMR_WORKTREE" "$FMR11_CANDIDATE" >/dev/null

check_blob "$FMR_WORKTREE" src/adapter/mod_reference_richards_legacy_binding.f90 db432cac3f1156a179c636435a25f52cdececffc
check_blob "$FMR_WORKTREE" src/legacy/b1_10_port/headcalc.f90 d92f77963329d61ab3feb988f912252c0161436c
check_blob "$FMR_WORKTREE" src/solver/mod_reference_richards_workspace.f90 a09ba3457a8ce3685df446bfacbf5220cd401507
check_blob "$FMR_WORKTREE" src/solver/mod_soil_water_solver_contract.f90 4271372085d800fd5da969a2ed073b00422d79c6
check_blob "$FMR_WORKTREE" src/adapter/mod_b110_serialized_context_binding.f90 e21c964eac48d5feb91388cfd06a646c4002a497
check_blob "$FMR_WORKTREE" src/runtime/mod_fmr_serialized_reference_backend.f90 6f39d60a87c1987ae95d7faec2f55f865af90a08
check_blob "$FMR_WORKTREE" src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f
check_blob "$FMR_WORKTREE" src/runtime/mod_fmr_checkpoint_orchestrator.f90 232875e7192f995930c102609cee08dc8938c86a
echo 'FGC02_IMMUTABLE_FMR11_CANDIDATE PASS'

python3 - "$FMR_WORKTREE/tests/fsi/fsi04_real_headcalc_stubs.f90" "$RESPONSE_STUB" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
old='''subroutine tridag(n, upper, main, lower, rhs, solution, ierror)
  implicit none
  integer, intent(in) :: n
  real(8), intent(in) :: upper(*), main(*), lower(*), rhs(*)
  real(8), intent(out) :: solution(*)
  integer, intent(out) :: ierror
  integer :: i
  if (n <= 0 .or. upper(1) > huge(upper(1)) .or. main(1) > huge(main(1)) .or. &
      lower(1) > huge(lower(1)) .or. rhs(1) > huge(rhs(1))) error stop 'invalid tridag arguments'
  do i = 1, n
    solution(i) = 0.0d0
  end do
  ierror = 0
end subroutine tridag
'''
new='''subroutine tridag(n, upper, main, lower, rhs, solution, ierror)
  implicit none
  integer, intent(in) :: n
  real(8), intent(in) :: upper(*), main(*), lower(*), rhs(*)
  real(8), intent(out) :: solution(*)
  integer, intent(out) :: ierror
  integer :: i, j
  real(8) :: beta, gamma(n)
  ierror = 0
  if (n <= 0) then
    ierror = 1
    return
  end if
  beta = main(1)
  if (abs(beta) <= tiny(1.0d0)) then
    ierror = 1
    do j = 1, n
      solution(j) = 0.0d0
    end do
    return
  end if
  gamma(1) = 0.0d0
  solution(1) = rhs(1)/beta
  do i = 2, n
    gamma(i) = lower(i-1)/beta
    beta = main(i) - upper(i)*gamma(i)
    if (abs(beta) <= tiny(1.0d0)) then
      ierror = 1
      do j = 1, n
        solution(j) = 0.0d0
      end do
      return
    end if
    solution(i) = (rhs(i) - upper(i)*solution(i-1))/beta
  end do
  do i = n-1, 1, -1
    solution(i) = solution(i) - gamma(i+1)*solution(i+1)
  end do
end subroutine tridag
'''
if src.count(old) != 1:
    raise SystemExit(f'FGC02 TRIDAG stub marker count={src.count(old)}')
Path(sys.argv[2]).write_text(src.replace(old,new,1))
PY

grep -Fq 'gamma(i) = lower(i-1)/beta' "$RESPONSE_STUB"
echo 'FGC02_RESPONSE_CAPABLE_TRIDAG_FIXTURE PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
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
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$RESPONSE_STUB" -o "$OUT/stubs.o"
  objects+=("$OUT/stubs.o")
  for rel in "${MODULE_SRC[@]}"; do
    src="$FMR_WORKTREE/$rel"
    obj="$OUT/$(basename "${rel%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$OUT" -I "$OUT" -c "$DRIVER" -o "$OUT/fgc02.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/fgc02.o" -o "$OUT/fgc02"
  timeout 60s "$OUT/fgc02" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  for marker in \
    'FGC02_FMR11_IMMUTABLE_PHYSICAL_TRIAL=PASS' \
    'FGC02_GW_HEAD_TO_BOTTOM_HEAD_AUTHORITY=PASS' \
    'FGC02_QSWAP_EQUALS_NEGATIVE_QBOT=PASS' \
    'FGC02_ACTION_REACTION_EXACT=PASS' \
    'FGC02_PREDICTOR_NONCOMMIT=PASS' \
    'FGC02_SAME_T0_CORRECTOR=PASS' \
    'FGC02_ACCEPTED_CORRECTOR_SINGLE_COMMIT=PASS' \
    'FGC02_REJECTED_PREDICTOR_NO_MASS_LEDGER=PASS' \
    'FGC02_INTERFACE_MASS_EXACTLY_ONCE=PASS' \
    'FGC02_POSITIVE_NEGATIVE_INTERFACE_SIGNS=PASS' \
    'FGC02_GENERIC_NONMIDNIGHT_WINDOW=PASS' \
    'FGC02_PHYSICAL_COUPLING_DRIVER PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || fail "missing $marker at O$opt"
  done
  echo "FGC02_PHYSICAL_COUPLING_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FGC02_PHYSICAL_COUPLING_O0_O2_IDENTITY=PASS'

PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s "$ROOT/tests/fgc" -p 'test_fgc01_*.py'
echo 'FGC02_FGC01_ORCHESTRATION_REGRESSION=PASS'

cat "$BUILD/o0/output.txt"
echo "FGC02_PHYSICAL_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FGC02_PHYSICAL_COUPLING_GATE PASS'
