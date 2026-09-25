#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-h18-paired-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PARENT=f81f57b00681baa39da1befab2569214e71a4cb9
SOURCE=tests/fpe/run_fpe_zero_waste01_paired_runtime.sh
TARGET="$BUILD/run_h18_paired.sh"

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

for mode in reference directional; do
  echo "H18_PAIRED_MODE=$mode"
  TIMING_MODE="$mode" bash "$TARGET"
done
echo 'FPE_ZERO_WASTE01_H18_ISOLATED_PAIRED=PASS'
