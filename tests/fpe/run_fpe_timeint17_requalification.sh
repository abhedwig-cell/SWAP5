#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-timeint17-requal-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT

bash tests/fpe/run_fpe_nlglob14e1.sh | tee "$BUILD/out.log"

grep -q '"classification":"QUALIFIED_COMPLETE_DYNAMIC_TOP_RESEARCH_POLICY"' "$BUILD/out.log"
grep -q '"complete_cases":96' "$BUILD/out.log"
grep -q '"process_failures":0' "$BUILD/out.log"
grep -q '"post_entry_root_attempt_violations":0' "$BUILD/out.log"

echo "F_PE_TIMEINT17_REQUALIFICATION=PASS"
