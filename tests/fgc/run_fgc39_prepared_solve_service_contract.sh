#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

python3 - <<'PY'
import ast
from pathlib import Path

path = Path("tests/fgc/support/fgc39_prepared_solve_service_harness.py")
source = path.read_text()
tree = ast.parse(source)

assert not Path("src/adapter/coupled_predictor_corrector_host.py").exists()

for forbidden_import in {"xmipy", "ribasim"}:
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            assert all(alias.name.split(".", 1)[0] != forbidden_import for alias in node.names)
        if isinstance(node, ast.ImportFrom) and node.module:
            assert node.module.split(".", 1)[0] != forbidden_import

calls = []
for node in ast.walk(tree):
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
        calls.append(node.func.attr)

for forbidden_call in [
    "get_value_ptr",
    "get_var_address",
    "prepare_solve",
    "solve",
    "finalize_time_step",
]:
    assert forbidden_call not in calls, forbidden_call

assert "imod_coupler" not in source.lower()

# The reconciled contract must not contain groundwater candidate rollback.
for forbidden in [
    "groundwater.discard_candidate",
    "groundwater.capture_origin",
    "groundwater.prepare_candidate",
]:
    assert forbidden not in source, forbidden

for required in [
    "open_window",
    "solve_iteration",
    "finalize_converged_solve",
    "invalidate_abandoned_solve",
    "corrector_trial_from_origin",
]:
    assert required in source, required

print("FGC39_INTERNAL_SERVICE_BELOW_IMOD=PASS")
print("FGC39_NO_GROUNDWATER_PER_ITERATION_ROLLBACK=PASS")
print("FGC39_NO_DIRECT_XMI_OR_TIMESTEP_OWNERSHIP=PASS")
PY

python3 tests/fgc/test_fgc39_prepared_solve_service_contract.py
echo 'F-GC39 PREPARED-SOLVE COUPLING SERVICE CONTRACT GATE PASS'
