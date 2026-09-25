#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="bc4147a6252a50bd24db78f3499ae7e3db05bbca"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-h22a-fgc-paired-${GITHUB_RUN_ID:-local}-$$"
BASE_DIR="$BUILD/baseline"
mkdir -p "$BUILD"
trap 'git -C "$ROOT" worktree remove --force "$BASE_DIR" >/dev/null 2>&1 || true; rm -rf "$BUILD"' EXIT

cd "$ROOT"
cp tests/fgc/run_fgc49d_production_application_context.sh "$BUILD/current-run.sh"
cp tests/fgc/test_fgc49d_production_application_context.py "$BUILD/current-test.py"

git worktree add --detach "$BASE_DIR" "$BASE" >/dev/null
cp "$BUILD/current-run.sh" "$BASE_DIR/tests/fgc/run_fgc49d_production_application_context.sh"
cp "$BUILD/current-test.py" "$BASE_DIR/tests/fgc/test_fgc49d_production_application_context.py"

set +e
(
  cd "$BASE_DIR"
  bash tests/fgc/run_fgc49d_production_application_context.sh
) >"$BUILD/baseline.out" 2>&1
base_status=$?
(
  cd "$ROOT"
  bash tests/fgc/run_fgc49d_production_application_context.sh
) >"$BUILD/current.out" 2>&1
current_status=$?
set -e

echo "FPE_H22A_FGC_BASE_STATUS=$base_status"
echo "FPE_H22A_FGC_CURRENT_STATUS=$current_status"
echo "--- BASELINE TAIL ---"
tail -n 40 "$BUILD/baseline.out" || true
echo "--- CURRENT TAIL ---"
tail -n 40 "$BUILD/current.out" || true

if [[ "$base_status" -eq 0 && "$current_status" -ne 0 ]]; then
  echo "FPE_H22A_FGC_DIAGNOSIS=CANDIDATE_REGRESSION"
  exit 1
elif [[ "$base_status" -ne 0 && "$current_status" -ne 0 ]]; then
  echo "FPE_H22A_FGC_DIAGNOSIS=INHERITED_OR_HARNESS_FAILURE"
  exit 0
elif [[ "$base_status" -eq 0 && "$current_status" -eq 0 ]]; then
  echo "FPE_H22A_FGC_DIAGNOSIS=BOTH_PASS"
  exit 0
else
  echo "FPE_H22A_FGC_DIAGNOSIS=CURRENT_IMPROVEMENT"
  exit 0
fi
