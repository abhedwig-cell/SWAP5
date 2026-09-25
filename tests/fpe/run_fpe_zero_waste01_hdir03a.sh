#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-hdir03a-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PARENT=31de53a448cbd048045a95c111682262c4fb9657
SOURCE=tests/fpe/run_fpe_zero_waste01_paired_runtime.sh
TARGET="$BUILD/run_hdir03a_paired.sh"

python3 - "$SOURCE" "$TARGET" "$PARENT" "$ROOT" <<'PY'
from pathlib import Path
import sys
source,target,parent,root=sys.argv[1:]
s=Path(source).read_text(encoding='utf-8')
s=s.replace('ROOT="$(cd "$(dirname "$0")/../.." && pwd)"', f'ROOT="{root}"', 1)
s=s.replace('BASELINE_COMMIT=82d9938976fd92ff3230e7739539e467c3243225', f'BASELINE_COMMIT={parent}')
Path(target).write_text(s,encoding='utf-8')
PY
chmod +x "$TARGET"

TIMING_MODE=directional bash "$TARGET"
echo 'FPE_ZERO_WASTE01_HDIR03A_PAIRED=PASS'
