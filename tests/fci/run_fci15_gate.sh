#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
python "$ROOT/tools/fci/fci15_exit_gate_contract_gate.py"
echo FCI15_GATE_PASS
