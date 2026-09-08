#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FSI15_HEAD="fe5e55d5d5ebff42e8212cba8df15652e5f1a52b"
FSI15_QUALIFICATION_BLOB="9dd06140d624c18d1a282bf10a30c737f61ab1ea"
EXPECTED_FKT_HEAD="510d1f29d40225c68f3a8d3e789071279941e87b"
EXPECTED_FKT_BOUNDARY_BLOB="ee1a153c30bbae9416ce08414e8b56049d3d14db"
BUILD="${TMPDIR:-/tmp}/swap5-fsi16-closeout-$$"
OLD="$BUILD/fsi15"
mkdir -p "$BUILD"
cleanup() {
  if git -C "$ROOT" worktree list --porcelain | grep -Fq "worktree $OLD"; then
    git -C "$ROOT" worktree remove --force "$OLD" >/dev/null 2>&1 || true
  fi
  rm -rf "$BUILD"
}
trap cleanup EXIT
cd "$ROOT"

[[ "$(git merge-base "$FSI15_HEAD" HEAD)" == "$FSI15_HEAD" ]] || {
  echo 'F-SI16_CLOSEOUT FAIL not descendant of final F-SI15 head' >&2; exit 1; }

actual_fsi15_qualification="$(git rev-parse "$FSI15_HEAD:integration/f-si/F-SI15_QUALIFICATION.json")"
[[ "$actual_fsi15_qualification" == "$FSI15_QUALIFICATION_BLOB" ]] || {
  echo "F-SI16_CLOSEOUT FAIL F-SI15 qualification blob expected=$FSI15_QUALIFICATION_BLOB actual=$actual_fsi15_qualification" >&2
  exit 1
}

# Reproduce the exact qualified predecessor in its own immutable tree. This
# avoids pretending that F-SI15 blob-identity gates should accept F-SI16's
# intentionally changed bottom-boundary/geometry source.
git worktree add --detach "$OLD" "$FSI15_HEAD" >/dev/null
(
  cd "$OLD"
  bash tests/fsi/run_fsi15_physical_option_authority_gate_v2.sh >/dev/null
  bash tests/fsi/run_fsi15_fsi14_identity_gate.sh >/dev/null
  bash tests/fsi/run_fsi15_closeout_regression_gate.sh >/dev/null
)
git worktree remove --force "$OLD" >/dev/null
echo 'F-SI16_FSI15_PINNED_QUALIFICATION_REGRESSION PASS'

# F-KT remains owner of committed state, retries, time and transaction semantics.
# F-SI16 changes no F-KT type or transaction contract, so require the same live
# qualified owner head and the same explicit F-KT -> F-SI boundary blob.
git fetch origin integration/f-kt >/dev/null 2>&1
actual_fkt_head="$(git rev-parse origin/integration/f-kt)"
[[ "$actual_fkt_head" == "$EXPECTED_FKT_HEAD" ]] || {
  echo "F-SI16_CLOSEOUT FAIL F-KT head drift expected=$EXPECTED_FKT_HEAD actual=$actual_fkt_head" >&2; exit 1; }
actual_boundary="$(git rev-parse origin/integration/f-kt:integration/f-kt/F-KT01_FSI_BOUNDARY.json)"
[[ "$actual_boundary" == "$EXPECTED_FKT_BOUNDARY_BLOB" ]] || {
  echo "F-SI16_CLOSEOUT FAIL F-KT boundary drift expected=$EXPECTED_FKT_BOUNDARY_BLOB actual=$actual_boundary" >&2; exit 1; }
bash "$ROOT/tests/fci/run_fci03_gate.sh" >/dev/null
echo 'F-SI16_FKT_BOUNDARY_REGRESSION PASS'

echo 'F-SI16_CLOSEOUT_REGRESSION_GATE PASS'
