#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.."&&pwd)";cd "$ROOT"
OUT="${1:-/tmp/a28-q3}";mkdir -p "$OUT/exact" "$OUT/approx"
bash research/rfm/a27/run_production_abc01.sh "$OUT/exact"
# The ABC executable receives "approx" and therefore opts C into PERF07_V1.
# Build/run is repeated deliberately so exact and approximate outputs are independently persisted.
BUILD="$(mktemp -d)";trap 'rm -rf "$BUILD"' EXIT
# Reuse runner source assembly while changing only invocation by generating a temporary runner.
python3 - "$BUILD/run.sh" "$OUT/approx" <<'PY'
from pathlib import Path
import sys
s=Path("research/rfm/a27/run_production_abc01.sh").read_text()
s=s.replace('"$B/abc" > "$OUTDIR/abc_o$opt.txt"','"$B/abc" approx > "$OUTDIR/abc_o$opt.txt"')
Path(sys.argv[1]).write_text(s)
PY
bash "$BUILD/run.sh" "$OUT/approx"
python3 research/rfm/a28/compare_q3.py "$OUT/exact/abc_o2.txt" "$OUT/approx/abc_o2.txt" "$OUT"
