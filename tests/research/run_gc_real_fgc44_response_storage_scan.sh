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

# The original DSW22 all-nine-success gate is immutable and was falsified
# in workflow 35564514215 at its first matrix point. Do not rerun it as a
# moving acceptance gate. Characterize the unchanged matrix instead.
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_real_fgc44_response_storage_diagnostic.py | tee "$BUILD/dsw22-diagnostic.txt"

grep -Fq 'GC_DSW22D_DIAGNOSTIC_GATE=PASS' "$BUILD/dsw22-diagnostic.txt" || {
  echo "GC_DSW22D_FAIL missing diagnostic gate" >&2
  exit 1
}

echo 'GC_DSW22_PREREGISTERED_GATE=FALSIFIED_PRESERVED'
echo 'GC_DSW22D_REAL_SWAP_MATRIX_DIAGNOSTIC=PASS'

# G03/G05/G06 fixed-interface globalization qualification. This reuses the
# built real F-GC44 bridge, but every groundwater probe uses a fresh MODFLOW
# prepared solve and every SWAP trial is discarded.
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_fgc44_globalization_g03.py \
  | tee "$BUILD/fgc44-globalization-g03.txt"

grep -Fq 'GC_FIXED_INTERFACE_FGC44_GLOBALIZATION_GATE=PASS' "$BUILD/fgc44-globalization-g03.txt" || {
  echo "GC_FGC44_GLOBALIZATION_FAIL missing G03/G05/G06 gate" >&2
  exit 1
}

# G07A live groundwater-regime sweep around the analytical r=1 and r=3
# transition structure. The real-SWAP response remains diagnostic-only.
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_fgc44_regime_sweep_g07a.py \
  | tee "$BUILD/fgc44-globalization-g07a.txt"

grep -Fq 'GC_FIXED_INTERFACE_FGC44_G07A=PASS' "$BUILD/fgc44-globalization-g07a.txt" || {
  echo "GC_FGC44_G07A_FAIL missing live phase-transition gate" >&2
  exit 1
}


# G08 production-candidate research qualification. This is still diagnostic:
# every SWAP trial is discarded and the accepted origin/ledger must remain
# unchanged. The test re-estimates the physical tangent at each accepted trial
# and compares raw Newton (P1) with factor-1/2 safeguarded Newton (P4).
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_fgc44_safeguarded_newton_g08.py \
  | tee "$BUILD/fgc44-globalization-g08.txt"

grep -Fq 'GC_FIXED_INTERFACE_G08_EXECUTION=PASS' "$BUILD/fgc44-globalization-g08.txt" || {
  echo "GC_FGC44_G08_FAIL missing safeguarded-Newton execution gate" >&2
  exit 1
}


# The preregistered G09 all-boundary estimator gate was falsified in
# workflow 35699061533 at C3_LONG_HIGH positive edge. Preserve that result;
# do not rerun it as a moving acceptance gate.
echo 'GC_FIXED_INTERFACE_G09_FIRST_EXECUTION=FALSIFIED_PRESERVED'

# G09A fixed-scale diagnostic: characterize status topology and derivative
# estimates at the failed C3-positive state and the C2-negative control.
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_fgc44_tangent_topology_g09a.py \
  | tee "$BUILD/fgc44-globalization-g09a.txt"

grep -Fq 'GC_FIXED_INTERFACE_G09A_DIAGNOSTIC=PASS' "$BUILD/fgc44-globalization-g09a.txt" || {
  echo "GC_FGC44_G09A_FAIL missing tangent-topology diagnostic gate" >&2
  exit 1
}


# G09B topology-consistent tangent qualification. Probes may contribute to the
# derivative only when participant status is 0 and raw execution topology
# matches the current center trial.
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
  python3 tests/research/test_gc_fixed_interface_fgc44_topology_tangent_g09b.py \
  | tee "$BUILD/fgc44-globalization-g09b.txt"

grep -Fq 'GC_FIXED_INTERFACE_G09B_EXECUTION=PASS' "$BUILD/fgc44-globalization-g09b.txt" || {
  echo "GC_FGC44_G09B_FAIL missing topology-consistent tangent gate" >&2
  exit 1
}
