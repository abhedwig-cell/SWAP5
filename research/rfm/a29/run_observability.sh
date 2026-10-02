#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"
BUILD="$(mktemp -d)"
OUTDIR="${1:-$BUILD/result}"
mkdir -p "$OUTDIR"
trap 'rm -rf "$BUILD"' EXIT

python3 - "$OUTDIR" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1]); rows=[]
for p in root.glob("*.txt"):
 for line in p.read_text().splitlines():
  if line.startswith("A29OBS,"): rows.append(line.split(","))
if not rows: raise SystemExit("no A29OBS rows")
for r in rows:
 approx=int(r[3]); policy=int(r[4]); n64,n32,n16,nother=map(int,r[5:9])
 if nother: raise SystemExit(f"unexpected panel count {r}")
 if approx==0 and (policy!=0 or n32 or n16): raise SystemExit(f"exact provenance/count failure {r}")
 if approx==1 and (policy==0 or n32<=0): raise SystemExit(f"approx provenance/occupancy failure {r}")
print("A29_OBSERVABILITY=PASS")
PY
