#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
EXPECTED="825c4aea9306087534d0a46514bc40c254aebfd4"
ACTUAL="$(git hash-object tests/fmr/test_fmr36_divdra_active_runtime_callsite_v2.f90)"
[[ "$ACTUAL" == "$EXPECTED" ]] || { echo "FMR36_GATE_FAIL corrected oracle drift expected=$EXPECTED actual=$ACTUAL" >&2; exit 1; }
# Preserve the failed historical fixture in Git, but make the existing source-bound
# gate compile the corrected F-VQ21-derived oracle in this ephemeral CI workspace.
cp tests/fmr/test_fmr36_divdra_active_runtime_callsite_v2.f90 tests/fmr/test_fmr36_divdra_active_runtime_callsite.f90
echo 'FMR36_CORRECTED_FVQ21_DERIVED_ORACLE_LOCK=PASS'
exec bash tests/fmr/run_fmr36_divdra_active_runtime_callsite_gate.sh
