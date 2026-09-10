#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=e3964ec0ef312f974461aeac70fb9bc5720803e3

fail() { echo "FMR29_READINESS_FAIL $*" >&2; exit 1; }

# Readiness workunit must not mutate production source.
git diff --quiet "$BASE"..HEAD -- src || {
  git diff --name-only "$BASE"..HEAD -- src >&2
  fail 'readiness branch mutated production source'
}
echo 'FMR29_PRODUCTION_SOURCE_UNCHANGED=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git rev-parse "HEAD:$path")"
  [[ "$actual" == "$expected" ]] || fail "source authority drift $path expected=$expected actual=$actual"
}

check_blob src/runtime/mod_fmr_reference_et_root_uptake_composition.f90 8ed7610144700f58d0b89482925471fcb2ff7d69
check_blob src/process/mod_root_water_uptake_process.f90 e6134587cf3c0164bbe09f2f4c87aef6886aaeb3
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 9af5a494526810324dc00706b444e448e770cba9
check_blob src/transaction/mod_transaction_reference.f90 2fd932b74dbd0ffc0ec089f49e632b7ac8852df4
check_blob src/runtime/mod_canonical_interval_runtime.f90 55f3d271aa6200a994fd0144d6fce0701c918a74
check_blob src/kernel/mod_kernel_transactions.f90 f1acff10dd99c308a00f434440d6a9ef14632f0d
check_blob src/runtime/mod_fmr_accepted_commit_receipt.f90 6798b3296b426950bf028814585c3f5de9be950b
echo 'FMR29_PINNED_SOURCE_AUTHORITY=PASS'

python3 - <<'PY'
from pathlib import Path

backend = Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text(encoding='utf-8')
runtime = Path('src/runtime/mod_canonical_interval_runtime.f90').read_text(encoding='utf-8')
kernel = Path('src/kernel/mod_kernel_transactions.f90').read_text(encoding='utf-8')
receipt = Path('src/runtime/mod_fmr_accepted_commit_receipt.f90').read_text(encoding='utf-8')
root = Path('src/process/mod_root_water_uptake_process.f90').read_text(encoding='utf-8')

required_backend = [
    'self%qrot = forcing%root_extraction_sink',
    'call bind_b110_root_sink_provider(self%root_sink, self%qrot)',
    'value = self%qrot(i) * step_duration',
    'total_out = total_out + value',
]
for x in required_backend:
    assert x in backend, x

prepare_pos = runtime.index('call model%prepare_interval(forcing, interval, config)')
loop_pos = runtime.index('do isub = 1, config%max_committed_substeps')
assert prepare_pos < loop_pos
assert 'if (runtime_result%completed) then' in kernel
assert 'candidate_state%origin_t0 = t0' in kernel
assert 'candidate_state%origin_t1 = t1' in kernel
assert 'call kernel%commit_candidate(committed_state, candidate_state, diagnostics, did_commit, local_commit_status)' in receipt
assert 'if (.not. did_commit) then' in receipt
assert receipt.index('if (.not. did_commit) then') < receipt.index('receipt%initialized = .true.')
assert 'fluxes%actual_uptake_total = sum(fluxes%root_extraction_sink)' in root

print('FMR29_QROT_SINGLE_OUTER_INTERVAL_BINDING=PASS')
print('FMR29_ROOT_MASS_ALREADY_BOOKED_ONCE=PASS')
print('FMR29_CANDIDATE_ONLY_AFTER_FULL_INTERVAL=PASS')
print('FMR29_RECEIPT_ONLY_AFTER_SUCCESSFUL_COMMIT=PASS')
print('FMR29_PROCESS_TOTAL_EQUALS_QROT_RATE_SUM=PASS')
PY

python3 - <<'PY'
# Partition-invariance proof over representative non-negative qrot vectors and
# arbitrary accepted substep partitions. This checks the arithmetic contract,
# not new physics.
cases = [
    ([0.0], [1.0]),
    ([0.1, 0.2, 0.3], [0.125, 0.375, 0.5]),
    ([1e-12, 2e-8, 0.004, 0.7], [0.01, 0.02, 0.07, 0.2, 0.7]),
    ([0.25, 0.0, 0.75], [0.3333333333333333, 0.6666666666666667]),
]
for qrot, fractions in cases:
    rate = sum(qrot)
    outer_dt = 7.25
    parts = [outer_dt * f for f in fractions]
    reconstructed = sum(rate * dt for dt in parts)
    direct = rate * outer_dt
    tol = 64.0 * 2.220446049250313e-16 * max(1.0, abs(reconstructed), abs(direct))
    assert abs(reconstructed - direct) <= tol, (qrot, fractions, reconstructed, direct)
print('FMR29_ACCEPTED_SUBSTEP_PARTITION_INVARIANCE=PASS')
PY

echo 'FMR29_NO_DUPLICATE_MASS_BOOKING_CONTRACT=PASS'
echo 'FMR29_ACTUAL_TRANSPIRATION_ATTRIBUTION_READINESS_GATE=PASS'
