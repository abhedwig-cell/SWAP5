#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq26-hcdiag-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FMR11_CLOSEOUT=86924e93ee81f8c246c28e8277b8ade6079ebaa7
V2_BASE=0ff1d0086ae4c397c203fc90f9591608f010fb69

git diff --quiet "$FMR11_CLOSEOUT" -- src || { echo 'FVQ26_HCDIAG_PRODUCTION_IMMUTABILITY=FAIL' >&2; exit 1; }
git show "$V2_BASE:src/legacy/b1_10_port/headcalc.f90" > "$BUILD/headcalc.f90"
python3 - "$BUILD/headcalc.f90" "$BUILD/headcalc_diag.f90" <<'PY'
import sys
from pathlib import Path
s=Path(sys.argv[1]).read_text()
needle="""!  calculate vector fsi_ws%residual (first time)
   fsi_ws%residual = 0.0d0
   call vector_F(1)

!  initial estimate of fsi_ws%residual inner product
"""
insert="""!  calculate vector fsi_ws%residual (first time)
   fsi_ws%residual = 0.0d0
   call vector_F(1)
   if (swbotb == 5 .and. state%qtop > 0.0d0) then
      write(*,'(A,ES26.17E3)') 'FVQ26_HCDIAG_DT=', dt
      write(*,'(A,ES26.17E3)') 'FVQ26_HCDIAG_QTOP=', state%qtop
      write(*,'(A,ES26.17E3)') 'FVQ26_HCDIAG_HBOT=', state%hbot
      write(*,'(A,4(1X,ES26.17E3))') 'FVQ26_HCDIAG_H=', state%h(1:NN)
      write(*,'(A,4(1X,ES26.17E3))') 'FVQ26_HCDIAG_THETA=', state%theta(1:NN)
      write(*,'(A,5(1X,ES26.17E3))') 'FVQ26_HCDIAG_KMEAN=', state%kmean(1:NN+1)
      write(*,'(A,4(1X,ES26.17E3))') 'FVQ26_HCDIAG_GRAD=', fsi_ws%head_gradient(1:NN+1)
      write(*,'(A,4(1X,ES26.17E3))') 'FVQ26_HCDIAG_SOURCE=', fsi_ws%source(1:NN)
      write(*,'(A,4(1X,ES26.17E3))') 'FVQ26_HCDIAG_SINK=', fsi_ws%sink(1:NN)
      write(*,'(A,4(1X,ES26.17E3))') 'FVQ26_HCDIAG_ROOT=', fsi_ws%provider_root_sink(1:NN)
      write(*,'(A,4(1X,ES26.17E3))') 'FVQ26_HCDIAG_RESIDUAL=', fsi_ws%residual(1:NN)
      write(*,'(A,ES26.17E3)') 'FVQ26_HCDIAG_SUMRES=', sum(fsi_ws%residual(1:NN))
      write(*,'(A,ES26.17E3)') 'FVQ26_HCDIAG_MAXABSRES=', maxval(abs(fsi_ws%residual(1:NN)))
      write(*,'(A)') 'FVQ26_HCDIAG_INITIAL_RESIDUAL_CAPTURE=PASS'
   end if

!  initial estimate of fsi_ws%residual inner product
"""
if s.count(needle)!=1:
    raise SystemExit(f'HeadCalc anchor count={s.count(needle)}')
Path(sys.argv[2]).write_text(s.replace(needle,insert,1))
print('FVQ26_HCDIAG_SOURCE_TRANSFORM=PASS')
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
)
TAIL_SRC=(
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
    obj="$OUT/$(basename "${src%.*}").o"; gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"; objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/headcalc_diag.f90" -o "$OUT/headcalc.o"; objects+=("$OUT/headcalc.o")
  for src in "${TAIL_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"; gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"; objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fvq/test_fvq26_prescribed_bottom_head_runtime_v2.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  set +e
  "$OUT/test" > "$OUT/output.txt" 2>&1
  rc=$?
  set -e
  [[ $rc -ne 0 ]]
  grep -Fq 'FVQ26_HCDIAG_INITIAL_RESIDUAL_CAPTURE=PASS' "$OUT/output.txt"
  grep -Fq 'FVQ26V2_FAIL upward trial completed' "$OUT/output.txt"
  grep '^FVQ26_HCDIAG_' "$OUT/output.txt" > "$OUT/diag.txt"
  echo "FVQ26_HCDIAG_EXPECTED_FAILURE_CAPTURED_O${opt}=PASS"
done
cmp "$BUILD/o0/diag.txt" "$BUILD/o2/diag.txt"
echo 'FVQ26_HCDIAG_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/diag.txt"
echo 'FVQ26_HEADCALC_INITIAL_RESIDUAL_DIAGNOSTIC PASS'
