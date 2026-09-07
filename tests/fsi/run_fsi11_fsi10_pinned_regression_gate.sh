#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FSI10_HEAD="8dc05bd4133cd24f13e794d7410d408f9337cf74"
BUILD="${TMPDIR:-/tmp}/swap5-fsi11-fsi10-regression-$$"
REG="$BUILD/fsi10"
mkdir -p "$BUILD"
cleanup() {
  if git -C "$ROOT" worktree list --porcelain | grep -Fq "worktree $REG"; then
    git -C "$ROOT" worktree remove --force "$REG" >/dev/null 2>&1 || true
  fi
  rm -rf "$BUILD"
}
trap cleanup EXIT

cd "$ROOT"
# Regression must execute the exact previously qualified F-SI10 postimage. Running
# its protected-source gate in the F-SI11 tree would intentionally fail because the
# common contract and HeadCalc seam have advanced.
git cat-file -e "$FSI10_HEAD^{commit}"
git worktree add --detach "$REG" "$FSI10_HEAD" >/dev/null
(
  cd "$REG"
  bash tests/fsi/run_fsi10_source_sink_provider_gate.sh >/dev/null
)

echo 'F-SI11_FSI10_PINNED_REGRESSION PASS'
