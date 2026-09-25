#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-h04-characterize-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

mapfile -t MODULE_SRC < <(
  awk '
    /^MODULE_SRC=\(/ {inside=1; next}
    inside && /^\)/ {exit}
    inside {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      if (length($0)) print $0
    }
  ' tests/fkt/run_fkt22_fmr_runtime_gate.sh
)

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fopenmp -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD"   -c tests/fpe/test_fpe_zero_waste01_h04_characterization.f90 -o "$BUILD/test.o"
gfortran -fopenmp -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test"

: > "$BUILD/out.txt"
for mode in 2 5 7; do
  for multiplier in 1.0 0.0 0.5 1.5 2.0 5.0; do
    "$BUILD/test" "$mode" "$multiplier" | tee -a "$BUILD/out.txt"
  done
done

grep -Fq 'H04_CASE,bottom_mode=5,flux_multiplier=' "$BUILD/out.txt"
grep -Fq 'H04_CASE,bottom_mode=7,flux_multiplier=' "$BUILD/out.txt"
python3 - "$BUILD/out.txt" <<'PY'
from pathlib import Path
import re,sys
rows=Path(sys.argv[1]).read_text().splitlines()
parsed=[]
for row in rows:
    if not row.startswith("H04_CASE,"): continue
    m=re.search(r"bottom_mode=(\d+),flux_multiplier=\s*([0-9.\-]+),status=(\d+),converged=([TF]),iterations=(\d+),evals=(\d+),initial=(\d+),candidate_full=(\d+),candidate_demand=(\d+),capacity_only=(\d+),terminal=(\d+),capacity_reuse=(\d+)",row)
    if not m: raise SystemExit(f"unparsed row: {row}")
    parsed.append(tuple(m.groups()))
if not parsed: raise SystemExit("no H04 rows")
for r in parsed:
    print("H04_OBSERVATION", *r)
print("FPE_ZERO_WASTE01_H04_CHARACTERIZATION=PASS")
PY
