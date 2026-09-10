#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BASE=b982d4d0c8686e5c5fcb965633d34a4e0ba46fcf
CANDIDATE=97c5f4fd7cbc2024248a6b3df927ca4fa6b6dee7

changed_src="$(git diff --name-only "$BASE" -- src)"
[[ -z "$changed_src" ]] || {
  echo 'FVQ44_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FVQ44_NO_PRODUCTION_DELTA=PASS'

changed_ref="$(git diff --name-only "$BASE" -- reference)"
[[ -z "$changed_ref" ]] || {
  echo 'FVQ44_UNEXPECTED_REFERENCE_DELTA' >&2
  printf '%s\n' "$changed_ref" >&2
  exit 1
}
echo 'FVQ44_NO_REFERENCE_DELTA=PASS'

# The independent verifier must not import, execute, or parse F-PM08A-owned tests/evidence as an oracle.
if grep -Eiq 'tests/fpm/.*fpm08a|F-PM08A_CANDIDATE_EVIDENCE|run_fpm08a' tests/fvq/test_fvq44_single_level_linear_drainage.py; then
  echo 'FVQ44_INDEPENDENT_ORACLE_STATIC_SEPARATION=FAIL' >&2
  exit 1
fi
echo 'FVQ44_INDEPENDENT_ORACLE_STATIC_SEPARATION=PASS'

actual_blob="$(git rev-parse "$CANDIDATE:src/process/mod_drainage_process.f90")"
[[ "$actual_blob" == 'dbacd49da3bb0b94f822f9ee0478d15183e9c0fa' ]]
echo 'FVQ44_CANDIDATE_BLOB_PRECHECK=PASS'

python3 tests/fvq/test_fvq44_single_level_linear_drainage.py | tee /tmp/fvq44-output.txt

for marker in \
  'FVQ44_FROZEN_DRAINAGE_SOURCE_IDENTITY=PASS' \
  'FVQ44_FROZEN_MOD_DRAINAGE_SOURCE_IDENTITY=PASS' \
  'FVQ44_PERSISTED_EQUATION_LEVEL_ORACLE_BINDING=PASS' \
  'FVQ44_CANDIDATE_CLOSEOUT_BLOB_IDENTITY=PASS' \
  'FVQ44_O0_O2_CANDIDATE_OUTPUT_IDENTITY=PASS' \
  'FVQ44_RANDOMIZED_VALID_DOMAIN_COVERAGE=PASS' \
  'FVQ44_EFFECTIVE_DRAIN_HEAD_ABSTRACTION_COVERAGE=PASS' \
  'FVQ44_ACTIVE_INACTIVE_KINK_COVERAGE=PASS' \
  'FVQ44_RESTRICTED_LEGACY_FLUX_EQUIVALENCE=PASS' \
  'FVQ44_STABLE_BRANCH_ANALYTIC_DERIVATIVE_EQUIVALENCE=PASS' \
  'FVQ44_ACTIVE_DERIVATIVE_FINITE_DIFFERENCE=PASS' \
  'FVQ44_INACTIVE_DERIVATIVE_FINITE_DIFFERENCE=PASS' \
  'FVQ44_INVALID_NORMALIZED_DOMAIN_FAILS_CLOSED=PASS' \
  'FVQ44_STATELESS_A_B_A_REPEATABILITY=PASS' \
  'FVQ44_RESTRICTED_SINGLE_LEVEL_LINEAR_DRAINAGE_QUALIFICATION=PASS'; do
  grep -Fq "$marker" /tmp/fvq44-output.txt
 done

echo 'FVQ44_RESTRICTED_SINGLE_LEVEL_LINEAR_DRAINAGE_GATE=PASS'
