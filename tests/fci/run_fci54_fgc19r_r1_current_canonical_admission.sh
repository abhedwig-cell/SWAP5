#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

canonical_branch="integration/f-ci-canonical"
canonical="c262ae3c0c06a8fdeb5e87dde2177417c1465f91"
composition="66f6ba0ec63d0f3a7ceb6f84dc67494bd2befc61"
owner_branch="work/f-gc19r-r1-prepared-ledger-provenance-remediation"
owner="3bf3fec344ee67dd56f5f54b293b3a0a47214efb"
vq_branch="qualification/f-vq62-fgc19r-r1-prepared-ledger-provenance-independent-qualification"
vq="9017c8350c5f05deab235a6e59cc53ffdcf6f8dd"
blocked_branch="qualification/f-gc19r-prepared-ledger-publication-owner-qualification"
blocked="c4b0dc78af0b444edcc4b349cc598b5b6167bd1d"
fgc19_branch="work/f-gc19-interface-mass-ledger-diagnostics"
fgc19="215313675c074c18dff251b74581269085f7658e"
source="src/runtime/mod_groundwater_interface_mass_ledger.f90"
source_blob="d37f1926dafde9d941939cf4147d799cb7478bfc"
fgc17_blob="fc598d14eabafcb025bb55621f7b00d6d1816f10"

check_ref() {
  local branch="$1" expected="$2" label="$3"
  local actual
  actual="$(git ls-remote origin "refs/heads/$branch" | awk '{print $1}')"
  test "$actual" = "$expected" || { echo "FCI54_${label}_RACE_FAIL expected=$expected actual=$actual" >&2; exit 20; }
}
check_ref "$canonical_branch" "$canonical" CANONICAL
check_ref "$owner_branch" "$owner" OWNER
check_ref "$vq_branch" "$vq" VQ62
check_ref "$blocked_branch" "$blocked" BLOCKED
check_ref "$fgc19_branch" "$fgc19" FGC19

git fetch --quiet --no-tags origin \
  "$owner_branch" "$vq_branch" "$blocked_branch" "$fgc19_branch" "$canonical_branch"

test "$(git rev-parse "$composition^")" = "$canonical"
parents=( $(git rev-list --parents -n 1 "$composition") )
test "${#parents[@]}" -eq 2
mapfile -t composition_delta < <(git diff --name-only "$canonical..$composition")
test "${#composition_delta[@]}" -eq 1
test "${composition_delta[0]}" = "$source"
if git cat-file -e "$canonical:$source" 2>/dev/null; then
  echo 'FCI54_SOURCE_ALREADY_PRESENT_IN_RESTART_CANONICAL' >&2; exit 21
fi
test "$(git rev-parse "$composition:$source")" = "$source_blob"
test "$(git rev-parse "HEAD:$source")" = "$source_blob"
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_coupling_contract.f90)" = "$fgc17_blob"

allowed=(
  ".github/workflows/fci54-fgc19r-r1-current-canonical-admission.yml"
  "integration/f-ci/F-CI54_PRE_REGISTRATION.json"
  "integration/f-ci/F-CI54_ARCHITECTURE_AUDIT.json"
  "integration/f-ci/F-CI54_STATUS.json"
  "tests/fci/run_fci54_fgc19r_r1_current_canonical_admission.sh"
)
mapfile -t qdelta < <(git diff --name-only "$composition..HEAD")
for path in "${qdelta[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do [[ "$path" == "$candidate" ]] && ok=1 && break; done
  [[ "$ok" -eq 1 ]] || { echo "FCI54_QUAL_SCOPE_FAIL unexpected path: $path" >&2; exit 22; }
done
! git diff --name-only "$composition..HEAD" | grep -Eq '^(src/|reference/)'

! grep -Eiq 'MODFLOW|\.swp|midnight|86400' "$source"
! grep -Eiq 'mass_tolerance|balance_tolerance' "$source"
! grep -Eiq 'c_loc|loc\(' "$source"
! grep -Eiq '^[[:space:]]*save([[:space:]:]|$)' "$source"
grep -q 'prepared%ledger_id /= self%ledger_id' "$source"
grep -q 'GW_MASS_LEDGER_IDENTITY_REQUIRED' "$source"
grep -q 'self%preparation_generation >= huge(self%preparation_generation)' "$source"
grep -q 'self%committed_exchange_count >= huge(self%committed_exchange_count)' "$source"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
git show "$vq:tests/fvq/test_fvq62_fgc19r_r1_prepared_ledger_provenance.f90" > "$work/test_vq62.f90"
git show "$fgc19:tests/fgc/test_fgc19_groundwater_interface_mass_ledger.f90" > "$work/test_fgc19.f90"
git show "$owner:integration/f-gc/F-GC19R_R1_STATUS.json" > "$work/owner_status.json"
git show "$vq:integration/f-vq/F-VQ62_STATUS.json" > "$work/vq_status.json"
git show "$blocked:integration/f-gc/F-GC19R_OWNER_QUALIFICATION_STATUS.json" > "$work/blocked_status.json"

