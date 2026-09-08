#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

CANDIDATE="ffab7d705928170db3e76a5d346caafeb560e605"
EXPECTED_TREE="06bd92b2cf96b7bc6eb6978250017cd054547a56"
FVQ17_CLOSEOUT="1d9ff946f45488557d10700f047089d3298a4794"
FVQ17_DECISIVE_HEAD="6377e0e932bc5258ed6105253360ec887257de3b"
FVQ16_CLOSEOUT="98712959d811c788c77842eede4c6f558cca1c11"
FMQ24_START="ff6c2b4f48dd9e76f5bec41281493f1d35d03d90"
ARTIFACTS=".fmq24-artifacts"
BUILD="${TMPDIR:-/tmp}/swap5-fmq24-$$"
rm -rf "$ARTIFACTS" "$BUILD"
mkdir -p "$ARTIFACTS" "$BUILD"
trap 'git worktree remove --force "$BUILD/candidate" >/dev/null 2>&1 || true; git worktree remove --force "$BUILD/fvq17" >/dev/null 2>&1 || true; rm -rf "$BUILD"' EXIT

# F-MQ24 itself is qualification-only: it must not modify production/reference source.
changed="$(git diff --name-only "$FMQ24_START"..HEAD -- src reference)"
[[ -z "$changed" ]] || {
  echo "FMQ24_SOURCE_BOUNDARY_VIOLATION" >&2
  echo "$changed" >&2
  exit 1
}
echo 'FMQ24_PRODUCTION_REFERENCE_SOURCE_UNCHANGED=PASS'

# Materialize the exact source candidate and exact independent F-VQ17 closeout.
git worktree add --detach "$BUILD/candidate" "$CANDIDATE" > "$ARTIFACTS/candidate-worktree-add.out" 2>&1
git worktree add --detach "$BUILD/fvq17" "$FVQ17_CLOSEOUT" > "$ARTIFACTS/fvq17-worktree-add.out" 2>&1

