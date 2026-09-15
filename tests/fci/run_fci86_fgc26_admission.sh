#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BASE=e4419b41d15a4acebf0fe55e5b810b92bbcd5f35

# Admission recomposition is production-minimal: no existing runtime source may move.
if ! git diff --quiet "$BASE" HEAD -- src/runtime; then
  echo 'FCI86_PRESERVATION_FAIL existing src/runtime changed' >&2
  git diff --name-status "$BASE" HEAD -- src/runtime >&2
  exit 1
fi
mapfile -t prod_delta < <(git diff --name-only "$BASE" HEAD -- src | sort)
if [[ ${#prod_delta[@]} -ne 1 || "${prod_delta[0]}" != "src/adapter/mod_groundwater_external_gateway.f90" ]]; then
  echo 'FCI86_PRESERVATION_FAIL unexpected production delta' >&2
  printf '%s\n' "${prod_delta[@]}" >&2
  exit 1
fi

[[ "$(git hash-object src/adapter/mod_groundwater_external_gateway.f90)" == "f307f17e2fd20983432f91e91ac90aaae8311849" ]]
[[ "$(git hash-object tests/fvq/test_fvq96_fgc26_external_gateway_independent.f90)" == "ed44b66418753cb36897e755522378698d20f460" ]]
[[ "$(git hash-object tests/fvq/run_fvq96_fgc26_external_gateway_independent.sh)" == "090d5669e7dfe6eefa68fdcf4e02fbac2d982d90" ]]
[[ "$(git hash-object tests/fvq/F-VQ96_RECONCILE_CHECKPOINT.json)" == "e4985be51a3aaca2f58c1e9a995b213edd5ac26f" ]]
[[ "$(git hash-object tests/fvq/F-VQ96_QUALIFY_CHECKPOINT.json)" == "11938b8ca54e27200d610ddfbb263992934f4de6" ]]

printf '%s\n' 'FCI86_PRODUCTION_DELTA_EXACT_GATEWAY_ONLY=PASS'
printf '%s\n' 'FCI86_INDEPENDENT_EVIDENCE_BLOBS_IMMUTABLE=PASS'

# Replay only the evidence whose context is the recomposed current-canonical tree.
# Owner evidence is intentionally reused, not redundantly rerun.
bash tests/fvq/run_fvq96_fgc26_external_gateway_independent.sh

printf '%s\n' 'FCI86_CURRENT_CANONICAL_RECOMPOSITION=PASS'
printf '%s\n' 'F-CI86 F-GC26 ADMISSION GATE PASS'