compile_run() {
  local test_src="$1" tag="$2" opt="$3" out="$4"
  local dir="$work/$tag-$opt"
  mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" \
    src/runtime/mod_groundwater_coupling_contract.f90 \
    "$source" "$test_src" -o "$dir/test"
  "$dir/test" > "$out"
}
compile_run "$work/test_vq62.f90" vq62 O0 "$work/vq62-o0.txt"
compile_run "$work/test_vq62.f90" vq62 O2 "$work/vq62-o2.txt"
diff -u "$work/vq62-o0.txt" "$work/vq62-o2.txt"
grep -q '^FVQ62_FOREIGN_HANDLE_SAME_LINEAGE_REJECTION=PASS$' "$work/vq62-o0.txt"
grep -q '^FVQ62_EXACT_ACTION_REACTION=PASS$' "$work/vq62-o0.txt"

compile_run "$work/test_fgc19.f90" fgc19 O0 "$work/fgc19-o0.txt"
compile_run "$work/test_fgc19.f90" fgc19 O2 "$work/fgc19-o2.txt"
diff -u "$work/fgc19-o0.txt" "$work/fgc19-o2.txt"
grep -q '^FGC19_INTERFACE_MASS_LEDGER=PASS$' "$work/fgc19-o0.txt"
grep -q '^FGC19_EXACT_ACTION_REACTION=PASS$' "$work/fgc19-o0.txt"

python3 - "$work" <<'PY'
import json, os, sys
w=sys.argv[1]
owner=json.load(open(os.path.join(w,'owner_status.json')))
vq=json.load(open(os.path.join(w,'vq_status.json')))
blocked=json.load(open(os.path.join(w,'blocked_status.json')))
audit=json.load(open('integration/f-ci/F-CI54_ARCHITECTURE_AUDIT.json'))
assert owner['decision'].startswith('OWNER_QUALIFIED_')
assert owner['state']['owner_qualified'] is True
assert owner['state']['canonical_admission'] is False
assert vq['decision']=='INDEPENDENTLY_QUALIFIED_FOR_CANONICAL_ADMISSION'
assert vq['state']['independently_qualified_for_canonical_admission'] is True
assert vq['state']['canonical_admission'] is False
assert blocked['decision']=='BLOCKED_REMEDIATION_REQUIRED_BEFORE_INDEPENDENT_QUALIFICATION'
assert blocked['state']['owner_qualified'] is False
assert audit['overall']=='30_OF_30_NO_ADVERSE_DELTA_FOR_CANONICAL_ADMISSION'
assert audit['mass_conservation']=='HARD_UNCHANGED_WITH_PROVENANCE_SAFE_PREPARED_PUBLICATION'
assert [x['id'] for x in audit['invariants']]==list(range(1,31))
assert all(x['status']=='PASS' for x in audit['invariants'])
PY

cat "$work/vq62-o0.txt"
cat "$work/fgc19-o0.txt"
echo 'FCI54_LIVE_CANONICAL_LOCK=PASS'
echo 'FCI54_COMPOSITION_DIRECT_CHILD=PASS'
echo 'FCI54_SINGLE_SOURCE_DELTA=PASS'
echo 'FCI54_SOURCE_BLOB_LOCK=PASS'
echo 'FCI54_OWNER_AUTHORITY_LOCK=PASS'
echo 'FCI54_VQ62_AUTHORITY_LOCK=PASS'
echo 'FCI54_FROZEN_BLOCKED_AUTHORITY_LOCK=PASS'
echo 'FCI54_FGC17_CONTRACT_LOCK=PASS'
echo 'FCI54_O0_O2_REPLAYS=PASS'
echo 'FCI54_30_INVARIANTS=PASS'
echo 'FCI54_MASS_HARD_UNCHANGED=PASS'
echo 'FCI54_QUALIFICATION_SCOPE_ALLOWLIST=PASS'
