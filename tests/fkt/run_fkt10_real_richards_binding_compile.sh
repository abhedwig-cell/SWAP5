#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fkt10-real-binding-compile-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
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
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
  done
  echo "FKT10_REAL_RICHARDS_BINDING_COMPILE_O${opt}=PASS"
done

python3 - <<'PY'
from pathlib import Path
core=Path('src/runtime/mod_fmr_runtime_core.f90').read_text().lower()
backend=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text().lower()
assert 'numerical_continuation_layout_id' in core
assert 'fmr_numerical_continuation_richards_temporal_history' in core
assert 'select case (template%numerical_continuation_layout_id)' in backend
assert 'select case (template%optional_state_layout_id)' not in backend
assert 'fmr_optional_state_richards_temporal_history' not in backend
assert 'outcome%temporal_certificate_available = .true.' not in backend
assert 'outcome%temporal_indicator = indicator_result%head_inf_bound' not in backend
assert 'call self%solver%evaluate_temporal_indicator' in backend
print('FKT10_GATE_D_LAYOUT_SEPARATION_SOURCE_GUARD=PASS')
print('FKT10_GATE_E_NO_UNQUALIFIED_CERTIFICATE_PROMOTION_SOURCE_GUARD=PASS')
PY

echo 'FKT10_REAL_RICHARDS_BINDING_COMPILE_GATE PASS'
