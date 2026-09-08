#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
export PYTHONDONTWRITEBYTECODE=1
python3 "$ROOT/tools/fgc/fgc02_boundary_blocker_gate.py" "$ROOT"
echo "F-GC02_BLOCKER_REPRODUCTION_GATE PASS"
