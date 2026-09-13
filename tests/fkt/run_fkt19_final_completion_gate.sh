#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
CANON=267f2a6ec61f78d3ba4ce75b3e5a7fdc08479135
CANDIDATE=623e633b1f8451bd849f590f796806f11e1ecbdf
TX=src/transaction/mod_transaction_reference.f90
TX_BLOB=d5a71a526efaebd82054580c3186f8e3545db331
STATUS=integration/f-kt/F_KT19_KERNEL_TRANSACTIONS_GENERIC_TIME_MASS_V1_FINAL_COMPLETION.json

git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1
test "$(git rev-parse origin/integration/f-ci-canonical)" = "$CANON"
git diff --exit-code "$CANON" HEAD -- src reference
test "$(git rev-parse "$CANON:$TX")" = "$TX_BLOB"
test "$(git rev-parse "$CANDIDATE:$TX")" = "$TX_BLOB"
test "$(git rev-parse "HEAD:$TX")" = "$TX_BLOB"

python3 - "$TX" "$STATUS" <<'PY'
from pathlib import Path
import json, sys
src=Path(sys.argv[1]).read_text()
status=json.loads(Path(sys.argv[2]).read_text())
blocks={
 'external': src[src.index('subroutine execute_reference_interval'):src.index('end subroutine execute_reference_interval')],
 'certificate': src[src.index('subroutine execute_model_certificate_interval'):src.index('end subroutine execute_model_certificate_interval')],
}
for name,b in blocks.items():
    gate=b.index('if (.not. mass_ok)')
    materialize=b.index('call move_alloc')
    assert 'mass_accounting_complete' in b[:gate]
    assert 'missing_mass_contribution_mask' in b[:gate]
    assert 'ieee_is_finite' in b[:gate]
    assert 'mass_tolerance' in b[:materialize]
    assert gate < materialize, name
assert status['decision']=='QUALIFIED_KERNEL_TRANSACTIONS_GENERIC_TIME_MASS_V1_100_PERCENT_COMPLETE'
assert status['frozen_denominator']['denominator']==8
assert status['frozen_denominator']['qualified']==8
assert status['frozen_denominator']['denominator_changed'] is False
assert status['frozen_denominator']['scope_redefined'] is False
assert status['fkt17_g01']['status']=='CLOSED'
assert status['mass_admission_contract']['invariant_13']=='PASS'
assert status['regression_audit_since_fkt17']['new_hard_blockers']==[]
assert status['production_source_changed_by_fkt19'] is False
print('FKT19_FAIL_CLOSED_MASS_ADMISSION=PASS')
print('FKT19_CURRENT_CANONICAL_BLOB_IDENTITY=PASS')
print('FKT19_NO_PRODUCTION_SOURCE_CHANGE=PASS')
print('FKT19_FROZEN_DENOMINATOR_8_OF_8=PASS')
print('FKT19_FINAL_COMPLETION_GATE=PASS')
PY
