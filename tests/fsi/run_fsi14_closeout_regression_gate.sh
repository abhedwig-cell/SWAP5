#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FSI13_HEAD="485d702c720cd9532addf9cba8cf2c5bd3b3ee43"
BUILD="${TMPDIR:-/tmp}/swap5-fsi14-closeout-$$"
FSI13="$BUILD/fsi13"
mkdir -p "$BUILD"
cleanup() {
  if git -C "$ROOT" worktree list --porcelain | grep -Fq "worktree $FSI13"; then
    git -C "$ROOT" worktree remove --force "$FSI13" >/dev/null 2>&1 || true
  fi
  rm -rf "$BUILD"
}
trap cleanup EXIT
cd "$ROOT"

# The complete, exact F-SI13 qualification remains green in its own pinned tree.
git worktree add --detach "$FSI13" "$FSI13_HEAD" >/dev/null
(
  cd "$FSI13"
  bash tests/fsi/run_fsi13_qualification_gate.sh >/dev/null
)
git worktree remove --force "$FSI13" >/dev/null
echo 'F-SI14_FSI13_PINNED_REGRESSION PASS'

# F-SI14 must remain behind the unchanged F-KT transaction boundary. This is the
# existing source-bound F-CI/F-KT boundary regression, not a new F-SI transaction test.
bash "$ROOT/tests/fci/run_fci03_gate.sh" >/dev/null
echo 'F-SI14_FKT_BOUNDARY_REGRESSION PASS'

echo 'F-SI14_CLOSEOUT_REGRESSION_GATE PASS'
