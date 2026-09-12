#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
base="eba90d79010b095b6556e93bd8b77a8c28d25560"
allowed=(
  "src/runtime/mod_groundwater_interface_mass_ledger.f90"
  "tests/fgc/test_fgc19_groundwater_interface_mass_ledger.f90"
  "tests/fgc/run_fgc19_groundwater_interface_mass_ledger.sh"
  ".github/workflows/fgc19-groundwater-interface-mass-ledger.yml"
  "integration/f-gc/F-GC19_PRE_REGISTRATION.json"
  "integration/f-gc/F-GC19_ARCHITECTURE_AUDIT.json"
  "integration/f-gc/F-GC19_STATUS.json"
)
mapfile -t changed < <(git diff --name-only "$base..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do [[ "$path" == "$candidate" ]] && ok=1 && break; done
  [[ "$ok" -eq 1 ]] || { echo "FGC19_SCOPE_FAIL unexpected path: $path" >&2; exit 20; }
done

test "$(git rev-parse HEAD:src/runtime/mod_groundwater_coupling_contract.f90)" = fc598d14eabafcb025bb55621f7b00d6d1816f10
! grep -q 'mass_tolerance' src/runtime/mod_groundwater_interface_mass_ledger.f90
! grep -Eiq 'MODFLOW|\.swp|midnight' src/runtime/mod_groundwater_interface_mass_ledger.f90

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
compile_and_run() {
  local opt="$1" out="$2" dir="$work/$opt"
  mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" \
    src/runtime/mod_groundwater_coupling_contract.f90 \
    src/runtime/mod_groundwater_interface_mass_ledger.f90 \
    tests/fgc/test_fgc19_groundwater_interface_mass_ledger.f90 \
    -o "$dir/test_fgc19"
  "$dir/test_fgc19" > "$out"
}
compile_and_run O0 "$work/o0.txt"
compile_and_run O2 "$work/o2.txt"
diff -u "$work/o0.txt" "$work/o2.txt"
grep -q '^FGC19_INTERFACE_MASS_LEDGER=PASS$' "$work/o0.txt"
grep -q '^FGC19_REJECTED_TRIAL_NOT_BOOKED=PASS$' "$work/o0.txt"
grep -q '^FGC19_COMMIT_ONCE=PASS$' "$work/o0.txt"
grep -q '^FGC19_EXACT_ACTION_REACTION=PASS$' "$work/o0.txt"
grep -q '^FGC19_NO_INTERFACE_MASS_TOLERANCE=PASS$' "$work/o0.txt"
if [[ -f integration/f-gc/F-GC19_ARCHITECTURE_AUDIT.json ]]; then
python3 - <<'PY'
import json
d=json.load(open('integration/f-gc/F-GC19_ARCHITECTURE_AUDIT.json'))
assert d['overall']=='30_OF_30_NO_ADVERSE_DELTA'
assert d['mass_conservation']=='HARD_UNCHANGED'
assert [x['id'] for x in d['invariants']]==list(range(1,31))
assert all(x['status']=='PASS' for x in d['invariants'])
PY
fi
cat "$work/o0.txt"
echo 'FGC19_SCOPE_ALLOWLIST=PASS'
echo 'FGC19_FGC17_CONTRACT_LOCK=PASS'
echo 'FGC19_O0_O2_IDENTITY=PASS'
