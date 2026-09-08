#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq26-upward-diag-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FMR11_CLOSEOUT=86924e93ee81f8c246c28e8277b8ade6079ebaa7
V2_BASE=0ff1d0086ae4c397c203fc90f9591608f010fb69

# Diagnostic only. Production and the decisive V2 oracle remain immutable.
git diff --quiet "$FMR11_CLOSEOUT" -- src || {
  echo 'FVQ26_UPDIAG_PRODUCTION_IMMUTABILITY=FAIL' >&2
  git diff --name-only "$FMR11_CLOSEOUT" -- src >&2
  exit 1
}
[[ "$(git rev-parse "$V2_BASE:tests/fvq/test_fvq26_prescribed_bottom_head_runtime_v2.f90")" == \
   "$(git rev-parse HEAD:tests/fvq/test_fvq26_prescribed_bottom_head_runtime_v2.f90)" ]]
echo 'FVQ26_UPDIAG_V2_ORACLE_IMMUTABILITY=PASS'

git show "$V2_BASE:tests/fvq/test_fvq26_prescribed_bottom_head_runtime_v2.f90" > "$BUILD/original.f90"
python3 - "$BUILD/original.f90" "$BUILD/diagnostic.f90" <<'PY'
import sys
from pathlib import Path
src=Path(sys.argv[1]).read_text()
needle="""  obs_up = backend%observation()
  call require(trial_up%completed, 'upward trial completed')
"""
insert="""  obs_up = backend%observation()
  write(*,'(A,I0)') 'FVQ26_UPDIAG_KERNEL_STATUS=', trial_up%status
  write(*,'(A,L1)') 'FVQ26_UPDIAG_COMPLETED=', trial_up%completed
  write(*,'(A,L1)') 'FVQ26_UPDIAG_CANDIDATE_READY=', candidate%ready()
  write(*,'(A,L1)') 'FVQ26_UPDIAG_SOLVER_EXECUTED=', obs_up%solver_executed
  write(*,'(A,I0)') 'FVQ26_UPDIAG_SOLVER_STATUS=', obs_up%solver_status
  write(*,'(A,A)') 'FVQ26_UPDIAG_SOLVER_ROUTE=', trim(obs_up%solver_diagnostics%route)
  write(*,'(A,I0)') 'FVQ26_UPDIAG_NONLINEAR_ITERATIONS=', obs_up%solver_diagnostics%nonlinear_iterations
  write(*,'(A,I0)') 'FVQ26_UPDIAG_INTERNAL_RETRIES=', obs_up%solver_diagnostics%internal_retries
  write(*,'(A,I0)') 'FVQ26_UPDIAG_JACOBIAN_BUILDS=', obs_up%solver_diagnostics%jacobian_builds
  write(*,'(A,I0)') 'FVQ26_UPDIAG_LINEAR_SOLVES=', obs_up%solver_diagnostics%linear_solves
  write(*,'(A,I0)') 'FVQ26_UPDIAG_BACKTRACKING=', obs_up%solver_diagnostics%backtracking_attempts
  write(*,'(A,I0)') 'FVQ26_UPDIAG_ALT_SOLVER=', obs_up%solver_diagnostics%alternative_solver_calls
  write(*,'(A,ES26.17E3)') 'FVQ26_UPDIAG_QBOT=', obs_up%bottom_flux
  write(*,'(A,L1)') 'FVQ26_UPDIAG_EQ_RESIDUAL_AVAILABLE=', obs_up%solver_equation_residual_available
  write(*,'(A,ES26.17E3)') 'FVQ26_UPDIAG_EQ_RESIDUAL=', obs_up%solver_equation_residual
  write(*,'(A,L1)') 'FVQ26_UPDIAG_MASS_COMPLETE=', trial_up%mass%complete
  write(*,'(A,ES26.17E3)') 'FVQ26_UPDIAG_MASS_RESIDUAL=', trial_up%mass%residual
  write(*,'(A,I0)') 'FVQ26_UPDIAG_ATTEMPTS=', trial_diagnostics%attempts
  write(*,'(A,I0)') 'FVQ26_UPDIAG_RETRIES=', trial_diagnostics%retries
  write(*,'(A,I0)') 'FVQ26_UPDIAG_SOLVER_REJECTIONS=', trial_diagnostics%solver_rejections
  write(*,'(A,I0)') 'FVQ26_UPDIAG_TEMPORAL_REJECTIONS=', trial_diagnostics%temporal_rejections
  write(*,'(A,I0)') 'FVQ26_UPDIAG_MASS_REJECTIONS=', trial_diagnostics%mass_rejections
  write(*,'(A,I0)') 'FVQ26_UPDIAG_ADMISSION_REJECTIONS=', trial_diagnostics%admission_rejections
  write(*,'(A,I0)') 'FVQ26_UPDIAG_ACCEPTED_SUBSTEPS=', trial_diagnostics%accepted_substeps
  write(*,'(A)') 'FVQ26_UPDIAG_CAPTURED_BEFORE_DECISIVE_ASSERTION=PASS'
  call require(trial_up%completed, 'upward trial completed')
"""
if src.count(needle) != 1:
    raise SystemExit(f'upward insertion anchor count={src.count(needle)}')
src=src.replace(needle,insert,1)
Path(sys.argv[2]).write_text(src)
print('FVQ26_UPDIAG_SOURCE_TRANSFORM=PASS')
PY

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
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/diagnostic.f90" -o "$OUT/diag.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/diag.o" -o "$OUT/diag"
  set +e
  "$OUT/diag" > "$OUT/output.txt" 2>&1
  rc=$?
  set -e
  [[ $rc -ne 0 ]] || { echo "FVQ26_UPDIAG_EXPECTED_V2_FAILURE_MISSING_O${opt}=FAIL" >&2; exit 1; }
  grep -Fq 'FVQ26_UPDIAG_CAPTURED_BEFORE_DECISIVE_ASSERTION=PASS' "$OUT/output.txt"
  grep -Fq 'FVQ26V2_FAIL upward trial completed' "$OUT/output.txt"
  echo "FVQ26_UPDIAG_EXPECTED_V2_FAILURE_REPRODUCED_O${opt}=PASS"
done

# The diagnostic values themselves must be optimization independent.
grep '^FVQ26_UPDIAG_' "$BUILD/o0/output.txt" > "$BUILD/o0/diag.txt"
grep '^FVQ26_UPDIAG_' "$BUILD/o2/output.txt" > "$BUILD/o2/diag.txt"
cmp "$BUILD/o0/diag.txt" "$BUILD/o2/diag.txt"
echo 'FVQ26_UPDIAG_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/diag.txt"
echo 'FVQ26_UPWARD_TRIAL_DIAGNOSTIC PASS'
