#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

OWNER_HEAD="d678b5953c64be3f3f2056c369fd8b8eb7deab82"
HARNESS_PATH="tests/fgc/support/fgc39_prepared_solve_service_harness.py"
HARNESS_BLOB="0ab5cd1d5b701389972ddfcdf7f4ebc7dc198aec"

test "$(git rev-parse "HEAD:$HARNESS_PATH")" = "$HARNESS_BLOB"
test "$(git rev-parse "$OWNER_HEAD:$HARNESS_PATH")" = "$HARNESS_BLOB"
test -z "$(git diff --name-only "$OWNER_HEAD..HEAD" -- src)"
echo 'FVQ112_VERIFIER_PRODUCTION_DELTA_NONE=PASS'
echo 'FVQ112_OWNER_HARNESS_BLOB_LOCK=PASS'

python3 - <<'PY'
import ast
from pathlib import Path

verifier=Path("tests/fvq/test_fvq112_fgc39_independent.py").read_text()
assert "test_fgc39_prepared_solve_service_contract" not in verifier
assert "test_reference_update_and_convergence_ordering" in verifier
assert "test_finalize_failure_is_not_publication_ready" in verifier

harness=Path("tests/fgc/support/fgc39_prepared_solve_service_harness.py").read_text()
tree=ast.parse(harness)
for node in ast.walk(tree):
    if isinstance(node, ast.Import):
        assert all(alias.name.split(".",1)[0] not in {"xmipy","ribasim"} for alias in node.names)
    if isinstance(node, ast.ImportFrom) and node.module:
        assert node.module.split(".",1)[0] not in {"xmipy","ribasim"}

calls=[
    node.func.attr
    for node in ast.walk(tree)
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
]
for forbidden in ["get_value_ptr","get_var_address","prepare_solve","solve","finalize_time_step"]:
    assert forbidden not in calls, forbidden

print("FVQ112_OWNER_TEST_NOT_REUSED=PASS")
print("FVQ112_INDEPENDENT_ORACLE_STRUCTURE=PASS")
print("FVQ112_INTERNAL_SERVICE_OWNERSHIP_STATIC_ORACLE=PASS")
PY

python3 tests/fvq/test_fvq112_fgc39_independent.py
echo 'F-VQ112 F-GC39 INDEPENDENT QUALIFICATION PASS'
