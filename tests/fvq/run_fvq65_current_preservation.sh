#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/fvq65-preservation-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail() { echo "FVQ65_PRESERVATION_FAIL:$*" >&2; exit 1; }
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

# 1. Solver-service/reference-model composition. The historical F-KT15 fixture
# is frozen input only; it is rebuilt against the F-KT18 candidate production source.
FKT15=48336cb7f14e9246b03c23e549fe7354a93f9e6b
mkdir -p "$BUILD/fkt15"
git show "$FKT15:tests/fkt/fkt15_reference_model_stubs.f90" > "$BUILD/fkt15/stubs.f90"
git show "$FKT15:tests/fkt/test_fkt15_reference_model_transport.f90" > "$BUILD/fkt15/test.f90"
for opt in 0 2; do
  out="$BUILD/fkt15/o$opt"; mkdir -p "$out"; objects=()
  for src in src/transaction/mod_transaction_reference.f90 src/runtime/mod_a23bu_worker_execution_context.f90 \
    src/solver/mod_soil_water_solver_contract.f90 "$BUILD/fkt15/stubs.f90" \
    src/adapter/mod_soil_water_transaction_result_bridge.f90 src/adapter/mod_b1_10_reference_model.f90 "$BUILD/fkt15/test.f90"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" "${objects[@]}" -o "$out/test"
  "$out/test" > "$out/output.txt"
  grep -Fq 'FKT15_REFERENCE_MODEL_TRANSPORT_GATE=PASS' "$out/output.txt" || fail "solver-service O$opt"
done
cmp "$BUILD/fkt15/o0/output.txt" "$BUILD/fkt15/o2/output.txt" || fail 'solver-service O0/O2 identity'
echo 'FVQ65_SOLVER_SERVICE_REFERENCE_MODEL_PRESERVED=PASS'

# 2. Current restart + serialized MultiSWAP continuation through production code.
RESTART_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/kernel/mod_kernel_committed_persistence.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/runtime/mod_fmr_restart_state_contract.f90
  src/runtime/mod_fmr_committed_restart.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)
for opt in 0 2; do
  out="$BUILD/restart/o$opt"; mkdir -p "$out"; objects=()
  for src in "${RESTART_SRC[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c tests/fmr/test_fmr19_process_restart.f90 -o "$out/test.o"
  gfortran -O"$opt" "${objects[@]}" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/output.txt" 2>&1 || { cat "$out/output.txt" >&2; fail "restart O$opt"; }
  grep -Fq 'FMR19_EXACT_INTERVAL_MASS_CONTINUATION=PASS' "$out/output.txt" || fail "restart mass O$opt"
  grep -Fq 'FMR19_CONTINUOUS_VS_RESTARTED_ENDPOINT_IDENTITY=PASS' "$out/output.txt" || fail "restart endpoint O$opt"
  grep -Fq 'FMR19_REAL_HEADCALC_PROCESS_RESTART_TEST PASS' "$out/output.txt" || fail "restart final O$opt"
done
cmp "$BUILD/restart/o0/output.txt" "$BUILD/restart/o2/output.txt" || fail 'restart O0/O2 identity'
echo 'FVQ65_RESTART_SERIALIZED_MULTISWAP_PRESERVED=PASS'

