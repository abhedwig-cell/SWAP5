#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic65-p2e05-diff-${GITHUB_RUN_ID:-local}-$$"
CANON="$BUILD/canonical"
mkdir -p "$BUILD"
cleanup(){ git worktree remove --force "$CANON" >/dev/null 2>&1 || true; rm -rf "$BUILD"; }
trap cleanup EXIT
fail(){ echo "F_PE_ELASTIC65_P2E05_DIFF_FAIL $*" >&2; exit 1; }

git fetch origin integration/f-ci-canonical
BASE="$(git rev-parse origin/integration/f-ci-canonical)"
CANDIDATE="$(git rev-parse HEAD)"
echo "F_PE_ELASTIC65_P2E05_CANONICAL=$BASE"
echo "F_PE_ELASTIC65_P2E05_CANDIDATE=$CANDIDATE"

git worktree add --detach "$CANON" "$BASE" >/dev/null
cp tests/fci/run_fci_canonical_p2e05_moving_preservation.sh    "$CANON/tests/fci/run_fci_canonical_p2e05_moving_preservation.sh"

run_gate(){
  local root="$1" log="$2"
  set +e
  (cd "$root" && bash tests/fci/run_fci_canonical_p2e05_moving_preservation.sh) >"$log" 2>&1
  local rc=$?
  set -e
  grep -E '^(FCI_CANONICAL_|FCI[0-9]+_MOVING_)' "$log" >"$log.semantic" || true
  grep 'FCI_CANONICAL_P2E05_PRESERVATION_FAIL' "$log" | tail -1 >"$log.failure" || true
  echo "$rc"
}

RC_CAN="$(run_gate "$CANON" "$BUILD/canonical.log")"
RC_CAND="$(run_gate "$ROOT" "$BUILD/candidate.log")"

echo "F_PE_ELASTIC65_P2E05_CANONICAL_RC=$RC_CAN"
echo "F_PE_ELASTIC65_P2E05_CANDIDATE_RC=$RC_CAND"

if [[ "$RC_CAN" != "$RC_CAND" ]]; then
  echo "--- canonical semantic ---" >&2
  cat "$BUILD/canonical.log.semantic" >&2
  echo "--- candidate semantic ---" >&2
  cat "$BUILD/candidate.log.semantic" >&2
  fail "exit-status drift canonical=$RC_CAN candidate=$RC_CAND"
fi

if ! cmp -s "$BUILD/canonical.log.semantic" "$BUILD/candidate.log.semantic"; then
  diff -u "$BUILD/canonical.log.semantic" "$BUILD/candidate.log.semantic" >&2 || true
  fail "semantic marker drift"
fi

cat "$BUILD/canonical.log.semantic"

if [[ "$RC_CAN" == "0" ]]; then
  echo "F_PE_ELASTIC65_P2E05_BASELINE=PASS"
else
  expected='FCI_CANONICAL_P2E05_PRESERVATION_FAIL admitted dependency drift from a0fd7822ea5d7ecc0bb409fd9f0439c8fd1dca6a: src/runtime/mod_a23bu_worker_execution_context.f90'
  grep -Fqx "$expected" "$BUILD/canonical.log.failure" || {
    cat "$BUILD/canonical.log.failure" >&2
    fail "canonical failed for a different reason"
  }
  grep -Fqx "$expected" "$BUILD/candidate.log.failure" || {
    cat "$BUILD/candidate.log.failure" >&2
    fail "candidate failed for a different reason"
  }
  echo "F_PE_ELASTIC65_P2E05_BASELINE=PREEXISTING_CURRENT_CANONICAL_FAILURE"
fi

echo "F_PE_ELASTIC65_P2E05_NO_REGRESSION=PASS"
