#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FPE05_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/transaction/mod_transaction_reference.f90 b1878606ae6cb2b04a7b4b15e3e537deacf4477f
check_blob src/runtime/mod_canonical_interval_runtime.f90 f2cae79d533343db818c11e0b61b605ac5f6739d
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 ade399a1df4b582c9038442093ccacce034f923d
check_blob src/kernel/mod_kernel_transactions.f90 af42c7d51ef545e20c76d3000f1ed1493690d68e
check_blob integration/f-pe/F-PE04_STATUS.json dac3afc75ca0f25bb167d851eeff2e9756298bc9

echo 'FPE05_EXACT_SOURCE_PREIMAGE=PASS'

python3 - <<'PY'
import json
from pathlib import Path

tx = Path('src/transaction/mod_transaction_reference.f90').read_text()
backend = Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
deps = json.loads(Path('integration/f-pe/F-PE05_DEPENDENCIES.json').read_text())
contract = json.loads(Path('integration/f-pe/F-PE05_REFERENCE_TEMPORAL_ACCEPTANCE_CONTRACT.json').read_text())
handoff = json.loads(Path('integration/f-pe/F-PE05_OWNER_HANDOFF.json').read_text())
status = json.loads(Path('integration/f-pe/F-PE05_STATUS.json').read_text())
fpe04 = json.loads(Path('integration/f-pe/F-PE04_STATUS.json').read_text())

assert 'terr = model%temporal_error(full_state, half_state)' in tx
assert 'temporal_ok = terr <= policy%temporal_tolerance' in tx
assert 'if (.not. temporal_ok)' in tx
assert 'procedure :: temporal_error => fmr_serialized_temporal_identity' in backend
assert 'all(full%pressure_head == half%pressure_head)' in backend
assert 'all(full%water_content == half%water_content)' in backend
assert 'full%ponding_depth == half%ponding_depth' in backend
assert 'full%groundwater_level == half%groundwater_level' in backend
assert 'value = 0.0_real64' in backend
assert 'value = huge(0.0_real64)' in backend

assert fpe04['status'] == 'QUALIFIED_REFERENCE_FAILURE_AND_RETRY_ENVELOPE'
assert fpe04['accepted_nonstationary_higher_cost_fixture_found'] is False
assert deps['scope_lock']['reference_only'] is True
assert deps['scope_lock']['production_source_change'] is False
assert contract['interpretation']['current_temporal_metric_is_exact_identity_gate'] is True
assert contract['interpretation']['nonstationary_acceptance_proven_impossible'] is False
assert contract['claim_limits']['bug_claimed'] is False
assert handoff['non_admission']['BALANCED'] == 'DEFINED_NOT_ADMITTED'
assert handoff['non_admission']['THROUGHPUT'] == 'DEFINED_NOT_ADMITTED'
assert handoff['non_admission']['FALLBACK'] == 'DEFINED_NOT_ADMITTED'
assert status['status'] == 'BLOCKED_OWNER_QUALIFIED_NONSTATIONARY_TEMPORAL_ACCEPTANCE_REQUIRED'
assert status['production_source_changed'] is False

print('FPE05_TEMPORAL_IDENTITY_SOURCE_PROOF=PASS')
print('FPE05_FPE04_DEPENDENCY_PROOF=PASS')
print('FPE05_OWNER_BOUNDARY_PROOF=PASS')
print('FPE05_NON_REFERENCE_NON_ADMISSION=PASS')
PY

echo 'FPE05_REFERENCE_TEMPORAL_ACCEPTANCE_SOURCE_GATE=PASS'
