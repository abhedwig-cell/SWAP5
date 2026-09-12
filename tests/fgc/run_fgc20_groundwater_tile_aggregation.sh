#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
base="eba90d79010b095b6556e93bd8b77a8c28d25560"
allowed=(
  "src/runtime/mod_groundwater_tile_aggregation.f90"
  "tests/fgc/test_fgc20_groundwater_tile_aggregation.f90"
  "tests/fgc/run_fgc20_groundwater_tile_aggregation.sh"
  ".github/workflows/fgc20-groundwater-tile-aggregation.yml"
  "integration/f-gc/F-GC20_PRE_REGISTRATION.json"
  "integration/f-gc/F-GC20_ARCHITECTURE_AUDIT.json"
  "integration/f-gc/F-GC20_STATUS.json"
)
mapfile -t changed < <(git diff --name-only "$base..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do [[ "$path" == "$candidate" ]] && ok=1 && break; done
  [[ "$ok" -eq 1 ]] || { echo "FGC20_SCOPE_FAIL unexpected path: $path" >&2; exit 20; }
done
! grep -Eiq "MODFLOW|\.swp|midnight|normalize" src/runtime/mod_groundwater_tile_aggregation.f90
! grep -Eiq "tolerance" src/runtime/mod_groundwater_tile_aggregation.f90
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
compile_and_run() {
  local opt="$1"
  local out="$2"
  local dir="$work/$opt"
  mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" \
    src/runtime/mod_groundwater_tile_aggregation.f90 \
    tests/fgc/test_fgc20_groundwater_tile_aggregation.f90 \
    -o "$dir/test_fgc20"
  "$dir/test_fgc20" > "$out"
}
compile_and_run O0 "$work/o0.txt"
compile_and_run O2 "$work/o2.txt"
diff -u "$work/o0.txt" "$work/o2.txt"
grep -q '^FGC20_TILE_AGGREGATION=PASS$' "$work/o0.txt"
grep -q '^FGC20_NO_SILENT_NORMALIZATION=PASS$' "$work/o0.txt"
grep -q '^FGC20_MULTI_TILE_CELL=PASS$' "$work/o0.txt"
grep -q '^FGC20_MIXED_COMPONENT_TILES=PASS$' "$work/o0.txt"
grep -q '^FGC20_EXACT_QGW_NEGATIVE_QSWAP=PASS$' "$work/o0.txt"
if [[ -f integration/f-gc/F-GC20_ARCHITECTURE_AUDIT.json ]]; then
python3 - <<'PY'
import json
d=json.load(open('integration/f-gc/F-GC20_ARCHITECTURE_AUDIT.json'))
assert d['overall']=='30_OF_30_NO_ADVERSE_DELTA'
assert d['mass_conservation']=='HARD_UNCHANGED'
assert [x['id'] for x in d['invariants']]==list(range(1,31))
assert all(x['status']=='PASS' for x in d['invariants'])
PY
fi
cat "$work/o0.txt"
echo 'FGC20_SCOPE_ALLOWLIST=PASS'
echo 'FGC20_O0_O2_IDENTITY=PASS'
