#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
export PYTHONDONTWRITEBYTECODE=1
export PYTHONPATH="$ROOT/tests/fgc"
python3 "$ROOT/tests/fgc/test_fgc01_models.py"
python3 "$ROOT/tests/fgc/test_fgc01_coupling.py"
python3 "$ROOT/tools/fgc/fgc01_contract_gate.py" "$ROOT"
echo "F-GC01_GATE PASS"
