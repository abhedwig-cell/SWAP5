#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "FCI63_ADMISSION_GATE_FAIL $*" >&2; exit 63; }

CANONICAL="5e5e498dc56d1df1dd7ebebbf9901c946445a1ab"
OWNER="788ff3c9af90143960a5aa3831f0171160aa8c47"
VQ77="728cf5face45be5b46c91701d7ed1102c9950091"
VQ78="6a8258e6e5e2365b51b086212f926f6f1bab5a15"
VQ79="77496e5eb0fe8712613ca2959552d612f3c2a29d"
PRE="integration/f-ci/F-CI63_PRE_REGISTRATION.json"
AUDIT="integration/f-ci/F-CI63_ARCHITECTURE_AUDIT.json"
STATUS="integration/f-ci/F-CI63_STATUS.json"

for object in "$CANONICAL" "$OWNER" "$VQ77" "$VQ78" "$VQ79"; do
  git cat-file -e "$object^{commit}" || fail "missing authority $object"
done
for object in "$OWNER" "$VQ79"; do
  git merge-base --is-ancestor "$object" HEAD || fail "required authority not in admission ancestry $object"
done
LIVE="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE" == "$CANONICAL" ]] || fail "live canonical drift expected=$CANONICAL actual=$LIVE"
[[ "$(git merge-base "$CANONICAL" HEAD)" == "$CANONICAL" ]] || fail 'qualification no longer rooted in frozen canonical'
echo 'FCI63_AUTHORITY_AND_LIVE_CANONICAL_LOCKS=PASS'

expected=$'src/process/mod_liquid_water_sensible_enthalpy.f90\nsrc/runtime/mod_fmr_bottom_external_thermal_binding.f90\nsrc/runtime/mod_fmr_bottom_external_thermal_provider.f90\nsrc/runtime/mod_fmr_bottom_sensible_energy.f90\nsrc/runtime/mod_fmr_bottom_thermal_carrier.f90\nsrc/runtime/mod_fmr_serialized_multiswap_runtime.f90\nsrc/runtime/mod_fmr_serialized_reference_backend.f90'
actual="$(git diff --name-only "$CANONICAL..$VQ79" -- src reference | LC_ALL=C sort)"
[[ "$actual" == "$expected" ]] || {
  printf 'expected production scope:\n%s\nactual:\n%s\n' "$expected" "$actual" >&2
  fail 'exact seven-file production scope mismatch'
}
[[ -z "$(git diff --name-only "$VQ79..HEAD" -- src reference)" ]] || fail 'F-CI63 qualification changed src/reference'

declare -A BLOBS=(
  [src/process/mod_liquid_water_sensible_enthalpy.f90]=2247370ee34fac73a0e2d0b9fa15e171467aded3
  [src/runtime/mod_fmr_bottom_external_thermal_binding.f90]=ed2a2ee36add299ebb5f8bde276da2f3b360cc28
  [src/runtime/mod_fmr_bottom_external_thermal_provider.f90]=885cc50ad1f5cfc17843e412c0f5dfdb989d553b
  [src/runtime/mod_fmr_bottom_sensible_energy.f90]=6c7e9b9ed77d116104fd6299a6404037a2548960
  [src/runtime/mod_fmr_bottom_thermal_carrier.f90]=c371be3e22eaa6da70ca8cbb060bc42d1e0e0bfb
  [src/runtime/mod_fmr_serialized_multiswap_runtime.f90]=07d3699e3e3972921fdb36352d75c47cb12d03b7
  [src/runtime/mod_fmr_serialized_reference_backend.f90]=3506b453ba6a00111d182f29db8cbfb288001854
)
for path in "${!BLOBS[@]}"; do
  actual_blob="$(git rev-parse "$VQ79:$path")"
  [[ "$actual_blob" == "${BLOBS[$path]}" ]] || fail "qualified production blob mismatch $path $actual_blob"
  [[ "$(git rev-parse "HEAD:$path")" == "${BLOBS[$path]}" ]] || fail "admission head production blob mismatch $path"
done
echo 'FCI63_EXACT_SEVEN_PRODUCTION_BLOBS_LOCKED=PASS'

python3 - "$PRE" "$AUDIT" "$STATUS" "$VQ77" "$VQ78" <<'PY'
import json
import pathlib
import subprocess
import sys

