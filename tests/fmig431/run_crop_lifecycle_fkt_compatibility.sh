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
# The generated F-WOF38 test fixture is modified only in this temporary
# wrapper. The frozen historical test and original runner remain unchanged.
hook='python3 "$ROOT/tests/fmig431/patch_crop_lifecycle_fwof38_fixture.py" "$BUILD/fwof38_atomic.f90"\\n'
assert s.count('COMMON=(-std=f2008')==1
s=s.replace('COMMON=(-std=f2008',hook+'\nCOMMON=(-std=f2008',1)
Path(sys.argv[2]).write_text(s)
PY
CROP_FKT_ROOT="$ROOT" bash "$BUILD/runner.sh" > "$BUILD/out"
grep -Fq 'FWOF38_ATOMIC_CROP_TRANSACTION_GATE PASS' "$BUILD/out"
grep -Fq 'SW431_CROP_FKT_LIFECYCLE_PERSISTENCE_REPLAY=PASS' "$BUILD/out"
echo 'SW431_CROP_LIFECYCLE_FKT_OWNER_PRESERVATION=PASS'
