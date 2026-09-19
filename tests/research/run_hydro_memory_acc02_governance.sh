#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-hm-acc02-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "HYDRO_MEMORY_ACC02_FAIL $*" >&2; exit 72; }

BASE=2a1ac9b221305ebdc191cf444b8561d2c068fee2
SOURCE=docs/publication/HYDRO_MEMORY_STAGE0_INTERFACE_ACCURACY_GOVERNANCE_V1.md
EXPECTED_BLOB=62841616e83ae9209cd33566929866a7e54d87d6

git merge-base --is-ancestor "$BASE" HEAD || fail "branch not descended from ACC01-F1 authority"
git diff --quiet "$BASE"..HEAD -- src || fail "ACC02 changed production source"
git diff --quiet "$BASE"..HEAD -- reference || fail "ACC02 changed reference source"
[[ "$(git rev-parse HEAD:$SOURCE)" == "$EXPECTED_BLOB" ]] || fail "interface governance source blob drift"

python3 - <<'PY'
import json
p=json.load(open('integration/research/HYDRO_MEMORY_ACC02_PREREGISTRATION.json',encoding='utf-8'))
g=p['interface_governance']
assert g['source_git_blob_sha1']=='62841616e83ae9209cd33566929866a7e54d87d6'
assert g['interface_allocation_fraction']==0.25
assert g['interface_tolerance_cm']==0.1
assert g['interface_tolerance_m']==0.001
assert p['budget_partition']['temporal_fraction']==0.25
assert p['budget_partition']['interface_fraction']==0.25
assert p['budget_partition']['unallocated_fraction']==0.50
print('HYDRO_MEMORY_ACC02_GOVERNANCE_SOURCE_LOCK=PASS')
print('HYDRO_MEMORY_ACC02_FROZEN_ALLOCATION=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
run_one(){
  local opt="$1" out="$2"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_soil_water_accepted_step_direction_contract.f90 -o "$out/step_direction.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 -o "$out/trajectory_sensitivity.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/transaction/mod_accepted_trajectory_directional_publication.f90 -o "$out/trajectory_publication.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/transaction/mod_transaction_reference.f90 -o "$out/transaction.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/runtime/mod_canonical_contracts.f90 -o "$out/contracts.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/runtime/mod_coupling_application_accuracy_contract.f90 -o "$out/accuracy_contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/runtime/mod_coupling_application_accuracy_adapter.f90 -o "$out/accuracy_adapter.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/runtime/mod_groundwater_coupling_policy.f90 -o "$out/gw_policy.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/runtime/mod_groundwater_accuracy_binding.f90 -o "$out/gw_binding.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c tests/research/test_hydro_memory_acc02_interface_accuracy_binding.f90 -o "$out/test.o"
  gfortran -O"$opt" "$out/step_direction.o" "$out/trajectory_sensitivity.o" "$out/trajectory_publication.o"     "$out/transaction.o" "$out/contracts.o" "$out/accuracy_contract.o" "$out/accuracy_adapter.o"     "$out/gw_policy.o" "$out/gw_binding.o" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/output.txt"
}
run_one 0 "$BUILD/o0"
run_one 2 "$BUILD/o2"

diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail "O0/O2 output drift"
cat "$BUILD/o0/output.txt"
for marker in   HYDRO_MEMORY_ACC02_TYPED_INTERFACE_BINDING=PASS   HYDRO_MEMORY_ACC02_BOUNDARY_POLICY=PASS   HYDRO_MEMORY_ACC02_GOVERNANCE_QUALIFIED; do
  grep -Fq "$marker" "$BUILD/o0/output.txt" || fail "missing $marker"
done

echo 'HYDRO_MEMORY_ACC02_O0_O2_IDENTITY=PASS'
echo 'HYDRO_MEMORY_ACC02_GOVERNANCE_GATE=PASS'
