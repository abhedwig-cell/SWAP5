#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FSI14_HEAD="d1b1553805ce11f235ac2565381c1ac31739b1f4"
EXPECTED_FKT_HEAD="510d1f29d40225c68f3a8d3e789071279941e87b"
EXPECTED_FKT_BOUNDARY_BLOB="ee1a153c30bbae9416ce08414e8b56049d3d14db"
BUILD="${TMPDIR:-/tmp}/swap5-fsi15-closeout-$$"
OLD="$BUILD/fsi14"
mkdir -p "$BUILD"
cleanup() {
  if git -C "$ROOT" worktree list --porcelain | grep -Fq "worktree $OLD"; then
    git -C "$ROOT" worktree remove --force "$OLD" >/dev/null 2>&1 || true
  fi
  rm -rf "$BUILD"
}
trap cleanup EXIT
cd "$ROOT"

[[ "$(git merge-base "$FSI14_HEAD" HEAD)" == "$FSI14_HEAD" ]] || {
  echo 'F-SI15_CLOSEOUT FAIL not descendant of final F-SI14 head' >&2; exit 1; }

# The exact final F-SI14 qualification must remain reproducible in its own tree.
git worktree add --detach "$OLD" "$FSI14_HEAD" >/dev/null
(
  cd "$OLD"
  bash tests/fsi/run_fsi14_grid_authority_gate.sh >/dev/null
  bash tests/fsi/run_fsi14_qualification_identity_gate.sh >/dev/null
  bash tests/fsi/run_fsi14_closeout_regression_gate.sh >/dev/null
)
git worktree remove --force "$OLD" >/dev/null
echo 'F-SI15_FSI14_PINNED_REGRESSION PASS'

# F-KT remains the owner of transaction/time/committed-state semantics. Pin both
# the current integration branch head and its unchanged F-KT -> F-SI boundary.
git fetch origin integration/f-kt >/dev/null 2>&1
actual_fkt_head="$(git rev-parse origin/integration/f-kt)"
[[ "$actual_fkt_head" == "$EXPECTED_FKT_HEAD" ]] || {
  echo "F-SI15_CLOSEOUT FAIL F-KT head drift expected=$EXPECTED_FKT_HEAD actual=$actual_fkt_head" >&2; exit 1; }
actual_boundary="$(git rev-parse origin/integration/f-kt:integration/f-kt/F-KT01_FSI_BOUNDARY.json)"
[[ "$actual_boundary" == "$EXPECTED_FKT_BOUNDARY_BLOB" ]] || {
  echo "F-SI15_CLOSEOUT FAIL F-KT boundary drift expected=$EXPECTED_FKT_BOUNDARY_BLOB actual=$actual_boundary" >&2; exit 1; }
bash "$ROOT/tests/fci/run_fci03_gate.sh" >/dev/null
echo 'F-SI15_FKT_BOUNDARY_REGRESSION PASS'

echo 'F-SI15_CLOSEOUT_REGRESSION_GATE PASS'
