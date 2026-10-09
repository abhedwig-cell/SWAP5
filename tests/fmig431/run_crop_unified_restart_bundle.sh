#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

# Derive only a temporary runner; never rewrite the admitted F-WOF38 gate.
python3 - "$ROOT/tests/fmig431/run_crop_lifecycle_fkt_compatibility.sh" "$BUILD/derived.sh" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
old='ROOT="$(cd "$(dirname "$0")/../.." && pwd)"'
assert s.startswith('#!/usr/bin/env bash\nset -euo pipefail\n'+old+'\n')
s=s.replace(old+'\n','ROOT="${CROP_PAIR_ROOT:?}"\n',1)
old='''"targets = ['mod_fmr_wofost_crop_transaction']"'''
assert s.count(old)==1
s=s.replace(old, '''"targets = ['mod_fmr_crop_physical_calendar_restart_coherence']"''',1)
old='''hook='python3 "$ROOT/tests/fmig431/patch_crop_lifecycle_fwof38_fixture.py" "$BUILD/fwof38_atomic.f90"\\n\''''
assert s.count(old)==1,(old,s.count(old))
new='''hook=('python3 "$ROOT/tests/fmig431/patch_crop_lifecycle_fwof38_fixture.py" "$BUILD/fwof38_atomic.f90"\\n'
      'python3 "$ROOT/tests/fmig431/patch_crop_physical_calendar_restart_fixture.py" "$BUILD/fwof38_atomic.f90"\\n'
      'python3 "$ROOT/tests/fmig431/patch_crop_unified_restart_bundle_fixture.py" "$BUILD/fwof38_atomic.f90"\\n')'''
s=s.replace(old,new,1)
old="grep -Fq 'SW431_CROP_FKT_LIFECYCLE_ACCEPT_RESTART=PASS' \"$BUILD/out\""
assert s.count(old)==1
s=s.replace(old,old+"\ngrep -Fq 'SW431_CROP_PHYSICAL_CALENDAR_RESTART_PAIR=PASS' \"$BUILD/out\"",1)
assert "SW431_CROP_PHYSICAL_CALENDAR_RESTART_PAIR=PASS" in s
s=s.replace("grep -Fq 'SW431_CROP_PHYSICAL_CALENDAR_RESTART_PAIR=PASS' \\"$BUILD/out\\"",
            "grep -Fq 'SW431_CROP_PHYSICAL_CALENDAR_RESTART_PAIR=PASS' \\"$BUILD/out\\"\\ngrep -Fq 'SW431_CROP_UNIFIED_RESTART_BUNDLE_ACCEPT_NEGATIVE=PASS' \\"$BUILD/out\\"",1)
Path(sys.argv[2]).write_text(s)
PY
CROP_PAIR_ROOT="$ROOT" bash "$BUILD/derived.sh"
echo 'SW431_CROP_UNIFIED_RESTART_BUNDLE_O0_O2=PASS'
