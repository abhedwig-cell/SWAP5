#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

base="993673abae05570026dcc55a305679b09472e1d8"
owner="c50f3770ae8e4bee7c276a080be00156218944f1"
postimage="46ed64aba280bf721bce6f99446d0dd4ed00e38f"

binding="src/runtime/mod_groundwater_accuracy_binding.f90"
binding_blob="b8ac03e810c73519b433f7851c6fd143ba26676a"
app_contract="src/runtime/mod_coupling_application_accuracy_contract.f90"
app_contract_blob="c07d573d21e7d013ab962c0a9d28102ab7b5cdfc"
adapter="src/runtime/mod_coupling_application_accuracy_adapter.f90"
adapter_blob="9212d600e89c85287e9280832c7e0a94befb642e"
policy="src/runtime/mod_groundwater_coupling_policy.f90"
policy_blob="5e6fa9db6ddf60d3fc70ed4cec9a33858b0f9976"
temporal="src/solver/mod_reference_richards_temporal_indicator.f90"
temporal_blob="b648502dea7dfd5de8279bcfa06908c705dcfd2f"
owner_test="tests/fgc/test_fgc22_groundwater_accuracy_binding.f90"
owner_test_blob="18c4fa82b1d5c51a3cc0126e31086627a51b453e"

# Admission branch is governance/test-only over the frozen current canonical base.
git merge-base --is-ancestor "$base" HEAD
allowed=(
  ".github/workflows/fci78-fgc22-current-canonical-admission.yml"
  "tests/integration/run_fci78_fgc22_current_canonical_admission.sh"
  "integration/f-ci/F-CI78_STATUS.json"
)
mapfile -t changed < <(git diff --name-only "$base..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do
    [[ "$path" == "$candidate" ]] && ok=1 && break
  done
  [[ "$ok" -eq 1 ]] || { echo "FCI78_SCOPE_FAIL unexpected path: $path" >&2; exit 20; }
done

# GC22 production and direct accuracy-policy dependencies remain byte-exact.
test "$(git rev-parse HEAD:$binding)" = "$binding_blob"
test "$(git rev-parse $owner:$binding)" = "$binding_blob"
test "$(git rev-parse HEAD:$app_contract)" = "$app_contract_blob"
test "$(git rev-parse HEAD:$adapter)" = "$adapter_blob"
test "$(git rev-parse HEAD:$policy)" = "$policy_blob"
test "$(git rev-parse $owner:$owner_test)" = "$owner_test_blob"

# The only preregistered reused dependency that moved is the temporal indicator.
# Its current blob must be the already admitted and reconciled F-CI62P postimage blob.
test "$(git rev-parse HEAD:$temporal)" = "$temporal_blob"
test "$(git rev-parse $postimage:$temporal)" = "$temporal_blob"

python3 - <<'PY'
import json, subprocess
owner='c50f3770ae8e4bee7c276a080be00156218944f1'
postimage='46ed64aba280bf721bce6f99446d0dd4ed00e38f'

def show_json(ref, path):
    return json.loads(subprocess.check_output(['git','show',f'{ref}:{path}']))

s=show_json(owner,'integration/f-gc/F-GC22_STATUS.json')
assert s['qualified'] is True
assert s['decision']=='QUALIFIED_BRANCH_CAPABILITY_READY_FOR_RESTRICTED_COUPLING_COMPOSITION'
q=s['qualification']
for key in ['O0_O2_identity','no_project_numeric_default','separate_interface_allocation_fraction',
            'temporal_plus_interface_allocation_bounded_by_application_budget',
            'temporal_budget_not_aliased_to_interface_tolerance','upstream_accuracy_authority_blobs_locked']:
    assert q[key] is True
assert s['architecture_result']=='30_OF_30_NO_ADVERSE_DELTA'
assert s['mass_conservation']=='HARD_UNCHANGED'

pre=show_json(owner,'integration/f-gc/F-GC22_PRE_REGISTRATION.json')
assert 'src/solver/mod_reference_richards_temporal_indicator.f90' in pre['must_reuse_without_modification']
req='\n'.join(pre['required_semantics']).lower()
assert 'temporal budget is h_app times a_temporal' in req
assert 'not automatically the interface tolerance' in req
assert 'no project-specific numeric defaults' in req

vq=json.load(open('qualification/F-VQ75_STATUS.json'))
assert vq['status']=='QUALIFIED_INDEPENDENT_EVIDENCE_NOT_CANONICAL_ADMISSION'
assert vq['independent_evidence']['F-SI38_preservation_replay']=='PASS'
assert vq['independent_evidence']['O0_O2_semantic_identity'] is True
assert any('not a production, coupling, or application default' in x for x in vq['hard_nonclaims'])

si=json.load(open('integration/f-si/F-SI38_STATUS.json'))
assert si['qualification']['o0_o2_semantic_identity'] is True
assert si['architecture_invariants']['no_silent_application_accuracy_default'] is True
assert any('No universal or application-specific H_budget' in x for x in si['hard_nonclaims'])

ci62p=json.load(open('integration/f-ci/F-CI62P_STATUS.json'))
assert ci62p['canonical_postimage']==postimage
assert ci62p['production_canonical_admitted'] is True
assert ci62p['postimage_reconciled'] is True
assert ci62p['production_reference_delta_in_reconciliation'] is False
assert ci62p['preservation_evidence']['F_CI62_and_F_VQ75_authority_reconciliation']=='PASS'
assert any('No universal H_budget' in x for x in ci62p['hard_nonclaims'])
PY

grep -q 'interface_allocation_fraction' "$binding"
! grep -Eiq 'default.*(tolerance|allocation)|head_tolerance_m[[:space:]]*=[[:space:]]*[0-9]' "$binding"
! grep -Eiq 'MODFLOW|\.swp|midnight' "$binding"

# Replay the immutable owner test against current canonical production sources.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
git show "$owner:$owner_test" > "$work/test_fgc22_groundwater_accuracy_binding.f90"

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
    "$work/test_fgc22_groundwater_accuracy_binding.f90" \
    -o "$dir/test_fgc22"
  "$dir/test_fgc22" > "$out"
}

compile_and_run O0 "$work/o0.txt"
compile_and_run O2 "$work/o2.txt"
diff -u "$work/o0.txt" "$work/o2.txt"
grep -q '^FGC22_GROUNDWATER_ACCURACY_BINDING=PASS$' "$work/o0.txt"
grep -q '^FGC22_NO_PROJECT_NUMERIC_DEFAULT=PASS$' "$work/o0.txt"
grep -q '^FGC22_NO_TEMPORAL_INTERFACE_TOLERANCE_ALIAS=PASS$' "$work/o0.txt"

cat "$work/o0.txt"
echo 'FCI78_OWNER_AUTHORITY_EXACT=PASS'
echo 'FCI78_OWNER_TEST_BLOB_EXACT=PASS'
echo 'FCI78_DIRECT_ACCURACY_DEPENDENCIES_EXACT=PASS'
echo 'FCI78_TEMPORAL_SUPERSESSION_FCI62P_BOUND=PASS'
echo 'FCI78_FVQ75_INDEPENDENT_TEMPORAL_EVIDENCE_REUSED=PASS'
echo 'FCI78_APPLICATION_INTERFACE_SEPARATION_REPLAY=PASS'
echo 'FCI78_TEMPORAL_INTERFACE_SEPARATION_REPLAY=PASS'
echo 'FCI78_NO_PROJECT_NUMERIC_DEFAULT_REPLAY=PASS'
echo 'F_CI78_FINAL_GATE=PASS'
