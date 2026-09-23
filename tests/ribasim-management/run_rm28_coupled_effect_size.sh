#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rm28-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
python3 tests/ribasim-management/test_rm28_coupled_effect_size.py | tee "$BUILD/output.txt"
grep -Fq 'RM28_COUPLED_EFFECT_SIZE=PASS' "$BUILD/output.txt"
echo 'RM28_COUPLED_EFFECT_SIZE_GATE=PASS'
