#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic65-ebi25-diff-${GITHUB_RUN_ID:-local}-$$"
CANON="$BUILD/canonical"
mkdir -p "$BUILD"
cleanup(){ git worktree remove --force "$CANON" >/dev/null 2>&1 || true; rm -rf "$BUILD"; }
trap cleanup EXIT
fail(){ echo "F_PE_ELASTIC65_EBI25_DIFF_FAIL $*" >&2; exit 1; }

git fetch origin integration/f-ci-canonical
BASE="$(git rev-parse origin/integration/f-ci-canonical)"
CANDIDATE="$(git rev-parse HEAD)"
echo "F_PE_ELASTIC65_EBI25_CANONICAL=$BASE"
echo "F_PE_ELASTIC65_EBI25_CANDIDATE=$CANDIDATE"

git worktree add --detach "$CANON" "$BASE" >/dev/null
# Use one identical dependency-closed harness for both production trees.
cp tests/fkt/run_fkt22_eb_i25_preservation_gate.sh "$CANON/tests/fkt/run_fkt22_eb_i25_preservation_gate.sh"

run_gate(){
  local root="$1" log="$2"
  set +e
  (cd "$root" && bash tests/fkt/run_fkt22_eb_i25_preservation_gate.sh) >"$log" 2>&1
  local rc=$?
  set -e
  grep '^EB_I25_' "$log" >"$log.semantic" || true
  echo "$rc"
}

RC_CAN="$(run_gate "$CANON" "$BUILD/canonical.log")"
RC_CAND="$(run_gate "$ROOT" "$BUILD/candidate.log")"

echo "F_PE_ELASTIC65_EBI25_CANONICAL_RC=$RC_CAN"
echo "F_PE_ELASTIC65_EBI25_CANDIDATE_RC=$RC_CAND"

if [[ "$RC_CAN" != "$RC_CAND" ]]; then
  echo "--- canonical semantic ---" >&2
  cat "$BUILD/canonical.log.semantic" >&2
  echo "--- candidate semantic ---" >&2
  cat "$BUILD/candidate.log.semantic" >&2
  fail "exit-status drift canonical=$RC_CAN candidate=$RC_CAND"
fi

if ! cmp -s "$BUILD/canonical.log.semantic" "$BUILD/candidate.log.semantic"; then
  diff -u "$BUILD/canonical.log.semantic" "$BUILD/candidate.log.semantic" >&2 || true
  fail "EB-I25 semantic marker drift"
fi

cat "$BUILD/canonical.log.semantic"

if [[ "$RC_CAN" == "0" ]]; then
  echo "F_PE_ELASTIC65_EBI25_BASELINE=PASS"
else
  grep -Fq 'EB_I25_TEST_FAIL external full-half outflow fixture rejected before commit' "$BUILD/canonical.log" ||     fail "canonical failed for a different reason"
  grep -Fq 'EB_I25_TEST_FAIL external full-half outflow fixture rejected before commit' "$BUILD/candidate.log" ||     fail "candidate failed for a different reason"
  echo "F_PE_ELASTIC65_EBI25_BASELINE=PREEXISTING_CURRENT_CANONICAL_FAILURE"
fi

echo "F_PE_ELASTIC65_EBI25_NO_REGRESSION=PASS"
