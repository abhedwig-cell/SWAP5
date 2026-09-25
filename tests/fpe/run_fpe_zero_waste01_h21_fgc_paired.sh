#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PRE_H21="93fc10d6f73758e1081bb698c217fb6839b64724"
H21="00942a0f7d64c5e06e3c701346224470ba2f621d"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-h21-fgc-paired-${GITHUB_RUN_ID:-local}-$$"
PRE_DIR="$BUILD/pre-h21"
H21_DIR="$BUILD/h21"
mkdir -p "$BUILD"
trap 'git -C "$ROOT" worktree remove --force "$PRE_DIR" >/dev/null 2>&1 || true; git -C "$ROOT" worktree remove --force "$H21_DIR" >/dev/null 2>&1 || true; rm -rf "$BUILD"' EXIT

cd "$ROOT"
cp tests/fgc/run_fgc49d_production_application_context.sh "$BUILD/current-run.sh"
cp tests/fgc/test_fgc49d_production_application_context.py "$BUILD/current-test.py"

git worktree add --detach "$PRE_DIR" "$PRE_H21" >/dev/null
git worktree add --detach "$H21_DIR" "$H21" >/dev/null
for d in "$PRE_DIR" "$H21_DIR"; do
  cp "$BUILD/current-run.sh" "$d/tests/fgc/run_fgc49d_production_application_context.sh"
  cp "$BUILD/current-test.py" "$d/tests/fgc/test_fgc49d_production_application_context.py"
done

run_case() {
  local name="$1" dir="$2"
  set +e
  (
    cd "$dir"
    bash tests/fgc/run_fgc49d_production_application_context.sh
  ) >"$BUILD/$name.out" 2>&1
  local status=$?
  set -e
  echo "FPE_H21_FGC_${name^^}_STATUS=$status"
  echo "--- ${name^^} TAIL ---"
  tail -n 50 "$BUILD/$name.out" || true
  return "$status"
}

pre_status=0
h21_status=0
run_case pre "$PRE_DIR" || pre_status=$?
run_case h21 "$H21_DIR" || h21_status=$?

echo "FPE_H21_FGC_PRE_STATUS=$pre_status"
echo "FPE_H21_FGC_H21_STATUS=$h21_status"
if [[ "$pre_status" -eq 0 && "$h21_status" -ne 0 ]]; then
  echo "FPE_H21_FGC_DIAGNOSIS=H21_REGRESSION"
  exit 1
elif [[ "$pre_status" -ne 0 && "$h21_status" -ne 0 ]]; then
  echo "FPE_H21_FGC_DIAGNOSIS=PREEXISTING_OR_HARNESS_FAILURE"
  exit 0
elif [[ "$pre_status" -eq 0 && "$h21_status" -eq 0 ]]; then
  echo "FPE_H21_FGC_DIAGNOSIS=BOTH_PASS"
  exit 0
else
  echo "FPE_H21_FGC_DIAGNOSIS=H21_IMPROVEMENT"
  exit 0
fi
