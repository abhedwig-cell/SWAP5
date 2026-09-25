#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-h04c-paired-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PARENT=fb22094821b23a8c69fabb745078dcdfde4143cb
SOURCE=tests/fpe/run_fpe_zero_waste01_paired_runtime.sh
TARGET="$BUILD/run_h04c_paired.sh"

python3 - "$SOURCE" "$TARGET" "$PARENT" "$ROOT" <<'PY'
from pathlib import Path
import sys
source,target,parent,root=sys.argv[1:]
s=Path(source).read_text(encoding='utf-8')
s=s.replace('ROOT="$(cd "$(dirname "$0")/../.." && pwd)"', f'ROOT="{root}"', 1)
s=s.replace('BASELINE_COMMIT=82d9938976fd92ff3230e7739539e467c3243225', f'BASELINE_COMMIT={parent}')
copy_anchor='  src/runtime/mod_fmr_serialized_reference_backend.f90; do'
s=s.replace(copy_anchor, '  src/runtime/mod_fmr_serialized_reference_backend.f90   src/solver/mod_b110_default_mvg_provider.f90; do')
module_anchor='  src/solver/mod_b110_default_mvg_provider.f90\n'
s=s.replace(module_anchor, '  PROVIDER_PLACEHOLDER\n', 1)
case_anchor='      LINEAR_PLACEHOLDER)\n        [[ "$name" == baseline ]] && source="$BUILD/src/mod_reference_linear_solver.f90" || source="src/solver/mod_reference_linear_solver.f90" ;;\n'
insert=case_anchor + '      PROVIDER_PLACEHOLDER)\n        [[ "$name" == baseline ]] && source="$BUILD/src/mod_b110_default_mvg_provider.f90" || source="src/solver/mod_b110_default_mvg_provider.f90" ;;\n'
if case_anchor not in s:
    raise SystemExit('H04C paired harness linear placeholder anchor missing')
s=s.replace(case_anchor,insert,1)
Path(target).write_text(s,encoding='utf-8')
PY
chmod +x "$TARGET"

for mode in reference directional; do
  echo "H04C_PAIRED_MODE=$mode"
  TIMING_MODE="$mode" bash "$TARGET"
done
echo 'FPE_ZERO_WASTE01_H04C_ISOLATED_PAIRED=PASS'