# 3. Production parallel runtime against immutable independent FMQ attack blobs.
MATRIX_BLOB=26cc6e0ace986dc40db7635de7192958a1c0b868
ORDER_BLOB=f2584b0236e85d4f6e8b687cee97981eaaa909c9
git cat-file blob "$MATRIX_BLOB" > "$BUILD/parallel_matrix.f90"
git cat-file blob "$ORDER_BLOB" > "$BUILD/publication_order.f90"
PAR_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/runtime/mod_fmr_parallel_physical_scheduler.f90
  src/runtime/mod_fmr_parallel_worker_pool.f90
)
export OMP_DYNAMIC=FALSE OMP_THREAD_LIMIT=4 OMP_PROC_BIND=spread OMP_PLACES=cores
for opt in 0 2; do
  out="$BUILD/parallel/o$opt"; mkdir -p "$out"; objects=()
  for src in "${PAR_SRC[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -fopenmp -O"$opt" -J"$out" -I"$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -fopenmp -O"$opt" -J"$out" -I"$out" -c "$BUILD/parallel_matrix.f90" -o "$out/matrix.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$out/matrix.o" -o "$out/matrix"
  "$out/matrix" > "$out/matrix.txt" 2>&1 || { cat "$out/matrix.txt" >&2; fail "parallel matrix O$opt"; }
  grep -Fq 'FMQ26_HARD_MASS_ALL_CASES=PASS' "$out/matrix.txt" || fail "parallel hard mass O$opt"
  grep -Fq 'FMQ26_TRUE_MULTIWORKER_OVERLAP_CONTROL=PASS' "$out/matrix.txt" || fail "parallel overlap O$opt"
  grep -Fq 'FMQ26_PARALLEL_V1_ADMISSION_TEST PASS' "$out/matrix.txt" || fail "parallel final O$opt"
  gfortran "${COMMON[@]}" -fopenmp -O"$opt" -J"$out" -I"$out" -c "$BUILD/publication_order.f90" -o "$out/order.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$out/order.o" -o "$out/order"
  "$out/order" > "$out/order.txt" 2>&1 || { cat "$out/order.txt" >&2; fail "parallel order O$opt"; }
  grep -Fq 'FMQ26_CANONICAL_PUBLICATION_ORDER=PASS' "$out/order.txt" || fail "parallel publication O$opt"
done
cmp "$BUILD/parallel/o0/matrix.txt" "$BUILD/parallel/o2/matrix.txt" || fail 'parallel matrix O0/O2 identity'
cmp "$BUILD/parallel/o0/order.txt" "$BUILD/parallel/o2/order.txt" || fail 'parallel publication O0/O2 identity'
echo 'FVQ65_PRODUCTION_PARALLEL_RUNTIME_PRESERVED=PASS'

# 4. Independently qualified restricted predictor/corrector sequence replay.
OWNER=1da854e4dd2d45fe388ee2a1ef3bd67c76d3d73f
FVQ64=466119889a3f09b33ede638322e897bded2472a3
mkdir -p "$BUILD/coupling"
python3 - "$OWNER" "$BUILD/coupling/fixture.f90" <<'PY'
from pathlib import Path
import subprocess,sys
owner=sys.argv[1]; out=Path(sys.argv[2])
text=subprocess.check_output(['git','show',f'{owner}:tests/fgc/test_fgc21_restricted_predictor_corrector_window.f90'],text=True)
marker='\nprogram test_fgc21_restricted_predictor_corrector_window\n'
assert text.count(marker)==1
out.write_text(text.split(marker,1)[0]+'\n')
PY
git show "$FVQ64:tests/fvq/test_fvq64_fgc21_independent_sequences.f90" > "$BUILD/coupling/independent.f90"
COUPLING_SRC=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_coupling_policy.f90
  src/runtime/mod_groundwater_exchange_service_contract.f90
  src/runtime/mod_groundwater_interface_mass_ledger.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_predictor_corrector_window.f90
)
CFLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  out="$BUILD/coupling/o$opt"; mkdir -p "$out"
  gfortran "${CFLAGS[@]}" -O"$opt" -J"$out" -I"$out" "${COUPLING_SRC[@]}" \
    "$BUILD/coupling/fixture.f90" "$BUILD/coupling/independent.f90" -o "$out/test"
  "$out/test" > "$out/output.txt" 2>&1 || { cat "$out/output.txt" >&2; fail "coupling O$opt"; }
  grep -Fq 'F-VQ64 INDEPENDENT F-GC21 SEQUENCES PASS' "$out/output.txt" || fail "coupling O$opt final marker"
done
cmp "$BUILD/coupling/o0/output.txt" "$BUILD/coupling/o2/output.txt" || fail 'coupling O0/O2 identity'
echo 'FVQ65_FVQ64_COUPLING_SEMANTICS_PRESERVED=PASS'

echo 'FVQ65_CURRENT_PRESERVATION_GATE=PASS'
