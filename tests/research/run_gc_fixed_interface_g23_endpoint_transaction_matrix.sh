#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# Build and execute the ordinary committed F-GC44 source graph in this shell.
# Because the runner is sourced, its BUILD directory remains available until
# this outer G23 process exits. No G21L/M/N research instrumentation is present.
source tests/fgc/run_fgc44_real_swap_modflow_end_to_end.sh

test -f "$BUILD/modflow-bin/libmf6.so" || {
  echo "GC_FGC44_G23_FAIL missing clean libmf6" >&2
  exit 1
}
test -f "$BUILD/bridge/libfgc44_swap.so" || {
  echo "GC_FGC44_G23_FAIL missing clean standard FGC44 library" >&2
  exit 1
}
if nm -D "$BUILD/bridge/libfgc44_swap.so" | grep -q 'gc_g21m_snapshot_c'; then
  echo "GC_FGC44_G23_FAIL research residual observer leaked into clean G23 build" >&2
  exit 1
fi
echo 'GC_FIXED_INTERFACE_G23_STANDARD_SOURCE_BUILD=PASS'

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g23_endpoint_transaction_matrix.py \
  | tee "$BUILD/fgc44-g23-endpoint-transaction-matrix.txt"

grep -Fq 'GC_FIXED_INTERFACE_G23_EXECUTION=PASS' "$BUILD/fgc44-g23-endpoint-transaction-matrix.txt" || {
  echo "GC_FGC44_G23_FAIL missing endpoint transaction matrix gate" >&2
  exit 1
}

# G24 causal diagnostic: vary only MODFLOW convergence scales on the two
# G23 GW_MIXED failures and matched passing controls. G23 remains partial.
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g24_dvclose_compatibility.py \
  | tee "$BUILD/fgc44-g24-dvclose-compatibility.txt"

grep -Fq 'GC_FIXED_INTERFACE_G24_EXECUTION=PASS' "$BUILD/fgc44-g24-dvclose-compatibility.txt" || {
  echo "GC_FGC44_G24_FAIL missing dvclose compatibility execution gate" >&2
  exit 1
}