[[ "$(git -C "$BUILD/candidate" rev-parse HEAD)" == "$CANDIDATE" ]]
[[ "$(git -C "$BUILD/candidate" rev-parse HEAD^{tree})" == "$EXPECTED_TREE" ]]
[[ "$(git -C "$BUILD/candidate" rev-parse HEAD:src/process/mod_snow_process.f90)" == "54702d71b4c84dce2842813549bd14c57301a383" ]]
[[ "$(git -C "$BUILD/candidate" rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "202ab846cbd30d149d0d450249b3d517e333994f" ]]
[[ "$(git -C "$BUILD/candidate" rev-parse HEAD:src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" == "1bb0c6d4683db2729d48de31babcea72bc1a6caf" ]]
echo 'FMQ24_EXACT_CANDIDATE_TREE_AND_BLOBS=PASS'

python3 - "$BUILD/fvq17" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
status = json.loads((root/'integration/f-vq/F-VQ17_STATUS.json').read_text())
evidence = json.loads((root/'integration/f-vq/F-VQ17_QUALIFICATION_EVIDENCE.json').read_text())
assert status['QUALIFIED'] is True
assert status['TESTED'] is True
assert status['candidate_source_commit'] == 'ffab7d705928170db3e76a5d346caafeb560e605'
assert status['decision'] == 'QUALIFIED_FMR06_SERIALIZED_ONE_CALL_DAILY_SNOW_MULTISWAP_SCIENTIFIC_ADMISSION'
assert status['snow_multiswap_production_admission'] is False
assert status['parallel_reference_backend_admitted'] is False
assert status['subdaily_snow_admitted'] is False
assert evidence['candidate_source']['commit'] == status['candidate_source_commit']
assert evidence['candidate_source']['tree'] == '06bd92b2cf96b7bc6eb6978250017cd054547a56'
assert evidence['decisive_qualification']['qualification_harness_head'] == '6377e0e932bc5258ed6105253360ec887257de3b'
assert evidence['upstream_scientific_oracle']['fvq16_closeout_head'] == '98712959d811c788c77842eede4c6f558cca1c11'
print('FMQ24_FVQ17_CLOSEOUT_LOCK=PASS')
PY

# Re-execute the independent source-bound scientific/runtime matrix rather than merely trusting status.
(
  cd "$BUILD/fvq17"
  bash tests/vq/fvq17/run_fvq17_gate.sh
) > "$ARTIFACTS/fvq17-replay.out" 2>&1

for marker in \
  'FVQ17_SOURCE_IMMUTABILITY=PASS' \
  'FVQ17_CANDIDATE_LOCK=PASS' \
  'FVQ17_FMR06_ENGINEERING_REPLAY=PASS' \
  'FVQ17_DIRECT_FVQ16_ORACLE_REPLAY=PASS' \
  'FVQ17_O0=PASS' \
  'FVQ17_O2=PASS' \
  'FVQ17_O0_O2_OUTPUT_IDENTITY=PASS' \
  'FVQ17_PROFILE_ALL_INACTIVE_1_2_17_31=PASS' \
  'FVQ17_PROFILE_ALL_ACTIVE_1_2_17_31=PASS' \
  'FVQ17_PROFILE_MIXED_1_2_17_31=PASS' \
  'FVQ17_DIRECT_FVQ16_SNOW_STATE_IDENTITY=PASS' \
  'FVQ17_NONZERO_MELT_INTERNAL_TRANSFER=PASS' \
  'FVQ17_SNOW_INACTIVE_ZERO_STATE=PASS' \
  'FVQ17_REVERSE_ORDER_COLUMN_IDENTITY=PASS' \
  'FVQ17_REVERSE_ORDER_AGGREGATE_MASS_IDENTITY=PASS' \
  'FVQ17_A_B_A_EXACT=PASS' \
  'FVQ17_AUTHORITATIVE_MASS_COMPLETE=PASS' \
  'FVQ17_SUBDAILY_RUNTIME_FAIL_CLOSED=PASS' \
  'FVQ17_MULTIDAY_RUNTIME_FAIL_CLOSED=PASS' \
  'FVQ17_MAX_SIMULTANEOUS_REAL_PHYSICAL_SOLVES=1' \
  'FMR06_SNOW_ROLLBACK=PASS' \
  'FMR06_SNOW_REPLAY_BITWISE=PASS' \
  'FMR06_SNOW_COMMIT=PASS' \
  'FMR06_SNOW_AUTHORITATIVE_MASS_COMPLETE=PASS' \
  'FMR05_SINGLE_COLUMN_FMR04_ROUTE_IDENTITY=PASS' \
  'FMR05_SINGLE_COLUMN_FMR04_MASS_BITWISE_IDENTITY=PASS' \
  'FMR05_SINGLE_COLUMN_FMR04_COMMITTED_STATE_IDENTITY=PASS' \
  'FVQ17_GATE PASS_INDEPENDENT_FMR06_SNOW_MULTISWAP_SCIENTIFIC_ADMISSION'; do
  grep -Fq "$marker" "$ARTIFACTS/fvq17-replay.out"
done

echo 'FMQ24_MATRIX_1_2_17_31_INACTIVE_ACTIVE_MIXED=PASS'
echo 'FMQ24_ORDER_AND_A_B_A=PASS'
echo 'FMQ24_TRANSACTION_CHECKPOINT_ROLLBACK_REPLAY_COMMIT=PASS'
echo 'FMQ24_AUTHORITATIVE_MASS_COMPLETE=PASS'
echo 'FMQ24_SNOW_INACTIVE_REGRESSION=PASS'
echo 'FMQ24_O0_O2_IDENTITY=PASS'
echo 'FMQ24_SERIALIZED_MAX_SIMULTANEOUS_REAL_PHYSICAL_SOLVES=1'
echo 'FMQ24_SUBDAILY_SNOW_ADMISSION=FALSE'
echo 'FMQ24_MULTIDAY_SNOW_ADMISSION=FALSE'
echo 'FMQ24_PARALLEL_REAL_PHYSICS_ADMISSION=FALSE'
echo 'FMQ24_GENERAL_RICHARDS_SCOPE_EXPANSION=FALSE'

printf '%s\n' "$CANDIDATE" > "$ARTIFACTS/candidate.txt"
printf '%s\n' "$EXPECTED_TREE" > "$ARTIFACTS/candidate-tree.txt"
printf '%s\n' "$FVQ17_CLOSEOUT" > "$ARTIFACTS/fvq17-closeout.txt"
printf '%s\n' "$FVQ17_DECISIVE_HEAD" > "$ARTIFACTS/fvq17-decisive-head.txt"
printf '%s\n' "$FVQ16_CLOSEOUT" > "$ARTIFACTS/fvq16-closeout.txt"
git -C "$BUILD/candidate" rev-parse HEAD:src/process/mod_snow_process.f90 > "$ARTIFACTS/snow-process-blob.txt"
git -C "$BUILD/candidate" rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90 > "$ARTIFACTS/serialized-backend-blob.txt"
git -C "$BUILD/candidate" rev-parse HEAD:src/runtime/mod_fmr_serialized_multiswap_runtime.f90 > "$ARTIFACTS/serialized-runtime-blob.txt"
sha256sum "$ARTIFACTS/fvq17-replay.out" > "$ARTIFACTS/fmq24-qualification-output.sha256"

echo "FMQ24_QUALIFICATION_OUTPUT_SHA256=$(cut -d' ' -f1 "$ARTIFACTS/fmq24-qualification-output.sha256")"
echo 'FMQ24_GATE PASS_RESTRICTED_SERIALIZED_ONE_CALL_DAILY_SNOW_MULTISWAP_RUNTIME'
