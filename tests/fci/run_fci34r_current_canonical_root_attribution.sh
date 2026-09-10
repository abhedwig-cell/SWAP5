#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BASE="545e07c65338b9fe61b963468675c41f3e931816"
TARGET="src/runtime/mod_fmr_serialized_multiswap_runtime.f90"
NEW_BLOB="fe5a06c9af59308cdad86c5126379f413591b0cd"
fail() { echo "FCI34R_FAIL $*" >&2; exit 34; }

git merge-base --is-ancestor "$BASE" HEAD || fail 'HEAD is not descended from current canonical source authority'
[[ "$(git rev-parse "$BASE:$TARGET")" == "7bfb4a269256f0f1d50c32a20fd42479cf033528" ]] || fail 'current canonical runtime source drift'
[[ "$(git rev-parse "HEAD:$TARGET")" == "$NEW_BLOB" ]] || fail 'HEAD runtime is not exact F-MR31 qualified blob'
mapfile -t src_delta < <(git diff --name-only "$BASE"..HEAD -- src)
[[ ${#src_delta[@]} -eq 1 && "${src_delta[0]}" == "$TARGET" ]] || {
  printf '%s\n' "${src_delta[@]}" >&2
  fail 'source delta relative to current canonical is not exactly the admitted runtime path'
}
echo 'FCI34R_CURRENT_CANONICAL_SOURCE_AUTHORITY=PASS'
echo 'FCI34R_EXACT_ONE_CURRENT_CANONICAL_SOURCE_DELTA=PASS'
echo 'FCI34R_EXACT_FMR31_RUNTIME_BLOB=PASS'

bash tests/fci/run_fci34_fmr31_root_attribution_canonical_admission.sh

echo 'FCI34R_CURRENT_CANONICAL_RECOMPOSITION_GATE=PASS'
