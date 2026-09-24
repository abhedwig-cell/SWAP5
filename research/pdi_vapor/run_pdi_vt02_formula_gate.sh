#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
python3 research/pdi_vapor/pdi_vt02_formula_gate.py | tee "${1:-/tmp/pdi_vt02.json}"
grep -q '"status": "PASS"' "${1:-/tmp/pdi_vt02.json}"
