#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE=308a619c91d2cc3dae7f7aa143cfbe97c780c635
FGC13_AUTH=6d91bedc305504cc2fa08b196e6a9903c48c9461
EXPECTED_DIGEST=b35d4e4af46f1ed56b787e0b4c606077e2fded727cff8a16e34cc7e09d4f74b7
SOURCE=docs/publication/HYDRO_MEMORY_STAGE0_ACCURACY_GOVERNANCE_V1.md
PACKET=integration/research/HYDRO_MEMORY_ACC01_PROJECT_ACCURACY_PACKET.json
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-hm-acc01-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "HYDRO_MEMORY_ACC01_FAIL $*" >&2; exit 71; }

git merge-base --is-ancestor "$BASE" HEAD || fail "branch not descended from ACC01 canonical base"
git diff --quiet "$BASE"..HEAD -- src || fail "ACC01 changed production source"
git diff --quiet "$BASE"..HEAD -- reference || fail "ACC01 changed reference source"

ACTUAL_DIGEST="$(sha256sum "$SOURCE" | awk '{print $1}')"
[[ "$ACTUAL_DIGEST" == "$EXPECTED_DIGEST" ]] || fail "governance source digest mismatch: $ACTUAL_DIGEST"
python3 - "$PACKET" "$EXPECTED_DIGEST" <<'PY'
import json,sys
packet=json.load(open(sys.argv[1],encoding='utf-8'))
digest=sys.argv[2]
assert packet['application_requirement']['provenance']['source_digest_sha256']==digest
assert packet['temporal_policy']['provenance']['source_digest_sha256']==digest
assert packet['application_requirement']['value_cm']==0.4
assert packet['temporal_policy']['allocation_fraction']==0.25
print('HYDRO_MEMORY_ACC01_SOURCE_DIGEST_VERIFIED=PASS')
PY

git cat-file -e "${FGC13_AUTH}^{commit}" 2>/dev/null || git fetch --no-tags origin "$FGC13_AUTH" >/dev/null 2>&1 || fail "cannot fetch F-GC13 authority"
git show "$FGC13_AUTH:tests/fgc/validate_fgc13_project_accuracy_contract.py" > "$BUILD/validate_fgc13.py"
VALIDATION="$(python3 "$BUILD/validate_fgc13.py" "$PACKET")" || fail "F-GC13 validator rejected packet"
printf '%s\n' "$VALIDATION"
grep -Fq 'FGC13_PACKET_DECISION=ACCEPT' <<<"$VALIDATION" || fail "F-GC13 ACCEPT marker missing"
python3 - "$VALIDATION" <<'PY'
import json,math,sys
mapping=json.loads(sys.argv[1].splitlines()[-1])
assert mapping['qoi_kind']=='GROUNDWATER_HEAD'
assert mapping['qoi_kind_value']==1
assert math.isclose(mapping['h_app_cm'],0.4,rel_tol=0.0,abs_tol=1e-15)
assert math.isclose(mapping['a_temporal'],0.25,rel_tol=0.0,abs_tol=1e-15)
assert math.isclose(mapping['model_temporal_indicator_budget_cm'],0.1,rel_tol=0.0,abs_tol=1e-15)
assert mapping['application_provenance_id']==590201
assert mapping['temporal_allocation_provenance_id']==590202
print('HYDRO_MEMORY_ACC01_FGC13_MAPPING=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
build_run(){
  local opt="$1" out="$2"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/solver/mod_soil_water_accepted_step_direction_contract.f90 -o "$out/step_direction.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 -o "$out/trajectory_sensitivity.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_accepted_trajectory_directional_publication.f90 -o "$out/trajectory_publication.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/solver/mod_soil_water_accepted_step_direction_contract.f90 -o "$out/step_direction_contract.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 -o "$out/trajectory_sensitivity.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_accepted_trajectory_directional_publication.f90 -o "$out/trajectory_publication.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_transaction_reference.f90 -o "$out/transaction.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/runtime/mod_canonical_contracts.f90 -o "$out/contracts.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/runtime/mod_coupling_application_accuracy_contract.f90 -o "$out/accuracy_contract.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/runtime/mod_coupling_application_accuracy_adapter.f90 -o "$out/accuracy_adapter.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/research/test_hydro_memory_acc01_accuracy_binding.f90 -o "$out/test.o"
  gfortran "$opt" "$out/step_direction.o" "$out/trajectory_sensitivity.o" "$out/trajectory_publication.o" "$out/transaction.o" "$out/contracts.o" "$out/accuracy_contract.o" "$out/accuracy_adapter.o" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/output.txt"
}

build_run -O0 "$BUILD/o0"
build_run -O2 "$BUILD/o2"
diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail "O0/O2 governed binding output drift"
cat "$BUILD/o0/output.txt"

for marker in   HYDRO_MEMORY_ACC01_TYPED_BINDING=PASS   HYDRO_MEMORY_ACC01_GOVERNANCE_QUALIFIED; do
  grep -Fq "$marker" "$BUILD/o0/output.txt" || fail "missing marker $marker"
done

echo 'HYDRO_MEMORY_ACC01_O0_O2_IDENTITY=PASS'
echo 'HYDRO_MEMORY_ACC01_GOVERNANCE_GATE=PASS'
