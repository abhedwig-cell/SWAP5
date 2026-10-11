#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
python "$ROOT/tools/fci/fci17_canonical_baseline_registry_gate.py"
echo FCI17_GATE_PASS
