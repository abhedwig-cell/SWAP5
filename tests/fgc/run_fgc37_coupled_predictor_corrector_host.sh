#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

python3 - <<'PY'
import ast
from pathlib import Path

path = Path("src/adapter/coupled_predictor_corrector_host.py")
source = path.read_text()
tree = ast.parse(source)

for token in [
    "capture_origin",
    "build_predictor_response",
    "trial_from_origin",
    "corrector_trial_from_origin",
    "discard_candidate",
    "prepare_candidate",
    "publication_preflight",
    "commit_candidate",
    "commit_prepared",
]:
    assert token in source, token

for node in ast.walk(tree):
    if isinstance(node, ast.Import):
        for alias in node.names:
            root = alias.name.split(".", 1)[0].lower()
            assert root not in {"xmipy", "ribasim"}, alias.name
    if isinstance(node, ast.ImportFrom) and node.module:
        root = node.module.split(".", 1)[0].lower()
        assert root not in {"xmipy", "ribasim"}, node.module

calls = []
for node in ast.walk(tree):
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
        calls.append(node.func.attr)

for forbidden_call in [
    "solve",
    "get_value_ptr",
    "get_var_address",
    "prepare_time_step",
    "prepare_solve",
    "finalize_time_step",
]:
    assert forbidden_call not in calls, forbidden_call

print("FGC37_TRANSACTIONAL_PARTICIPANTS_ONLY=PASS")
print("FGC37_NO_XMI_OR_MODFLOW_EXECUTION_OWNERSHIP=PASS")
PY

python3 tests/fgc/test_fgc37_coupled_predictor_corrector_host.py
echo 'F-GC37 COUPLED PREDICTOR-CORRECTOR HOST CONTRACT GATE PASS'
