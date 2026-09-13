#!/usr/bin/env bash
set -euo pipefail

FC=${FC:-gfortran}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT

compile_and_run() {
  local opt=$1
  local out=$2
  rm -f "$BUILD"/*.o "$BUILD"/*.mod "$BUILD"/fsi32_gate
  "$FC" -std=f2008 "$opt" -fcheck=all -J"$BUILD" -I"$BUILD" \
    "$ROOT/src/transaction/mod_transaction_reference.f90" \
    "$ROOT/tests/fsi/test_fsi32_scoped_interface_sensitivity.f90" \
    -o "$BUILD/fsi32_gate"
  "$BUILD/fsi32_gate" | tee "$out"
  grep -Fq 'FSI32_SCOPED_SENSITIVITY_GATE PASS' "$out"
}

compile_and_run -O0 "$BUILD/o0.out"
compile_and_run -O2 "$BUILD/o2.out"
cmp "$BUILD/o0.out" "$BUILD/o2.out"
echo 'FSI32_O0_O2_IDENTITY=PASS'

TX="$ROOT/src/transaction/mod_transaction_reference.f90"
RT="$ROOT/src/runtime/mod_canonical_interval_runtime.f90"
KT="$ROOT/src/kernel/mod_kernel_transactions.f90"
PC="$ROOT/src/runtime/mod_groundwater_predictor_corrector_window.f90"

# The transaction/public semantic is explicitly local-terminal. Origin coverage
# is separate metadata and must never be an implicit whole-window upgrade.
grep -Fq 'TX_INTERFACE_SENSITIVITY_LOCAL_TERMINAL = 1' "$TX"
grep -Fq 'published%semantic = TX_INTERFACE_SENSITIVITY_LOCAL_TERMINAL' "$TX"
grep -Fq 'published%covers_requested_interval = origin_t0 == requested_t0 .and. origin_t1 == requested_t1' "$TX"

grep -Fq 'result%interface_sensitivity = terminal_sensitivity' "$RT"
grep -Fq 'result%mass%accepted_transaction_count == 1' "$RT"
grep -Fq 'result%interface_sensitivity = runtime_result%interface_sensitivity' "$KT"

# Current F-CI56 predictor-corrector has no sensitivity consumer. A future
# consumer requires a separate qualified composition and may not infer a whole-
# window derivative from origin coverage alone.
if grep -Fq 'interface_sensitivity' "$PC"; then
  echo 'FSI32 unexpected current predictor-corrector sensitivity consumer' >&2
  exit 1
fi

# There is intentionally no production whole-window derivative classification
# in the current transaction/runtime/kernel contract.
if grep -Eq 'WHOLE_WINDOW.*SENSITIVITY|SENSITIVITY.*WHOLE_WINDOW' "$TX" "$RT" "$KT"; then
  echo 'FSI32 unexpected whole-window sensitivity classification already present' >&2
  exit 1
fi

echo 'FSI32_LOCAL_TERMINAL_CLASSIFICATION=PASS'
echo 'FSI32_ORIGIN_COVERAGE_ORTHOGONALITY=PASS'
echo 'FSI32_KERNEL_TRANSPORT_PRESERVATION=PASS'
echo 'FSI32_FCI56_NONCONSUMPTION=PASS'
echo 'FSI32_NO_WHOLE_WINDOW_RELABEL=PASS'
