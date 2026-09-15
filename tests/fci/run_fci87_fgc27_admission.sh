#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

CANONICAL=5e4386f06a230c71eba103fd8e12fec97e7fae6d
QUAL_AUTH=d45abdfb7fbd3f1ce5f68866586c5e9e67252f54
QUAL_TESTED=5566d4888ae2395fc8d38e9e6ab07d4ff83f9b07
QUAL_STATUS_BLOB=b0293312470949f3483a6ac284106962ae62285e
QUAL_CHECKPOINT_BLOB=d949444063bfb74a35ca47355edd8e50f75b0229

allowed=(
  ".github/workflows/f-ci87-fgc27-admission.yml"
  "tests/fci/F-CI87_ADMIT_CHECKPOINT.json"
  "tests/fci/run_fci87_fgc27_admission.sh"
)
mapfile -t changed < <(git diff --name-only "$CANONICAL..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do
    if [[ "$path" == "$candidate" ]]; then ok=1; break; fi
  done
  if [[ "$ok" -ne 1 ]]; then
    echo "FCI87_SCOPE_FAIL unexpected path: $path" >&2
    exit 20
  fi
done
echo 'FCI87_METADATA_ONLY_DELTA=PASS'

# Exact production postimage must still be the independently qualified image.
declare -A PINNED=(
  [src/runtime/mod_groundwater_predictor_corrector_window.f90]=fa2a5a45d558fbaaea242438915cdb7420b6503c
  [src/runtime/mod_groundwater_tile_aggregation.f90]=d62ecba039d9bef178acde6900b81e9d5b0931eb
  [src/runtime/mod_groundwater_accuracy_binding.f90]=b8ac03e810c73519b433f7851c6fd143ba26676a
  [src/runtime/mod_groundwater_coupling_response.f90]=645141676536ae8289b9d52433798a965c7baa04
  [src/runtime/mod_groundwater_coupled_restart.f90]=0596933ff3ae89c61ab7a0913189a4fa3179e50b
  [src/runtime/mod_groundwater_multiswap_coupler.f90]=f2bf0e7d144fd3c0b9dc18f24f24eb4ffb7ffa0f
  [src/adapter/mod_groundwater_external_gateway.f90]=f307f17e2fd20983432f91e91ac90aaae8311849
  [src/runtime/mod_groundwater_coupling_contract.f90]=fc598d14eabafcb025bb55621f7b00d6d1816f10
  [src/runtime/mod_groundwater_exchange_service_contract.f90]=e99ae052fccd9992b76c12a91422a987dce059e2
  [src/runtime/mod_coupling_application_accuracy_contract.f90]=c07d573d21e7d013ab962c0a9d28102ab7b5cdfc
)
for path in "${!PINNED[@]}"; do
  expected="${PINNED[$path]}"
  test "$(git rev-parse "$CANONICAL:$path")" = "$expected"
  test "$(git rev-parse "HEAD:$path")" = "$expected"
done
echo 'FCI87_CURRENT_CANONICAL_PRODUCTION_LOCKED=PASS'

# Qualification authority must be immutable and internally self-consistent.
git cat-file -e "$QUAL_AUTH^{commit}"
git merge-base --is-ancestor "$QUAL_TESTED" "$QUAL_AUTH"
test "$(git rev-parse "$QUAL_AUTH:qualification/F-VQ97_STATUS.json")" = "$QUAL_STATUS_BLOB"
test "$(git rev-parse "$QUAL_AUTH:tests/qualification/fvq97/F-VQ97_QUALIFY_CHECKPOINT.json")" = "$QUAL_CHECKPOINT_BLOB"
python3 - "$QUAL_AUTH" <<'PY'
import json, subprocess, sys
q=sys.argv[1]
def show(path):
    return subprocess.check_output(['git','show',f'{q}:{path}'], text=True)
s=json.loads(show('qualification/F-VQ97_STATUS.json'))
c=json.loads(show('tests/qualification/fvq97/F-VQ97_QUALIFY_CHECKPOINT.json'))
assert s['subject_capability']=='F-GC27'
assert s['conclusion']=='success'
assert s['verdict']=='INDEPENDENTLY_QUALIFIED'
assert s['qualification_tested_head']=='5566d4888ae2395fc8d38e9e6ab07d4ff83f9b07'
assert s['workflow_run_id']==35031745967
assert s['workflow_job_id']==104591583793
assert s['production_delta'] is False
assert s['independent_oracle_sha256']=='b05c239a74873d0ae0df29905cabef0ab3fe8c6b3859e00fc22eeb61b444d3dd'
assert all(v=='PASS' for v in s['evidence_markers'].values())
assert c['verdict']=='INDEPENDENTLY_QUALIFIED'
assert c['production_mutations']==[]
assert c['workflow']['conclusion']=='success'
PY
echo 'FCI87_FVQ97_IMMUTABLE_AUTHORITY=PASS'

# The admission decision does not reinterpret separate F-GC23/F-GC24 ownership.
for path in \
  src/runtime/mod_groundwater_predictor_corrector_window.f90 \
  src/runtime/mod_groundwater_multiswap_coupler.f90; do
  if grep -Eq 'compose_groundwater_coupling_response|mod_groundwater_coupling_response' "$path"; then
    echo "FCI87_OWNERSHIP_FAIL response composition leaked into $path" >&2
    exit 21
  fi
done
if grep -Eq 'external_groundwater_backend_t|groundwater_external_gateway_t' \
   src/runtime/mod_groundwater_predictor_corrector_window.f90 \
   src/runtime/mod_groundwater_multiswap_coupler.f90; then
  echo 'FCI87_BACKEND_BOUNDARY_FAIL' >&2
  exit 22
fi
echo 'FCI87_OWNERSHIP_BOUNDARIES_PRESERVED=PASS'

echo 'FCI87_FGC27_CURRENT_CANONICAL_ADMISSION=PASS'
echo 'F-CI87 F-GC27 ADMISSION GATE PASS'
