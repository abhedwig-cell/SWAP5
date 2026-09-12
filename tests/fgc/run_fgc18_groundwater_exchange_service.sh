#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
base="eba90d79010b095b6556e93bd8b77a8c28d25560"
allowed=(
  "src/runtime/mod_groundwater_exchange_service_contract.f90"
  "tests/fgc/test_fgc18_groundwater_exchange_service.f90"
  "tests/fgc/run_fgc18_groundwater_exchange_service.sh"
  ".github/workflows/fgc18-groundwater-exchange-service.yml"
  "integration/f-gc/F-GC18_PRE_REGISTRATION.json"
  "integration/f-gc/F-GC18_ARCHITECTURE_AUDIT.json"
  "integration/f-gc/F-GC18_STATUS.json"
)
mapfile -t changed < <(git diff --name-only "$base..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do [[ "$path" == "$candidate" ]] && ok=1 && break; done
  [[ "$ok" -eq 1 ]] || { echo "FGC18_SCOPE_FAIL unexpected path: $path" >&2; exit 20; }
done

test "$(git rev-parse HEAD:src/runtime/mod_groundwater_coupling_contract.f90)" = fc598d14eabafcb025bb55621f7b00d6d1816f10
! grep -Eiq "MODFLOW|\.swp|midnight|predictor|corrector|tile|mass[_ -]?ledger" src/runtime/mod_groundwater_exchange_service_contract.f90

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
compile_and_run() {
  local opt="$1"
  local out="$2"
  local dir="$work/$opt"
  mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" \
    src/runtime/mod_groundwater_coupling_contract.f90 \
    src/runtime/mod_groundwater_exchange_service_contract.f90 \
    tests/fgc/test_fgc18_groundwater_exchange_service.f90 \
    -o "$dir/test_fgc18"
  "$dir/test_fgc18" > "$out"
}
compile_and_run O0 "$work/o0.txt"
compile_and_run O2 "$work/o2.txt"
diff -u "$work/o0.txt" "$work/o2.txt"
grep -q '^FGC18_TRANSACTIONAL_GW_SERVICE=PASS$' "$work/o0.txt"
grep -q '^FGC18_TRIAL_DOES_NOT_MUTATE_COMMITTED=PASS$' "$work/o0.txt"
grep -q '^FGC18_DISCARD_LEAVES_COMMITTED=PASS$' "$work/o0.txt"
grep -q '^FGC18_SAME_ORIGIN_MULTI_TRIAL=PASS$' "$work/o0.txt"
grep -q '^FGC18_COMMIT_ONCE_AND_STALE_REJECT=PASS$' "$work/o0.txt"
grep -q '^FGC18_NONMIDNIGHT_GENERIC_WINDOW=PASS$' "$work/o0.txt"
if [[ -f integration/f-gc/F-GC18_ARCHITECTURE_AUDIT.json ]]; then
python3 - <<'PY'
import json
d=json.load(open('integration/f-gc/F-GC18_ARCHITECTURE_AUDIT.json'))
assert d['overall']=='30_OF_30_NO_ADVERSE_DELTA'
assert d['mass_conservation']=='HARD_UNCHANGED'
assert [x['id'] for x in d['invariants']]==list(range(1,31))
assert all(x['status']=='PASS' for x in d['invariants'])
PY
fi
cat "$work/o0.txt"
echo 'FGC18_SCOPE_ALLOWLIST=PASS'
echo 'FGC18_FGC17_CONTRACT_LOCK=PASS'
echo 'FGC18_O0_O2_IDENTITY=PASS'
