#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
python "$ROOT/tools/fci/fci16_exit_gate_assessment_gate.py"
echo FCI16_GATE_PASS
