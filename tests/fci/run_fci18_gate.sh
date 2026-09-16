#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
python "$ROOT/tools/fci/fci18_exit_scope_ownership_gate.py"
echo FCI18_GATE_PASS
