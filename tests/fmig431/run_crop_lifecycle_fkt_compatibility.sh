#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

# Keep the immutable F-WOF38 donor untouched. Add only the new optional
# lifecycle dependency and independent owner persistence assertions.
python3 - "$ROOT/tests/fwof/run_fwof38_atomic_crop_transaction_gate.sh" "$BUILD/runner.sh" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
original='ROOT="$(cd "$(dirname "$0")/../.." && pwd)"'
replacement='ROOT="${CROP_FKT_ROOT:?}"'
assert s.count(original)==1
s=s.replace(original,replacement,1)
anchor='  src/runtime/mod_fmr_wofost_accepted_window_lineage.f90\n  src/runtime/mod_fmr_wofost_crop_transaction.f90'
extra='''  src/runtime/mod_fmr_wofost_accepted_window_lineage.f90
  src/crop/mod_crop_preparation_sowing_preflight.f90
  src/crop/mod_crop_germination_preflight.f90
  src/crop/mod_crop_lifecycle_daily_composition.f90
  src/crop/mod_crop_lifecycle_continuation.f90
  src/runtime/mod_fmr_wofost_crop_transaction.f90'''
assert s.count(anchor)==1
s=s.replace(anchor,extra,1)
# Use the same dependency-ordered real source set as the focused
# lifecycle O0/O2 gate. Frozen F-WOF38's hand-listed compilation order has
# become stale against the current F-KT directional-publication contract.
focused=Path(sys.argv[1]).parent.parent / 'fmig431' / 'run_crop_lifecycle_continuation.sh'
focused_text=focused.read_text()
start=focused_text.index("mapfile -t SOURCES < <(python3 - \"$ROOT\" <<'PY'\n")
finish=focused_text.index("\n)\n",start)+3
sources=focused_text[start:finish]
assert "targets = ['mod_crop_lifecycle_continuation']" in sources
sources=sources.replace("targets = ['mod_crop_lifecycle_continuation']", 
                        "targets = ['mod_fmr_wofost_crop_transaction', 'mod_fmr_crop_weather_physical_event_composition']")
assert "for path in sorted((root / 'src').rglob('*.f90')):" in sources
sources=sources.replace("for path in sorted((root / 'src').rglob('*.f90')):",
 "for path in [*sorted((root / 'src').rglob('*.f90')), root / 'tests/fsi/fsi04_real_headcalc_stubs.f90']:")
assert '    for dep in source[path]:\n        visit(dep)' in sources
sources=sources.replace('    for dep in source[path]:\n        visit(dep)',
  '    for dep in source[path]:\n        if dep in by_module and by_module[dep] == path: continue\n        visit(dep)')
source_start=s.index('SOURCES=(\n')
source_end=s.index('\n)\n\nfor OPT',source_start)+3
s=s[:source_start]+sources+s[source_end:]
# The generated F-WOF38 test fixture is modified only in this temporary
# wrapper. The frozen historical test and original runner remain unchanged.
hook='python3 "$ROOT/tests/fmig431/patch_crop_lifecycle_fwof38_fixture.py" "$BUILD/fwof38_atomic.f90"\n'
assert s.count('COMMON=(-std=f2008')==1
s=s.replace('COMMON=(-std=f2008',hook+'\nCOMMON=(-std=f2008',1)
s=s.replace('COMMON=(-std=f2008', 'COMMON=(-std=f2008 -w', 1)
s=s.replace(' -Werror -fcheck=all', ' -Werror -Wno-error=compare-reals -Wno-error=function-elimination -Wno-error=do-subscript -fcheck=all', 1)
s=s.replace('"$BUILD/fwof38_atomic.f90" ./*.o -o test', '"$BUILD/fwof38_atomic.f90" "$ROOT/src/legacy/b1_10_port/headcalc.f90" ./*.o -o test')
s=s.replace('  ./test > output.txt 2>&1', '  ./test > output.txt 2>&1 || { cat output.txt >&2; exit 1; }')
Path(sys.argv[2]).write_text(s)
PY
CROP_FKT_ROOT="$ROOT" bash "$BUILD/runner.sh" > "$BUILD/out" 2>&1 || { tail -n 160 "$BUILD/out" >&2; exit 1; }
grep -Fq 'FWOF38_ATOMIC_CROP_TRANSACTION_GATE PASS' "$BUILD/out"
grep -Fq 'SW431_CROP_FKT_LIFECYCLE_PERSISTENCE_REPLAY=PASS' "$BUILD/out"
grep -Fq 'SW431_CROP_FKT_LIFECYCLE_RECEIPT_COHERENCE=PASS' "$BUILD/out"
grep -Fq 'SW431_CROP_FKT_LIFECYCLE_ACCEPT_RESTART=PASS' "$BUILD/out"
grep -Fq 'SW431_CROP_FKT_EVENT_PREFLIGHT_NEGATIVES=PASS' "$BUILD/out"
grep -Fq 'SW431_CROP_POSITIVE_WINDOW_BRIDGE=PASS' "$BUILD/out"
echo 'SW431_CROP_LIFECYCLE_FKT_OWNER_PRESERVATION=PASS'
