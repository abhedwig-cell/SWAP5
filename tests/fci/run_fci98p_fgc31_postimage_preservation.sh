#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="7b864853ca22baa73141b2dec9ed2f3915ef520d"
FGC31_ADMISSION="7b864853ca22baa73141b2dec9ed2f3915ef520d"
VQ89="f8c43db9cf2dc4f3c330f8cb4d2ba0910f0b68f9"

fail(){ echo "FCI98P_PRESERVATION_FAIL $*" >&2; exit 98; }

git merge-base --is-ancestor "$BASE" HEAD || fail 'F-GC31 canonical admission not ancestor'
if git diff --name-only "$BASE..HEAD" -- 'src/**' | grep -q .; then
  fail 'F-CI98P modifies production source'
fi

expected=(
  .github/workflows/fci71-f-si37-moving-preservation.yml
  .github/workflows/fci72-eb-i23-moving-preservation.yml
  .github/workflows/fci74-eb-i24-moving-preservation.yml
  .github/workflows/fci79-eb-i25-moving-preservation.yml
  .github/workflows/fci98p-fgc31-postimage-preservation.yml
  integration/f-ci/F-CI98P_STATUS.json
  tests/fci/run_fci96_fross13_semantic_successor_preservation.sh
  tests/fci/run_fci_canonical_p2e05_moving_preservation.sh
  tests/fci/run_fci98p_fgc31_postimage_preservation.sh
  tests/ross/run_ross12_serialized_production_wiring.sh
)
mapfile -t changed < <(git diff --name-only "$BASE..HEAD" | sort)
mapfile -t wanted < <(printf '%s
' "${expected[@]}" | sort)
test "${#changed[@]}" -eq "${#wanted[@]}" || {
  printf 'changed:
%s
' "${changed[*]}" >&2
  fail 'unexpected preservation delta count'
}
for i in "${!wanted[@]}"; do
  test "${changed[$i]}" = "${wanted[$i]}" || fail "unexpected preservation path at $i: ${changed[$i]}"
done
echo 'FCI98P_ZERO_PRODUCTION_DELTA=PASS'
echo 'FCI98P_EXACT_GOVERNANCE_TEST_DELTA=PASS'

declare -A BLOBS=(
  [src/adapter/mod_reference_richards_accepted_step_directional_service.f90]="8ca4e08f0297a6b7d0bca1608e9a1ac4d41f4fd7"
  [src/runtime/mod_fmr_drainage_qbot_directional_binding.f90]="481dc8cb1af683053614de3a11c4155acb34b413"
  [src/runtime/mod_fmr_serialized_reference_backend.f90]="4e5491c997ed0752a4db9abd09b5ad3daf394db2"
  [src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90]="2d5342b45a61c9426d2b589b285050b648d141b9"
  [src/solver/mod_b110_smooth_freatic_projection.f90]="e83c1013a1d96508740619a71cfa1dbfdd665d61"
  [src/solver/mod_soil_water_accepted_step_direction_contract.f90]="b5a0276d2f1b2c8ffe581e68dffecdaf55a32768"
  [src/transaction/mod_accepted_trajectory_directional_publication.f90]="b1be9af9ece045cac1fd17087e6b08bc615bd733"
  [src/transaction/mod_accepted_trajectory_directional_sensitivity.f90]="d267a763ceb697557e762c937a99b7f11cb44684"
)
for path in "${!BLOBS[@]}"; do
  test "$(git rev-parse "HEAD:$path")" = "${BLOBS[$path]}" || fail "F-GC31 production drift $path"
done
python3 -m json.tool qualification/F-VQ105_STATUS.json >/dev/null
python3 -m json.tool integration/f-ci/F-CI98_STATUS.json >/dev/null
grep -Fq '"verdict": "INDEPENDENTLY_QUALIFIED_FOR_ADMISSION_REVIEW"' qualification/F-VQ105_STATUS.json
grep -Fq '"verdict": "QUALIFIED_FOR_CANONICAL_ADMISSION"' integration/f-ci/F-CI98_STATUS.json
echo 'FCI98P_FGC31_AUTHORITY_LOCK=PASS'

python3 - <<'PY'
from pathlib import Path
checks={
'.github/workflows/fci71-f-si37-moving-preservation.yml':[
 'FGC31_ADMISSION=7b864853ca22baa73141b2dec9ed2f3915ef520d',
 'b5a0276d2f1b2c8ffe581e68dffecdaf55a32768',
 '8ca4e08f0297a6b7d0bca1608e9a1ac4d41f4fd7',
 'qualification/F-VQ105_STATUS.json',
 'FCI71_MOVING_FGC31_DIRECTIONAL_SUCCESSOR=PASS',
 'git worktree add --detach "$WT" "$VQ89"'
],
'.github/workflows/fci72-eb-i23-moving-preservation.yml':[
 'FGC31_ADMISSION=7b864853ca22baa73141b2dec9ed2f3915ef520d',
 '4e5491c997ed0752a4db9abd09b5ad3daf394db2',
 'FCI72_MOVING_FGC31_BACKEND_SUCCESSOR=PASS'
],
'.github/workflows/fci74-eb-i24-moving-preservation.yml':[
 'FGC31_ADMISSION=7b864853ca22baa73141b2dec9ed2f3915ef520d',
 '4e5491c997ed0752a4db9abd09b5ad3daf394db2',
 'FCI74_MOVING_FGC31_BACKEND_SUCCESSOR=PASS'
],
'.github/workflows/fci79-eb-i25-moving-preservation.yml':[
 'FGC31_ADMISSION=7b864853ca22baa73141b2dec9ed2f3915ef520d',
 '4e5491c997ed0752a4db9abd09b5ad3daf394db2',
 'FCI79_MOVING_FGC31_BACKEND_SUCCESSOR=PASS'
],
'tests/fci/run_fci96_fross13_semantic_successor_preservation.sh':[
 'FGC31_ADMISSION=7b864853ca22baa73141b2dec9ed2f3915ef520d',
 '4e5491c997ed0752a4db9abd09b5ad3daf394db2',
 'FCI96_FGC31_BACKEND_SUCCESSOR=PASS'
],
'tests/fci/run_fci_canonical_p2e05_moving_preservation.sh':[
 'FGC31_ADMISSION=7b864853ca22baa73141b2dec9ed2f3915ef520d',
 'FGC31_BACKEND=4e5491c997ed0752a4db9abd09b5ad3daf394db2',
 'FCI_CANONICAL_FGC31_BACKEND_SUCCESSOR=PASS'
],
'tests/ross/run_ross12_serialized_production_wiring.sh':[
 'src/solver/mod_b110_smooth_freatic_projection.f90',
 'src/runtime/mod_fmr_drainage_qbot_directional_binding.f90'
]
}
for path,tokens in checks.items():
    text=Path(path).read_text()
    for token in tokens:
        assert token in text,(path,token)
print('FCI98P_SUCCESSOR_GUARD_STATIC_AUDIT=PASS')
PY

# Immutable historical F-SI37 qualification remains replayable on its own evidence head.
WT="${RUNNER_TEMP:-/tmp}/fci98p-vq89-${GITHUB_RUN_ID:-local}"
cleanup(){ git worktree remove --force "$WT" >/dev/null 2>&1 || true; }
trap cleanup EXIT
git worktree add --detach "$WT" "$VQ89" >/dev/null
(cd "$WT" && bash tests/qualification/fvq89/run_fvq89_fsi37_independent.sh) > fci98p-vq89.txt
grep -Fq 'FVQ89_QUALIFICATION PASS' fci98p-vq89.txt || fail 'historical VQ89 replay'
echo 'FCI98P_HISTORICAL_FSI37_REPLAY=PASS'

# Historical EB owner authorities remain replayable on their immutable heads.
# Current successor compatibility is guarded separately by exact unchanged EB
# blobs plus the exact F-GC31 backend/evidence locks in the moving workflows.
I23_OWNER=94832bb80534c2edb324c1c9e0cbb54df3678246
I24_OWNER=479fafcbbb02d1e9f9f6cba48384fb4280051a38
I25_OWNER=08be50f248f3e169a3f1aeebd263cfe95b0dccd0
for spec in \
  "i23:$I23_OWNER:tests/eb/run_eb_i23_sensible_boundary_runtime_materialization_gate.sh" \
  "i24:$I24_OWNER:tests/eb/run_eb_i24_top_liquid_sensible_inflow_gate.sh" \
  "i25:$I25_OWNER:tests/eb/run_eb_i25_multisubstep_sensible_boundary_gate.sh"; do
  IFS=: read -r tag head script <<<"$spec"
  EWT="${RUNNER_TEMP:-/tmp}/fci98p-${tag}-${GITHUB_RUN_ID:-local}"
  git worktree add --detach "$EWT" "$head" >/dev/null
  (cd "$EWT" && bash "$script") > "fci98p-${tag}.txt"
  git worktree remove --force "$EWT" >/dev/null
done
echo 'FCI98P_EB_I23_OWNER_REPLAY=PASS'
echo 'FCI98P_EB_I24_OWNER_REPLAY=PASS'
echo 'FCI98P_EB_I25_OWNER_REPLAY=PASS'

# Current RossFast successor preservation compiles the current serialized backend,
# including the additive F-GC31 projection/directional dependencies.
bash tests/fci/run_fci96_fross13_semantic_successor_preservation.sh > fci98p-fross.txt
grep -Fq 'FCI96_FGC31_BACKEND_SUCCESSOR=PASS' fci98p-fross.txt || fail 'F-GC31 backend successor marker missing'
grep -Fq 'FCI96_FROSS13_SEMANTIC_SUCCESSOR_PRESERVATION=PASS' fci98p-fross.txt || fail 'RossFast semantic successor replay'
echo 'FCI98P_ROSSFAST_SUCCESSOR_REPLAY=PASS'

echo 'FCI98P_DECISION=QUALIFIED_POSTIMAGE_PRESERVATION'
