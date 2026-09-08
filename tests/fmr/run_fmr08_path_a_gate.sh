#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

FMR06_CANDIDATE="ffab7d705928170db3e76a5d346caafeb560e605"
SNOW_BLOB="54702d71b4c84dce2842813549bd14c57301a383"
BACKEND_BLOB="202ab846cbd30d149d0d450249b3d517e333994f"
MULTISWAP_BLOB="1bb0c6d4683db2729d48de31babcea72bc1a6caf"
SMOKE_BLOB="4f45bb0623fef3fb6d091579e8f435563c858a69"
ARTIFACTS=".fmr08-artifacts"
rm -rf "$ARTIFACTS"
mkdir -p "$ARTIFACTS"

check_locked_blob() {
  local path="$1" expected="$2" candidate_blob head_blob
  candidate_blob="$(git rev-parse "${FMR06_CANDIDATE}:${path}")"
  head_blob="$(git hash-object "$path")"
  [[ "$candidate_blob" == "$expected" ]] || {
    echo "FMR08_CANDIDATE_BLOB_MISMATCH path=$path expected=$expected candidate=$candidate_blob" >&2
    exit 1
  }
  [[ "$head_blob" == "$expected" ]] || {
    echo "FMR08_HEAD_BLOB_MISMATCH path=$path expected=$expected head=$head_blob" >&2
    exit 1
  }
}

git merge-base --is-ancestor "$FMR06_CANDIDATE" HEAD
if git diff --name-status "$FMR06_CANDIDATE"..HEAD | awk '$1 != "A" { bad=1 } END { exit bad ? 0 : 1 }'; then
  echo 'FMR08_EXISTING_CANDIDATE_FILE_CHANGED_OR_DELETED' >&2
  git diff --name-status "$FMR06_CANDIDATE"..HEAD >&2
  exit 1
fi

check_locked_blob src/process/mod_snow_process.f90 "$SNOW_BLOB"
check_locked_blob src/runtime/mod_fmr_serialized_reference_backend.f90 "$BACKEND_BLOB"
check_locked_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 "$MULTISWAP_BLOB"
check_locked_blob tests/fmr/test_fmr06_snow_smoke.f90 "$SMOKE_BLOB"

echo 'FMR08_FMR06_SOURCE_LOCK=PASS'
echo 'FMR08_ONLY_ADDITIONS_SINCE_EXACT_FMR06_CANDIDATE=PASS'

SMOKE="tests/fmr/test_fmr06_snow_smoke.f90"
BACKEND="src/runtime/mod_fmr_serialized_reference_backend.f90"
grep -Fq 'real(real64), parameter :: t0 = 1400.25_real64' "$SMOKE"
grep -Fq 'real(real64), parameter :: t1 = 1401.25_real64' "$SMOKE"
grep -Fq 'real(real64), parameter :: initial_snow = 0.10_real64' "$SMOKE"
grep -Fq 'real(real64), parameter :: snowfall = 0.02_real64' "$SMOKE"
grep -Fq 'cfg%transaction%temporal_tolerance = 0.0_real64' "$SMOKE"
grep -Fq "candidate_snow_state(candidate, initial_snow + snowfall, .true., t0)" "$SMOKE"
grep -Fq "committed_snow_state(committed, initial_snow + snowfall, .true., t0)" "$SMOKE"
grep -Fq "committed_fingerprint(committed) == committed_before" "$SMOKE"
grep -Fq "procedure :: temporal_error => fmr_serialized_temporal_identity" "$BACKEND"
for field in snow_water_storage liquid_water_storage event_applied event_t0; do
  grep -Fq "$field" "$BACKEND"
done

python3 - <<'PY'
from decimal import Decimal
initial = Decimal('0.10')
snowfall = Decimal('0.02')
t0 = Decimal('1400.25')
t1 = Decimal('1401.25')
expected = initial + snowfall
assert t1 - t0 == Decimal('1.00')
assert snowfall > 0
assert expected == Decimal('0.12')
assert expected != initial
print('FMR08_SOURCE_DERIVED_INITIAL_SNOW=0.10')
print('FMR08_SOURCE_DERIVED_COMMITTED_SNOW=0.12')
print('FMR08_SOURCE_DERIVED_SNOW_DELTA=0.02')
print('FMR08_NONSTATIONARY_SNOW_STATE_SOURCE_AUDIT=PASS')
PY

bash tests/fmr/run_fmr06_gate.sh > "$ARTIFACTS/fmr06-replay.out" 2>&1
grep -Fq 'FMR06_SNOW_ONE_CALL_DAILY_TRIAL=PASS' "$ARTIFACTS/fmr06-replay.out"
grep -Fq 'FMR06_SNOW_ROLLBACK=PASS' "$ARTIFACTS/fmr06-replay.out"
grep -Fq 'FMR06_SNOW_REPLAY_BITWISE=PASS' "$ARTIFACTS/fmr06-replay.out"
grep -Fq 'FMR06_SNOW_COMMIT=PASS' "$ARTIFACTS/fmr06-replay.out"
grep -Fq 'FMR06_SNOW_AUTHORITATIVE_MASS_COMPLETE=PASS' "$ARTIFACTS/fmr06-replay.out"
grep -Fq 'FMR06_GATE PASS_RUNTIME_CANDIDATE_REQUIRES_INDEPENDENT_FVQ' "$ARTIFACTS/fmr06-replay.out"

echo 'FMR08_FMR06_ENGINEERING_REPLAY=PASS'
echo 'FMR08_PATH_A_GATE PASS_OWNER_CANDIDATE_REQUIRES_INDEPENDENT_FVQ'
