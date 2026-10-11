#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-dir01-r2-control-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/base" "$BUILD/candidate" "$BUILD/src"
trap 'rm -rf "$BUILD"' EXIT

BASE=933e9307318fda36a73bcffb9da3fe0cb5e588ab
git fetch --no-tags --depth=1 origin "$BASE"
git show "$BASE:src/transaction/mod_transaction_reference.f90" > "$BUILD/src/transaction_base.f90"

COMMON=(-std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -O2)

compile_and_run() {
  local name="$1"
  local tx="$2"
  local out="$BUILD/$name"
  gfortran "${COMMON[@]}" -J "$out" "$tx" tests/transaction/test_transaction_reference.f90 -o "$out/reference_test"
  gfortran "${COMMON[@]}" -J "$out" "$tx" tests/transaction/test_transaction_attempt_context.f90 -o "$out/context_test"

  set +e
  "$out/reference_test" > "$out/reference.log" 2>&1
  local ref_status=$?
  "$out/context_test" > "$out/context.log" 2>&1
  local context_status=$?
  set -e

  echo "DIR01_REPAIR02_CONTROL|VARIANT=$name|REFERENCE_STATUS=$ref_status|CONTEXT_STATUS=$context_status"
  echo "DIR01_REPAIR02_CONTROL_REFERENCE_LOG|VARIANT=$name"
  tail -40 "$out/reference.log"
  echo "DIR01_REPAIR02_CONTROL_CONTEXT_LOG|VARIANT=$name"
  cat "$out/context.log"

  echo "$ref_status $context_status" > "$out/status"
}

compile_and_run base "$BUILD/src/transaction_base.f90"
compile_and_run candidate src/transaction/mod_transaction_reference.f90

read -r base_ref base_ctx < "$BUILD/base/status"
read -r cand_ref cand_ctx < "$BUILD/candidate/status"

if [[ "$cand_ctx" -ne 0 ]]; then
  echo "DIR01_REPAIR02_CONTROL_FAIL candidate attempt-context semantics" >&2
  exit 1
fi
if [[ "$base_ref" -eq 0 && "$cand_ref" -ne 0 ]]; then
  echo "DIR01_REPAIR02_CONTROL_FAIL candidate introduced transaction-reference failure" >&2
  exit 1
fi
if [[ "$base_ref" -ne "$cand_ref" ]]; then
  echo "DIR01_REPAIR02_CONTROL_NOTE reference gate status changed base=$base_ref candidate=$cand_ref"
else
  echo "DIR01_REPAIR02_CONTROL_REFERENCE_STATUS_PRESERVED=$base_ref"
fi
echo "FPE_DIR01_REPAIR02_TRANSACTION_CONTROL=PASS"
