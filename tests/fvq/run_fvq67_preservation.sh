#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
CANDIDATE=623e633b1f8451bd849f590f796806f11e1ecbdf
CANDIDATE_TREE=47826cb69e04c46b8739bcf953ac26db80b5ff3e
CANON=267f2a6ec61f78d3ba4ce75b3e5a7fdc08479135
TX=src/transaction/mod_transaction_reference.f90
TX_BLOB=d5a71a526efaebd82054580c3186f8e3545db331
BUILD="${RUNNER_TEMP:-/tmp}/fvq67-preservation-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"; mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

# F-VQ67 is qualification-only: exact immutable candidate production/reference source is untouched.
test "$(git rev-parse "$CANDIDATE^{tree}")" = "$CANDIDATE_TREE"
git diff --exit-code "$CANDIDATE" HEAD -- src reference
test "$(git rev-parse "$CANDIDATE:$TX")" = "$TX_BLOB"
test "$(git rev-parse "HEAD:$TX")" = "$TX_BLOB"
echo 'FVQ67_PRODUCTION_AND_REFERENCE_UNCHANGED=PASS'
echo "FVQ67_TRANSACTION_SOURCE_BLOB=PASS:$TX_BLOB"

# Current canonical is compatibility evidence, never the source being qualified.
git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1
test "$(git rev-parse origin/integration/f-ci-canonical)" = "$CANON" || {
  echo 'FVQ67_CANONICAL_RACE=FAIL' >&2
  exit 67
}
test "$(git rev-parse "$CANON:$TX")" = "$TX_BLOB"
test "$(git rev-parse "$CANDIDATE:src")" = "$(git rev-parse "$CANON:src")"
test "$(git rev-parse "$CANDIDATE:reference")" = "$(git rev-parse "$CANON:reference")"
echo 'FVQ67_CURRENT_CANONICAL_FULL_SRC_IDENTITY=PASS'
echo 'FVQ67_CURRENT_CANONICAL_REFERENCE_IDENTITY=PASS'

# Structural proof: in both transaction modes the composite mass gate precedes candidate materialization.
python3 - "$TX" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
blocks={
  'external_full_half': s[s.index('subroutine execute_reference_interval'):s.index('end subroutine execute_reference_interval')],
  'model_certificate': s[s.index('subroutine execute_model_certificate_interval'):s.index('end subroutine execute_model_certificate_interval')],
}
for name,block in blocks.items():
    for token in ('mass_accounting_complete','missing_mass_contribution_mask','ieee_is_finite','mass_ok','mass_tolerance','move_alloc'):
        assert token in block, (name, token)
    gate=block.index('if (.not. mass_ok)')
    materialize=block.index('call move_alloc')
    assert block.index('mass_accounting_complete') < gate < materialize, name
    assert block.index('ieee_is_finite') < gate, name
    assert block.index('mass_tolerance') < materialize, name
print('FVQ67_BOTH_ADMISSION_ROUTES_STRUCTURAL_FAIL_CLOSED=PASS')
PY

# Replay the new independent attack matrix against the exact current-canonical transaction blob too.
git show "$CANON:$TX" > "$BUILD/mod_transaction_reference.f90"
FVQ67_TRANSACTION_SOURCE="$BUILD/mod_transaction_reference.f90" FVQ67_TAG=canonical \
  bash tests/fvq/run_fvq67_mass_completeness_independent.sh

echo 'FVQ67_CURRENT_CANONICAL_INDEPENDENT_ATTACK_REPLAY=PASS'
echo 'FVQ67_PRESERVATION_GATE=PASS'
