#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-hdir05-paired-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PARENT=00018c52d8ddc0aa5f6e831e1c07dc676c4b2402
SOURCE=tests/fpe/run_fpe_zero_waste01_paired_runtime.sh
TARGET="$BUILD/run_hdir05_paired.sh"

python3 - "$SOURCE" "$TARGET" "$PARENT" "$ROOT" <<'PY'
from pathlib import Path
import sys
source,target,parent,root=sys.argv[1:]
s=Path(source).read_text(encoding='utf-8')
s=s.replace('ROOT="$(cd "$(dirname "$0")/../.." && pwd)"', f'ROOT="{root}"', 1)
s=s.replace('BASELINE_COMMIT=82d9938976fd92ff3230e7739539e467c3243225', f'BASELINE_COMMIT={parent}')

copy_anchor='  src/runtime/mod_fmr_serialized_reference_backend.f90; do'
replacement='  src/runtime/mod_fmr_serialized_reference_backend.f90   src/solver/mod_b110_default_mvg_directional_provider.f90; do'
if copy_anchor not in s:
    raise SystemExit('HDIR05 paired copy anchor missing')
s=s.replace(copy_anchor,replacement,1)

module_anchor='  src/solver/mod_b110_default_mvg_directional_provider.f90\n'
if module_anchor not in s:
    raise SystemExit('HDIR05 paired directional provider module anchor missing')
s=s.replace(module_anchor,'  DIRECTIONAL_PROVIDER_PLACEHOLDER\n',1)

case_anchor='      DIRECTIONAL_PLACEHOLDER)\n        [[ "$name" == baseline ]] && source="$BUILD/src/mod_reference_richards_accepted_step_directional_service.f90" || source="src/adapter/mod_reference_richards_accepted_step_directional_service.f90" ;;\n'
if case_anchor not in s:
    raise SystemExit('HDIR05 paired directional placeholder anchor missing')
insert=case_anchor + '      DIRECTIONAL_PROVIDER_PLACEHOLDER)\n        [[ "$name" == baseline ]] && source="$BUILD/src/mod_b110_default_mvg_directional_provider.f90" || source="src/solver/mod_b110_default_mvg_directional_provider.f90" ;;\n'
s=s.replace(case_anchor,insert,1)
Path(target).write_text(s,encoding='utf-8')
PY
chmod +x "$TARGET"

TIMING_MODE=directional bash "$TARGET"
echo 'FPE_ZERO_WASTE01_HDIR05_ISOLATED_PAIRED=PASS'
