#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci21-materialization-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=ed0219402072f121856d82cb6068ab74c70f34d1
SOURCE_COMMIT=a0331164a8dfc2642becdbe96cab969eabead392
SOURCE_TREE=7dc94493d44952ad032c02c1d039bc4df0aa8e3f

fail() { echo "FCI21_TEMPORAL_MATERIALIZATION_FAIL $*" >&2; exit 1; }

git cat-file -e "$BASE^{commit}" || fail "WOF42 base missing"
git cat-file -e "$SOURCE_COMMIT^{commit}" || fail "materialized source commit missing"
[[ "$(git rev-parse "$SOURCE_COMMIT^{tree}")" == "$SOURCE_TREE" ]] || fail "materialized source tree drift"
git merge-base --is-ancestor "$BASE" HEAD || fail "branch no longer descends from exact WOF42 base"
git merge-base --is-ancestor "$SOURCE_COMMIT" HEAD || fail "persisted materialized source no longer ancestor of tested head"

check_blob() {
  local path="$1" expected="$2"
  local got
  got="$(git rev-parse "HEAD:$path")" || fail "missing production path $path"
  [[ "$got" == "$expected" ]] || fail "blob drift $path expected=$expected got=$got"
}

check_blob src/solver/mod_soil_water_solver_contract.f90 dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0
check_blob src/solver/mod_fixed_flux_top_boundary_provider.f90 fb226f133bd48d8ab945f111c76897aeff49facf
check_blob src/solver/mod_reference_richards_temporal_indicator.f90 fe8f87d11257d4c6bc019f1d628ac41ba3106d4e
check_blob src/adapter/mod_reference_richards_legacy_binding.f90 6eda1fec1bd03c03a1c0a8f2df29a273f70d962f
check_blob src/transaction/mod_fkt_temporal_indicator_history.f90 78884becbfa2fdaba74726608f9e37a303ae4c58
check_blob src/runtime/mod_fmr_runtime_core.f90 adc2b7514cc062c0cde4e71582ba8ed7776a7335
check_blob src/runtime/mod_canonical_contracts.f90 c06aa869a0bd479df4c7d6e1d0b4f5c07a207144
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 9af5a494526810324dc00706b444e448e770cba9

# Explicit non-delta locks. F-CI21 materialization must not rewrite the kernel,
# generic transaction carrier, canonical interval runtime, or source-equivalent providers.
check_blob src/kernel/mod_kernel_transactions.f90 f1acff10dd99c308a00f434440d6a9ef14632f0d
check_blob src/kernel/mod_kernel_committed_persistence.f90 ffd886c3401fc12739a456fe60a8741c12b9848b
check_blob src/transaction/mod_transaction_reference.f90 2fd932b74dbd0ffc0ec089f49e632b7ac8852df4
check_blob src/runtime/mod_canonical_interval_runtime.f90 55f3d271aa6200a994fd0144d6fce0701c918a74
check_blob src/solver/mod_b110_default_mvg_provider.f90 97d67eb373073b183be6d1bf5b756ecb5125dde2
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac
check_blob src/solver/mod_reference_richards_state_binding.f90 e68d88382c6502c571713cc97fddd4e18434e271

echo 'FCI21_SOURCE_BLOB_LOCK=PASS'

python3 - <<'PY'
from pathlib import Path

core = Path('src/runtime/mod_fmr_runtime_core.f90').read_text().lower()
contract = Path('src/solver/mod_soil_water_solver_contract.f90').read_text().lower()
backend = Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text().lower()
config = Path('src/runtime/mod_canonical_contracts.f90').read_text().lower()
history = Path('src/transaction/mod_fkt_temporal_indicator_history.f90').read_text().lower()
indicator = Path('src/solver/mod_reference_richards_temporal_indicator.f90').read_text().lower()

assert 'numerical_continuation_layout_id' in core
assert 'optional_state_layout_id' in core
assert 'fmr_numerical_continuation_richards_temporal_history' in core
assert 'evaluate_temporal_indicator => soil_water_temporal_indicator_unavailable' in contract
assert 'sw_temporal_indicator_unavailable' in contract
assert 'fkt_temporal_indicator_history_t' in history
assert 'previous_right_derivative' in history
assert 'model_temporal_indicator_budget_available' in config
assert 'model_temporal_indicator_budget' in config
assert 'self%temporal_indicator_budget = config%model_temporal_indicator_budget' in backend
assert 'ieee_is_finite(self%temporal_indicator_budget)' in backend
assert 'self%temporal_indicator_budget > 0.0_real64' in backend
assert 'self%last_observation%temporal_head_budget = self%temporal_indicator_budget' in backend
assert 'indicator_result%head_inf_bound / self%temporal_indicator_budget' in backend
assert 'call self%solver%evaluate_temporal_indicator' in backend
assert 'call reference_tridag' in indicator
assert indicator.count('call reference_tridag') == 1
assert 'dfdh' not in indicator
assert 'old_head' not in indicator
assert 'delta_head' not in indicator
print('FCI21_TEMPORAL_ARCHITECTURE_SOURCE_GUARD=PASS')
PY

# Only the frozen eight production surfaces may differ from the WOF42 base.
allowed='^(src/solver/mod_soil_water_solver_contract\.f90|src/solver/mod_fixed_flux_top_boundary_provider\.f90|src/solver/mod_reference_richards_temporal_indicator\.f90|src/adapter/mod_reference_richards_legacy_binding\.f90|src/transaction/mod_fkt_temporal_indicator_history\.f90|src/runtime/mod_fmr_runtime_core\.f90|src/runtime/mod_canonical_contracts\.f90|src/runtime/mod_fmr_serialized_reference_backend\.f90)$'
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  if [[ "$path" == src/* ]] && ! [[ "$path" =~ $allowed ]]; then
    fail "unexpected production source delta relative to WOF42: $path"
  fi
done < <(git diff --name-only "$BASE" HEAD)
echo 'FCI21_PRODUCTION_SCOPE_GUARD=PASS'

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
    [[ -f "$src" ]] || fail "compile dependency missing: $src"
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
  done
  echo "FCI21_TEMPORAL_COMPILE_O${opt}=PASS"
done

echo 'FCI21_TEMPORAL_MATERIALIZATION_GATE PASS'
