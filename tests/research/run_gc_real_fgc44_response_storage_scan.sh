#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# Reuse the admitted F-GC44 build/e2e recipe, but repair only current-source
# compile ordering in a temporary research copy. The historical runner itself
# remains untouched. Current mod_reference_richards_temporal_indicator imports
# mod_b110_root_sink_provider, so the provider must precede it.
PATCHED_RUNNER="tests/fgc/.dsw22-current-source-fgc44-runner.sh"
python3 - <<'PY'
from pathlib import Path
source = Path("tests/fgc/run_fgc44_real_swap_modflow_end_to_end.sh")
target = Path("tests/fgc/.dsw22-current-source-fgc44-runner.sh")
text = source.read_text()
root_sink = "  src/solver/mod_b110_root_sink_provider.f90\n"
temporal = "  src/solver/mod_reference_richards_temporal_indicator.f90\n"
if root_sink not in text or temporal not in text:
    raise SystemExit("DSW22 dependency-order repair anchors not found")
text = text.replace(root_sink, "", 1)
text = text.replace(temporal, root_sink + temporal, 1)
target.write_text(text)
PY

# Sourcing deliberately keeps BUILD and libfgc44_swap.so alive until this
# outer research runner exits. It still executes the complete F-GC44 e2e gate.
source "$PATCHED_RUNNER"
rm -f "$PATCHED_RUNNER"

test -f "$BUILD/bridge/libfgc44_swap.so" || {
  echo "GC_DSW22_FAIL missing reused F-GC44 bridge library" >&2
  exit 1
}

FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_real_fgc44_response_storage_scan.py | tee "$BUILD/dsw22-semantic-scan.txt"

grep -Fq 'GC_DSW22_LIVE_GATE=PASS' "$BUILD/dsw22-semantic-scan.txt" || {
  echo "GC_DSW22_FAIL missing live gate" >&2
  exit 1
}

echo 'GC_DSW22_REAL_SWAP_SEMANTIC_SCAN=PASS'
