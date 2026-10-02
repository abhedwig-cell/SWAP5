#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"
BUILD="$(mktemp -d)"
OUTDIR="${1:-$BUILD/result}"
mkdir -p "$OUTDIR"
trap 'rm -rf "$BUILD"' EXIT

python3 - "$BUILD/grid_stubs.f90" <<'GRID'
from pathlib import Path
import sys
s=Path('tests/fsi/fsi04_real_headcalc_stubs.f90').read_text()
s=s.replace('numnod = 4','numnod = 10')
s=s.replace('[-0.25d0, -0.75d0, -1.50d0, -2.50d0]','['+','.join(str(-5-10*i)+'d0' for i in range(10))+']')
s=s.replace('[0.50d0, 0.50d0, 1.00d0, 1.00d0]','10.0d0')
s=s.replace('disnod(numnod+1) = 1.0d0','disnod(numnod+1) = [5.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,5.0d0]')
Path(sys.argv[1]).write_text(s)
GRID

# Start from the current production backend compile gate's explicitly ordered
# source list. Replace only its legacy fixture with the A27 ten-cell fixture.
mapfile -t MODULE_SRC < <(python3 - "$BUILD/grid_stubs.f90" <<'SOURCES'
from pathlib import Path
import sys
lines=Path('tests/fpm/run_ppa_wu05a26_backend_compile.sh').read_text().splitlines()
inside=False
found=False
for raw in lines:
    stripped=raw.strip()
    if stripped == 'MODULE_SRC=(':
        inside=True
        found=True
        continue
    if inside and stripped == ')':
        break
    if not inside or not stripped:
        continue
    source=stripped
    if source == 'tests/fsi/fsi04_real_headcalc_stubs.f90':
        source=sys.argv[1]
    print(source)
if not found:
    raise SystemExit('A27 ABC01 could not locate current backend compile source list')
SOURCES
)

# Add current backend prerequisites such as Bartholomeus. The production
# augmenter may rediscover the stock fsi04 stub through module lookup; filter
# that one path because grid_stubs.f90 is its complete ten-cell replacement.
mapfile -t MODULE_SRC < <(
  python3 tests/support/augment_bartholomeus_backend_sources.py "${MODULE_SRC[@]}" |
  awk '$0 != "tests/fsi/fsi04_real_headcalc_stubs.f90"'
)

COMMON=(-std=f2008 -ffree-line-length-none -fcheck=all -fbacktrace -g)
for opt in 0 2; do
  B="$BUILD/o$opt"
  mkdir -p "$B"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$B/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J"$B" -I"$B" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J"$B" -I"$B" "${objects[@]}" \
    research/rfm/a29/test_observability.f90 -o "$B/abc"
  "$B/abc" > "$OUTDIR/a29_observability_o$opt.txt"
  grep -Fq 'A29_OBSERVABILITY_EXECUTION_COMPLETE' "$OUTDIR/a29_observability_o$opt.txt"
done

python3 research/rfm/a28/analyze_a29_observability.py "$OUTDIR/a29_observability_o2.txt" | tee "$OUTDIR/a29_observability_summary.txt"

python3 - "$OUTDIR" <<'PY'
from pathlib import Path
import sys
rows=[]
for p in Path(sys.argv[1]).glob("a29_observability_o*.txt"):
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
