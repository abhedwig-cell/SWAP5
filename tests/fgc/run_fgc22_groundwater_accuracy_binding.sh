#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

base="eba90d79010b095b6556e93bd8b77a8c28d25560"
allowed=(
  "src/runtime/mod_groundwater_accuracy_binding.f90"
  "tests/fgc/test_fgc22_groundwater_accuracy_binding.f90"
  "tests/fgc/run_fgc22_groundwater_accuracy_binding.sh"
  ".github/workflows/fgc22-groundwater-accuracy-binding.yml"
  "integration/f-gc/F-GC22_PRE_REGISTRATION.json"
  "integration/f-gc/F-GC22_ARCHITECTURE_AUDIT.json"
  "integration/f-gc/F-GC22_STATUS.json"
)

mapfile -t changed < <(git diff --name-only "$base..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do
    if [[ "$path" == "$candidate" ]]; then ok=1; break; fi
  done
  if [[ "$ok" -ne 1 ]]; then
    echo "FGC22_SCOPE_FAIL unexpected path: $path" >&2
    exit 20
  fi
done

test "$(git rev-parse HEAD:src/runtime/mod_coupling_application_accuracy_contract.f90)" = c07d573d21e7d013ab962c0a9d28102ab7b5cdfc
test "$(git rev-parse HEAD:src/runtime/mod_coupling_application_accuracy_adapter.f90)" = 9212d600e89c85287e9280832c7e0a94befb642e
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_coupling_policy.f90)" = 5e6fa9db6ddf60d3fc70ed4cec9a33858b0f9976
test "$(git rev-parse HEAD:src/solver/mod_reference_richards_temporal_indicator.f90)" = fe8f87d11257d4c6bc019f1d628ac41ba3106d4e

grep -q "interface_allocation_fraction" src/runtime/mod_groundwater_accuracy_binding.f90
! grep -Eiq "default.*(tolerance|allocation)|head_tolerance_m[[:space:]]*=[[:space:]]*[0-9]" src/runtime/mod_groundwater_accuracy_binding.f90
! grep -Eiq "MODFLOW|\.swp|midnight" src/runtime/mod_groundwater_accuracy_binding.f90

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

compile_and_run() {
  local opt="$1"
  local out="$2"
  local dir="$work/$opt"
  mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" \
    src/transaction/mod_transaction_reference.f90 \
    src/runtime/mod_canonical_contracts.f90 \
    src/runtime/mod_coupling_application_accuracy_contract.f90 \
    src/runtime/mod_groundwater_coupling_policy.f90 \
    src/runtime/mod_groundwater_accuracy_binding.f90 \
    tests/fgc/test_fgc22_groundwater_accuracy_binding.f90 \
    -o "$dir/test_fgc22"
  "$dir/test_fgc22" > "$out"
}

compile_and_run O0 "$work/o0.txt"
compile_and_run O2 "$work/o2.txt"
diff -u "$work/o0.txt" "$work/o2.txt"
grep -q '^FGC22_GROUNDWATER_ACCURACY_BINDING=PASS$' "$work/o0.txt"
grep -q '^FGC22_NO_PROJECT_NUMERIC_DEFAULT=PASS$' "$work/o0.txt"
grep -q '^FGC22_NO_TEMPORAL_INTERFACE_TOLERANCE_ALIAS=PASS$' "$work/o0.txt"

if [[ -f integration/f-gc/F-GC22_ARCHITECTURE_AUDIT.json ]]; then
  python3 - <<'PY'
import json
p='integration/f-gc/F-GC22_ARCHITECTURE_AUDIT.json'
d=json.load(open(p))
assert d['overall']=='30_OF_30_NO_ADVERSE_DELTA'
assert d['mass_conservation']=='HARD_UNCHANGED'
assert [x['id'] for x in d['invariants']]==list(range(1,31))
assert all(x['status']=='PASS' for x in d['invariants'])
PY
fi

cat "$work/o0.txt"
echo 'FGC22_SCOPE_ALLOWLIST=PASS'
echo 'FGC22_UPSTREAM_AUTHORITY_BLOBS=PASS'
echo 'FGC22_O0_O2_IDENTITY=PASS'