pre = json.loads(pathlib.Path(sys.argv[1]).read_text())
audit = json.loads(pathlib.Path(sys.argv[2]).read_text())
vq79 = json.loads(pathlib.Path('qualification/F-VQ79_STATUS.json').read_text())
vq77_sha, vq78_sha = sys.argv[4], sys.argv[5]
vq77 = json.loads(subprocess.check_output(['git', 'show', f'{vq77_sha}:qualification/F-VQ77_STATUS.json'], text=True))
vq78 = json.loads(subprocess.check_output(['git', 'show', f'{vq78_sha}:qualification/F-VQ78_STATUS.json'], text=True))

assert pre['canonical_base']['sha'] == '5e5e498dc56d1df1dd7ebebbf9901c946445a1ab'
assert len(pre['production_scope']) == 7
assert pre['scope_guards']['new_physics_in_F_CI63'] is False
assert pre['scope_guards']['new_mass_booking_in_F_CI63'] is False
assert pre['scope_guards']['second_water_ledger'] is False
assert pre['scope_guards']['new_persistent_column_state'] is False
assert pre['scope_guards']['new_solver_policy'] is False
assert pre['scope_guards']['new_application_accuracy_default'] is False
assert pre['scope_guards']['reference_source_changed'] is False
assert pre['scope_guards']['full_energy_balance_completion_claim'] is False

assert len(audit['invariants']) == 30
assert [item['id'] for item in audit['invariants']] == list(range(1, 31))
assert all(item['assessment'] == 'NO_ADVERSE_ADMISSION_DELTA' for item in audit['invariants'])
assert audit['overall'] == '30_OF_30_NO_ADVERSE_ADMISSION_DELTA'
assert audit['canonical_admission'] is False

assert vq77['status'] == 'QUALIFIED_INDEPENDENT_EVIDENCE_NOT_CANONICAL_ADMISSION'
assert vq77['conclusion'] == 'success'
assert vq78['status'] == 'QUALIFIED_INDEPENDENT_EVIDENCE_NOT_CANONICAL_ADMISSION'
assert vq78['conclusion'] == 'success'
assert vq79['status'] == 'QUALIFIED_INDEPENDENT_EVIDENCE_NOT_CANONICAL_ADMISSION'
assert vq79['decision'] == 'QUALIFIED_FOR_CURRENT_CANONICAL_ADMISSION_REVIEW'
assert vq79['conclusion'] == 'success'
assert vq79['owner_authorities']['EB-I19R_candidate'] == '788ff3c9af90143960a5aa3831f0171160aa8c47'
assert vq79['independent_evidence']['remediation_production_delta_exactly_three_files'] is True
assert vq79['independent_evidence']['reference_source_changed'] is False
assert vq79['independent_evidence']['no_physics_tolerance_or_solver_policy_change'] is True
assert vq79['independent_evidence']['pre_post_numeric_semantic_identity'] == 'PASS'
assert abs(vq79['independent_evidence']['max_abs_mass_residual_cm']) <= 1.0e-12
assert vq79['independent_evidence']['O0_O2_semantic_identity'] is True
assert vq79['independent_evidence']['accepted_only_energy_publication_preserved'] is True
assert vq79['independent_evidence']['rejected_trial_no_publication_preserved'] is True
assert vq79['independent_evidence']['backend_reuse_no_stale_publication_preserved'] is True

if pathlib.Path(sys.argv[3]).exists():
    status = json.loads(pathlib.Path(sys.argv[3]).read_text())
    assert status['decision'] == 'QUALIFIED_F_CI63_READY_FOR_CANONICAL_PROMOTION'
    assert status['ready_for_canonical_promotion'] is True
    assert status['canonical_admission'] is False

print('FCI63_OWNER_INDEPENDENT_AND_30_INVARIANT_AUTHORITIES=PASS')
PY

# F-VQ79 is the independent admission oracle. It reconstructs the remediation,
# proves no physics-policy/tolerance change, compares pre/post numeric outputs,
# checks hard mass closure and reruns O0/O2 EB/F-MR44R qualification.
bash tests/fvq/run_fvq79_eb_i19r_warning_hygiene_independent.sh
echo 'FCI63_FVQ79_INDEPENDENT_REPLAY=PASS'

git diff --quiet -- src reference || fail 'admission replay mutated production/reference source'
git diff --check "$VQ79..HEAD"
echo "FCI63_EXACT_HEAD=$(git rev-parse HEAD)"
echo 'F-CI63 CURRENT-CANONICAL ADMISSION GATE PASS'
