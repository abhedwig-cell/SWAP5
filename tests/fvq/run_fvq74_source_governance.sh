#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "FVQ74_SOURCE_GOVERNANCE_FAIL $*" >&2; exit 74; }

CANONICAL='e79b0272edb544ec4c8000a4d6869274f1ab3ae5'
TREE='44e904cd2c57a76ee6c7453a6782049b230a8f8d'
COMPOSITION='c7444233b0f23d4f0a845ef5639287e77099291b'
SOURCE_ADMISSION='eb2b2b17b2d54eeab22c4cba922426d8168e56a9'
PRESERVATION_PARENT='537695a6194d22b19e28d2d9abfb0d80da42dd93'

[[ "$(git rev-parse origin/integration/f-ci-canonical)" == "$CANONICAL" ]] || fail 'live canonical drifted from preregistered authority'
[[ "$(git rev-parse "$CANONICAL^{tree}")" == "$TREE" ]] || fail 'canonical tree drift'
git merge-base --is-ancestor "$CANONICAL" HEAD || fail 'qualification head not descended from exact canonical'
git diff --quiet "$CANONICAL"..HEAD -- src reference || fail 'qualification branch modifies src/reference'

echo 'FVQ74_LIVE_CANONICAL_LOCK=PASS'
echo 'FVQ74_NO_PRODUCTION_OR_REFERENCE_DELTA=PASS'

mapfile -t parents < <(git cat-file -p "$CANONICAL" | awk '$1=="parent"{print $2}')
[[ ${#parents[@]} -eq 2 ]] || fail 'canonical preservation authority is not a two-parent merge'
[[ "${parents[0]}" == "$SOURCE_ADMISSION" ]] || fail 'unexpected canonical first parent'
[[ "${parents[1]}" == "$PRESERVATION_PARENT" ]] || fail 'unexpected canonical second parent'
echo 'FVQ74_FCI61P_CANONICAL_LINEAGE=PASS'

declare -A PROD_BLOBS=(
  [src/process/mod_drainage_empirical_interflow_response.f90]=eb53096b678d08b76d3fb1adb2247bc2a58ee748
  [src/process/mod_drainage_ernst_ipos45_preparation.f90]=fa1d5d400bb32be42e78889c0ff2a3bcab335142
  [src/process/mod_drainage_ernst_ipos45_response.f90]=b00ef0ae1f10182af2d0a8ea636d10b196e93379
  [src/process/mod_drainage_hooghoudt_equivalent_depth.f90]=6b7b2bb1fd259879d3f26c46abfc071ea2b2f108
  [src/process/mod_drainage_hooghoudt_ipos1_response.f90]=89f26e2d2b77bef5bdd0c5fdb2ce9ca1f03206fa
  [src/process/mod_drainage_hooghoudt_ipos23_response.f90]=5637ddb4d33141f00b4ebf737d1c7f7fe1824164
  [src/process/mod_drainage_multilevel_aggregation.f90]=70d35512ef7c5958f7e4bf284cba104a7b641fdb
  [src/process/mod_drainage_process.f90]=dbacd49da3bb0b94f822f9ee0478d15183e9c0fa
  [src/process/mod_drainage_tabulated_response.f90]=738f57c334910ab73bc8870e3aa8dda1c1a48c7a
  [src/runtime/mod_fmr_drainage_response_binding.f90]=76c2a2ea569a4e85e490ebd2e7fb89c28d8b3fb5
  [src/runtime/mod_fmr_serialized_reference_backend.f90]=0f09c0df1559ece894356b146b64d872470c0a32
)
for p in "${!PROD_BLOBS[@]}"; do
  [[ "$(git rev-parse "HEAD:$p")" == "${PROD_BLOBS[$p]}" ]] || fail "admitted PM14 blob drift: $p"
done
echo 'FVQ74_EXACT_11_ADMITTED_PM14_BLOBS=PASS'

[[ "$(git rev-parse "$COMPOSITION:src/runtime/mod_fmr_serialized_reference_backend.f90")" == \
   "$(git rev-parse "HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90")" ]] || fail 'composition/backend mismatch'
echo 'FVQ74_COMPOSITION_IDENTITY=PASS'

allowed_paths=$(cat <<'EOF'
.github/workflows/fvq74-drainage-v1-crosscutting-runtime-completion.yml
integration/f-vq/F-VQ74_PRE_REGISTRATION.json
integration/f-vq/F-VQ74_STATUS.json
tests/fvq/run_fvq74_drainage_crosscutting_independent.sh
tests/fvq/run_fvq74_source_governance.sh
tests/fvq/test_fvq74_drainage_crosscutting_independent.f90
EOF
)
while IFS= read -r p; do
  grep -Fxq "$p" <<<"$allowed_paths" || fail "out-of-scope qualification path: $p"
done < <(git diff --name-only "$CANONICAL"..HEAD)
echo 'FVQ74_QUALIFICATION_PATH_ALLOWLIST=PASS'

python3 - <<'PY'
from pathlib import Path
backend=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
low=backend.lower()
start=low.index('type, extends(canonical_state_t), public :: fmr_b110_physical_state_t')
end=low.index('end type fmr_b110_physical_state_t', start)
state=low[start:end]
assert 'drainage' not in state, 'drainage response leaked into persistent physical state'
binding=Path('src/runtime/mod_fmr_drainage_response_binding.f90').read_text().lower()
assert 'headcalc' not in binding
for token in ('open(', 'read(', 'write(', '.swp', 'midnight', 'calendar'):
    assert token not in binding, token
workflow=Path('.github/workflows/fci-canonical.yml').read_text()
assert "AUTH=c7444233b0f23d4f0a845ef5639287e77099291b" in workflow
for p in (
 'src/process/mod_drainage_empirical_interflow_response.f90',
 'src/process/mod_drainage_ernst_ipos45_preparation.f90',
 'src/process/mod_drainage_ernst_ipos45_response.f90',
 'src/process/mod_drainage_hooghoudt_equivalent_depth.f90',
 'src/process/mod_drainage_hooghoudt_ipos1_response.f90',
 'src/process/mod_drainage_hooghoudt_ipos23_response.f90',
 'src/process/mod_drainage_multilevel_aggregation.f90',
 'src/process/mod_drainage_process.f90',
 'src/process/mod_drainage_tabulated_response.f90',
 'src/runtime/mod_fmr_drainage_response_binding.f90',
 'src/runtime/mod_fmr_serialized_reference_backend.f90'):
    assert p in workflow, p
print('FVQ74_NO_DRAINAGE_PERSISTENT_STATE_STATIC=PASS')
print('FVQ74_HEADCALC_IO_CALENDAR_ISOLATION_STATIC=PASS')
print('FVQ74_MOVING_CANONICAL_PRESERVATION_BINDING=PASS')
PY

git diff --check "$CANONICAL"..HEAD
echo 'FVQ74_SOURCE_GOVERNANCE=PASS'
