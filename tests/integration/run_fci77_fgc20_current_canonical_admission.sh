#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

base="687ee32ca98a42368a2b6380ea78d33eb254dad9"
owner="54dc9cc930468d9f376f596fe2c1b6f45938b59b"
prod="src/runtime/mod_groundwater_tile_aggregation.f90"
prod_blob="d62ecba039d9bef178acde6900b81e9d5b0931eb"

# Admission branch is governance/test-only over the frozen current canonical base.
git merge-base --is-ancestor "$base" HEAD
allowed=(
  ".github/workflows/fci77-fgc20-current-canonical-admission.yml"
  "tests/integration/run_fci77_fgc20_current_canonical_admission.sh"
  "integration/f-ci/F-CI77_STATUS.json"
)
mapfile -t changed < <(git diff --name-only "$base..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do [[ "$path" == "$candidate" ]] && ok=1 && break; done
  [[ "$ok" -eq 1 ]] || { echo "FCI77_SCOPE_FAIL unexpected path: $path" >&2; exit 20; }
done

test "$(git rev-parse HEAD:$prod)" = "$prod_blob"
test "$(git rev-parse $owner:$prod)" = "$prod_blob"

python3 - <<'PY'
import json, subprocess
owner='54dc9cc930468d9f376f596fe2c1b6f45938b59b'
prod='d62ecba039d9bef178acde6900b81e9d5b0931eb'
owner_status=json.loads(subprocess.check_output(['git','show',f'{owner}:integration/f-gc/F-GC20_STATUS.json']))
assert owner_status['qualified'] is True
assert owner_status['decision']=='QUALIFIED_BRANCH_CAPABILITY_READY_FOR_RESTRICTED_COUPLING_COMPOSITION'
q=owner_status['qualification']
assert all(q[k] is True for k in ['O0_O2_identity','no_silent_normalization','multi_tile_cell','mixed_component_tiles','exact_qgw_negative_qswap'])
assert owner_status['architecture_result']=='30_OF_30_NO_ADVERSE_DELTA'
assert owner_status['mass_conservation']=='HARD_UNCHANGED'

vq=json.load(open('qualification/F-VQ87_STATUS.json'))
assert vq['status']=='QUALIFIED_INDEPENDENT_EVIDENCE_NOT_CANONICAL_ADMISSION'
a=vq['inherited_authorities']['F-GC20']
assert a['authority_head']==owner and a['production_blob']==prod and a['exact_on_tested_head'] is True
m=vq['evidence_markers']
for key in ['FVQ87_FGC20_FGC22_INHERITANCE_LOCKED','FVQ87_WEIGHTED_MASS_ACTION_REACTION','FVQ87_INDEPENDENT_ORACLE','FVQ87_INDEPENDENT_ORACLE_O0_O2_IDENTITY','F_VQ87_FINAL_GATE']:
    assert m[key]=='PASS'

ci73=json.load(open('integration/f-ci/F-CI73_STATUS.json'))
a=ci73['inherited_authorities']['F-GC20']
assert a['head']==owner and a['production_blob']==prod
assert ci73['qualified_production_blobs']['src/runtime/mod_groundwater_tile_aggregation.f90']==prod
PY

grep -q 'area_fraction' "$prod"
grep -q 'weighted_flux' "$prod"
grep -q 'q_groundwater_area_weighted_m_per_s = -weighted_flux' "$prod"
! grep -Eiq 'normalize|renormal' "$prod"

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
for marker in \
  FGC20_TILE_AGGREGATION \
  FGC20_NO_SILENT_NORMALIZATION \
  FGC20_MULTI_TILE_CELL \
  FGC20_MIXED_COMPONENT_TILES \
  FGC20_EXACT_QGW_NEGATIVE_QSWAP; do
  grep -q "^${marker}=PASS$" "$work/o0.txt"
done
cat "$work/o0.txt"
echo 'FCI77_OWNER_AUTHORITY_EXACT=PASS'
echo 'FCI77_FVQ87_INDEPENDENT_EVIDENCE_REUSED=PASS'
echo 'FCI77_CURRENT_CANONICAL_PRODUCTION_BLOB_EXACT=PASS'
echo 'FCI77_GC20_CONTRACT_PRESERVATION_REPLAY=PASS'
echo 'F_CI77_FINAL_GATE=PASS'
