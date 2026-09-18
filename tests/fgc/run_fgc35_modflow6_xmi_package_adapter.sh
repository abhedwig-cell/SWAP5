#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

python3 - <<'PY'
import ast
from pathlib import Path

path = Path("src/adapter/modflow6_xmi_package_adapter.py")
source = path.read_text()
tree = ast.parse(source)

required_tokens = [
    "get_var_address",
    "get_value_ptr",
    "refresh_after_prepare_time_step",
    "publish_via_fgc34",
    "close_before_prepare_solve",
]
for token in required_tokens:
    assert token in source, token

forbidden_calls = {
    "initialize",
    "prepare_time_step",
    "prepare_solve",
    "solve",
    "finalize_solve",
    "finalize_time_step",
    "finalize",
}
actual_forbidden = []
for node in ast.walk(tree):
    if not isinstance(node, ast.Call):
        continue
    func = node.func
    if isinstance(func, ast.Attribute) and func.attr in forbidden_calls:
        actual_forbidden.append(func.attr)

assert not actual_forbidden, actual_forbidden
assert "ribasim" not in source.lower()
assert "groundwater_commit" not in source.lower()
print("FGC35_XMI_POINTER_API_ONLY=PASS")
print("FGC35_NO_MODFLOW_EXECUTION_OWNERSHIP=PASS")
PY

python3 tests/fgc/test_fgc35_modflow6_xmi_package_adapter.py
echo 'F-GC35 MODFLOW6 XMI PACKAGE ADAPTER GATE PASS'
