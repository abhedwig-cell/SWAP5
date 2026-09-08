#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr09-diag-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

# Instrument only a temporary build copy. The production backend on the branch
# remains byte-for-byte unchanged while this diagnostic is running.
DIAG_BACKEND="$BUILD/mod_fmr_serialized_reference_backend_diag.f90"
python3 - "$DIAG_BACKEND" <<'PY'
from pathlib import Path
import sys
s = Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
s = s.replace(
"    self%forcing_admitted = .false.\n    self%last_observation = fmr_serialized_physical_observation_t()",
"    self%forcing_admitted = .false.\n    self%last_observation = fmr_serialized_physical_observation_t()\n    write(*,'(A,1X,L1,1X,L1)') 'FMR09_TRACE_PREP_START=', self%root_extraction_active, associated(self%soil_parameters)", 1)
s = s.replace(
"      if (any(.not. ieee_is_finite(forcing%root_extraction_sink))) return\n      if (self%root_extraction_active) then",
"      write(*,'(A,1X,L1,1X,ES24.16,1X,ES24.16)') 'FMR09_TRACE_PREP_QROT=', self%root_extraction_active, &\n           minval(forcing%root_extraction_sink), maxval(forcing%root_extraction_sink)\n      if (any(.not. ieee_is_finite(forcing%root_extraction_sink))) return\n      if (self%root_extraction_active) then", 1)
s = s.replace(
"      self%forcing_admitted = .true.\n    class default",
"      self%forcing_admitted = .true.\n      write(*,'(A)') 'FMR09_TRACE_PREP_ADMITTED'\n    class default", 1)
s = s.replace(
"    snow_event_applied_this_call = .false.\n    if (.not. self%forcing_admitted",
"    snow_event_applied_this_call = .false.\n    write(*,'(A,1X,L1,1X,L1,1X,L1,1X,L1,1X,L1,1X,L1)') 'FMR09_TRACE_ADVANCE_FLAGS=', &\n         self%forcing_admitted, associated(self%soil_parameters), associated(self%constitutive), &\n         associated(self%source_sink), associated(self%root_sink), associated(self%top_boundary)\n    if (.not. self%forcing_admitted", 1)
s = s.replace(
"    if (self%root_extraction_active) request%evaluation%root_sink => self%root_sink\n    request%evaluation%top_boundary => self%top_boundary",
"    if (self%root_extraction_active) request%evaluation%root_sink => self%root_sink\n    write(*,'(A,1X,L1,1X,L1,1X,ES24.16,1X,ES24.16)') 'FMR09_TRACE_REQUEST=', &\n         self%root_extraction_active, associated(request%evaluation%root_sink), sum(self%qssdi), sum(self%qrot)\n    request%evaluation%top_boundary => self%top_boundary", 1)
s = s.replace(
"    call bind_b110_serialized_legacy_context(request, context_ok)\n    if (.not. context_ok) return\n    call self%solver%solve",
"    write(*,'(A)') 'FMR09_TRACE_STATE_BOUND'\n    call bind_b110_serialized_legacy_context(request, context_ok)\n    write(*,'(A,1X,L1)') 'FMR09_TRACE_CONTEXT_OK=', context_ok\n    if (.not. context_ok) return\n    write(*,'(A)') 'FMR09_TRACE_BEFORE_SOLVER'\n    call self%solver%solve", 1)
Path(sys.argv[1]).write_text(s)
PY

grep -Fq 'FMR09_TRACE_PREP_START=' "$DIAG_BACKEND"
grep -Fq 'FMR09_TRACE_CONTEXT_OK=' "$DIAG_BACKEND"

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
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  "$DIAG_BACKEND"
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

OUT="$BUILD/o0"
mkdir -p "$OUT"
objects=()
for src in "${MODULE_SRC[@]}"; do
  obj="$OUT/$(basename "${src%.*}").o"
  gfortran "${COMMON[@]}" -O0 -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
  objects+=("$obj")
done

gfortran "${COMMON[@]}" -O0 -J "$OUT" -I "$OUT" \
  -c tests/fmr/test_fmr09_root_sink_transaction_diag.f90 -o "$OUT/diag.o"
gfortran -O0 "${objects[@]}" "$OUT/diag.o" -o "$OUT/diag"
"$OUT/diag" | tee "$OUT/output.txt"
grep -Fq 'FMR09_ROOT_TRANSACTION_DIAGNOSTIC COMPLETE' "$OUT/output.txt"

echo 'FMR09_ROOT_TRANSACTION_DIAGNOSTIC_RUN PASS'
