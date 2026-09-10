#!/usr/bin/env bash
set -euo pipefail

BASE=c0fc660c1e68064f77f4ec4f3376d385fbe88b4a

fail() {
  echo "FMR34_FAIL $*" >&2
  exit 34
}

# Readiness-only: no production or reference source may change.
if git diff --name-only "$BASE"..HEAD -- src reference | grep -q .; then
  git diff --name-only "$BASE"..HEAD -- src reference >&2
  fail "unexpected production/reference delta"
fi

test "$(git rev-parse HEAD:src/runtime/mod_fmr_parallel_worker_pool.f90)" = 0e700797cbaed4aaab7f04db0054f72faddcfc15 || fail "worker-pool blob drift"
test "$(git rev-parse HEAD:src/runtime/mod_fmr_parallel_physical_scheduler.f90)" = 544a1ca16fdeebdfce7f89d1ddf1825fa32fa654 || fail "scheduler blob drift"
test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" = fe5a06c9af59308cdad86c5126379f413591b0cd || fail "serialized runtime blob drift"
test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" = 9af5a494526810324dc00706b444e448e770cba9 || fail "reference backend blob drift"
test "$(git rev-parse HEAD:src/solver/mod_b110_root_sink_provider.f90)" = ef2d2fd883d116c314b98e8f0f14330150b4778a || fail "root-sink provider blob drift"

echo 'FMR34_SOURCE_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path

pool = Path('src/runtime/mod_fmr_parallel_worker_pool.f90').read_text()
serial = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90').read_text()
root = Path('src/solver/mod_b110_root_sink_provider.f90').read_text()
contract = Path('integration/f-mr/F-MR34_READINESS_CONTRACT.md').read_text()
audit = Path('integration/f-mr/F-MR34_INVARIANT_AUDIT.json').read_text()

required_pool = [
    'allocate(backends(worker_count), transaction_controls(worker_count)',
    'call fmr_execute_serialized_physical_column(backends(w), transaction_controls(w)',
    'parameter_registry(parameter_index)%root_extraction_active .or.',
    'any(abs(forcing_registry(forcing_index)%root_extraction_sink) > 0.0_real64) return',
]
for s in required_pool:
    if s not in pool:
        raise SystemExit(f'FMR34_FAIL missing current parallel boundary: {s}')

# The exact forcing handle is resolved once, passed to run_trial and reused only
# after did_commit to publish F-MR31 actual transpiration.
markers = [
    'forcing_index = int(column%forcing_handle)',
    'forcing_registry(forcing_index), &',
    'if (.not. did_commit) then',
    'call bind_committed_actual_transpiration(parameter_registry(parameter_index), forcing_registry(forcing_index), &',
]
pos = [serial.find(m) for m in markers]
if any(p < 0 for p in pos) or pos != sorted(pos):
    raise SystemExit(f'FMR34_FAIL serialized forcing/commit/attribution ordering not preserved: {pos}')

required_root = [
    'real(real64), pointer :: root_extraction_sink(:) => null()',
    'real(real64), target, intent(in) :: root_extraction_sink(:)',
    'root_sink = self%root_extraction_sink',
]
for s in required_root:
    if s not in root:
        raise SystemExit(f'FMR34_FAIL root-provider binding changed: {s}')
if 'save ::' in root.lower():
    raise SystemExit('FMR34_FAIL root-sink provider gained SAVE state')

required_contract = [
    'distinct explicitly named root-active parallel physical profile/capability',
    'MUST NOT add a second water-mass contribution',
    'Time-varying root sink inside accepted substeps is explicitly NOT qualified',
    'separate restart requalification',
    'F-MQ30',
]
for s in required_contract:
    if s not in contract:
        raise SystemExit(f'FMR34_FAIL readiness contract incomplete: {s}')

if '"30_audit_every_architecture_change": "PASS_THIS_FILE"' not in audit:
    raise SystemExit('FMR34_FAIL invariant audit incomplete')

print('FMR34_PARALLEL_EXECUTOR_REUSE=PASS')
print('FMR34_CURRENT_ROOT_INACTIVE_PARALLEL_V1_BOUNDARY=PASS')
print('FMR34_EXACT_FORCING_POSTCOMMIT_ATTRIBUTION_SEAM=PASS')
print('FMR34_ROOT_PROVIDER_WORKER_BINDING_SHAPE=PASS')
print('FMR34_NO_SILENT_PARALLEL_V1_PHYSICS_RELAXATION=PASS')
print('FMR34_NO_SECOND_MASS_BOOKING_CONTRACT=PASS')
print('FMR34_GENERIC_TIME_FROZEN_QROT_SCOPE=PASS')
print('FMR34_ROOT_ACTIVE_RESTART_REQUALIFICATION_REQUIRED=PASS')
print('FMR34_ARCHITECTURE_INVARIANTS=30_OF_30_REVIEWED')
PY

echo 'FMR34_READINESS_GATE=PASS'
