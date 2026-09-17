#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

STATUS_A_AUTH=50346642bd565f79134ea17d5462e544b354998c
FROSS12_AUTH=786fe5bf59e616dcfa9a86b16b58c67ac0b3b97d
CANONICAL_PREIMAGE=95d24660b51257119d5ee5fd25f2011e20b1dfa6

fail() { echo "FCI96_FROSS12_POSTIMAGE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$STATUS_A_AUTH" HEAD || fail 'Status-A authority not ancestor'
git merge-base --is-ancestor "$FROSS12_AUTH" HEAD || fail 'F-ROSS12 admission not ancestor'
git merge-base --is-ancestor "$CANONICAL_PREIMAGE" HEAD || fail 'F-CI96 canonical preimage not ancestor'

# This workunit is governance-only. No source or reference mutation is permitted.
test "$(git rev-parse HEAD:src)" = "$(git rev-parse "$FROSS12_AUTH:src")" || fail 'source tree drift after F-ROSS12 admission'
test "$(git rev-parse HEAD:reference)" = "$(git rev-parse "$FROSS12_AUTH:reference")" || fail 'reference tree drift after F-ROSS12 admission'

BACKEND=src/runtime/mod_fmr_serialized_reference_backend.f90
BINDING=src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
ADAPTER=src/solver/mod_rossfast_d3r_soil_water_solver.f90

test "$(git rev-parse HEAD:$BACKEND)" = 19d07cac9285142d14a6e9c53706fb73d016d5ad || fail 'serialized backend successor blob drift'
test "$(git rev-parse HEAD:$BINDING)" = cca61af52bde3eed12b756547277cc2776589648 || fail 'RossFast selection binding blob drift'
test "$(git rev-parse HEAD:$ADAPTER)" = 6d6f66273483c19c1d2318dad518c537186a0ae7 || fail 'RossFast solver adapter blob drift'

test "$(git rev-parse "$FROSS12_AUTH:$BACKEND")" = 19d07cac9285142d14a6e9c53706fb73d016d5ad || fail 'F-ROSS12 backend authority mismatch'
test "$(git rev-parse "$FROSS12_AUTH:$BINDING")" = cca61af52bde3eed12b756547277cc2776589648 || fail 'F-ROSS12 binding authority mismatch'
test "$(git rev-parse "$FROSS12_AUTH:$ADAPTER")" = 6d6f66273483c19c1d2318dad518c537186a0ae7 || fail 'F-ROSS12 adapter authority mismatch'

test "$(git rev-parse "$STATUS_A_AUTH:$BACKEND")" != "$(git rev-parse "$FROSS12_AUTH:$BACKEND")" || fail 'expected backend semantic successor delta absent'

while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  case "$path" in
    .github/workflows/fci-canonical.yml|\
    .github/workflows/fci72-eb-i23-moving-preservation.yml|\
    .github/workflows/fci74-eb-i24-moving-preservation.yml|\
    .github/workflows/fci79-eb-i25-moving-preservation.yml|\
    .github/workflows/fci96-fross12-postimage-preservation.yml|\
    tests/fci/run_fci96_fross12_postimage_preservation.sh|\
    integration/f-ci/F-CI96_STATUS.json|\
    integration/f-ross/F-ROSS12_STATUS.json)
      ;;
    *) fail "out-of-scope reconciliation mutation: $path" ;;
  esac
done < <(git diff --name-only "$CANONICAL_PREIMAGE"...HEAD)

git diff --check "$CANONICAL_PREIMAGE"...HEAD

# Re-qualify only the F-ROSS12 scientific/production successor here.
# EB-I23/I24/I25 have their own moving-preservation workflows on this PR.
# Their historical independent qualification runners intentionally require
# frozen evidence/preimages and are not valid current-postimage replay entrypoints.
bash tests/ross/run_ross12_soil_water_solver_adapter.sh
bash tests/ross/run_ross12_solver_selection_binding.sh
bash tests/ross/run_ross12_serialized_production_wiring.sh

grep -Fq 'FROSS12_AUTH=786fe5bf59e616dcfa9a86b16b58c67ac0b3b97d' .github/workflows/fci72-eb-i23-moving-preservation.yml
grep -Fq 'FROSS12_AUTH=786fe5bf59e616dcfa9a86b16b58c67ac0b3b97d' .github/workflows/fci74-eb-i24-moving-preservation.yml
grep -Fq 'FROSS12_AUTH=786fe5bf59e616dcfa9a86b16b58c67ac0b3b97d' .github/workflows/fci79-eb-i25-moving-preservation.yml

echo 'FCI96_FROSS12_EXACT_POSTIMAGE=PASS'
echo 'FCI96_FROSS12_GOVERNANCE_ONLY_DELTA=PASS'
echo 'FCI96_FROSS12_SEMANTIC_REPLAY=PASS'
echo 'FCI96_EB_SUCCESSOR_WORKFLOW_OWNERSHIP=PASS'
echo 'FCI96_FROSS12_POSTIMAGE_PRESERVATION=PASS'
