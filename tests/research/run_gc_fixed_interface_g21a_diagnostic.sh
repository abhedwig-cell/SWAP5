#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# Reuse the admitted F-GC44 build recipe and keep BUILD/libmf6/libfgc44_swap
# alive in this process. This diagnostic intentionally does not execute the
# general GC research chain because G21 is a preserved falsified gate.
PATCHED_RUNNER="tests/fgc/.g21a-current-source-fgc44-runner.sh"
python3 - <<'PY'
from pathlib import Path
source=Path("tests/fgc/run_fgc44_real_swap_modflow_end_to_end.sh")
target=Path("tests/fgc/.g21a-current-source-fgc44-runner.sh")
text=source.read_text()
root_sink="  src/solver/mod_b110_root_sink_provider.f90\n"
temporal="  src/solver/mod_reference_richards_temporal_indicator.f90\n"
if root_sink not in text or temporal not in text:
    raise SystemExit("G21A dependency-order repair anchors not found")
text=text.replace(root_sink,"",1)
text=text.replace(temporal,root_sink+temporal,1)
target.write_text(text)
PY

source "$PATCHED_RUNNER"
rm -f "$PATCHED_RUNNER"

test -f "$BUILD/bridge/libfgc44_swap.so"
test -f "$BUILD/modflow-bin/libmf6.so"

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g21a_outer2_divergence.py \
  | tee "$BUILD/fgc44-globalization-g21a.txt"

grep -Fq 'GC_FIXED_INTERFACE_G21A_EXECUTION=PASS' "$BUILD/fgc44-globalization-g21a.txt" || {
  echo "GC_FGC44_G21A_FAIL missing diagnostic execution gate" >&2
  exit 1
}
